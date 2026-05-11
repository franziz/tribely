// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { runWithContext } from '@/core/context/request-context.js';
import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import { OutboxEventPublisher } from '@/core/events/outbox-event-publisher.js';
import { SystemClock } from '@/features/auth/infrastructure/adapters/system-clock.js';
import { EventPrismaRepository } from '@/features/events/infrastructure/persistence/event.prisma-repository.js';
import { JOIN_REQUEST_APPROVED } from '../../domain/events/approved.event.js';
import { JoinRequestPrismaRepository } from '../../infrastructure/persistence/join-request.prisma-repository.js';
import { ApproveJoinRequestUseCase } from './approve-join-request.usecase.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * Exercises the `SELECT … FOR UPDATE` row-lock path in
 * `EventPrismaRepository.findByIdForUpdate`. Two (or more) concurrent
 * `ApproveJoinRequestUseCase.execute` calls targeting the same capacity-2
 * event must not both pass the capacity guard — the lock serializes them so
 * exactly one approval succeeds and the rest receive CONFLICT / CAPACITY_FULL.
 *
 * capacity=2 means 1 guest slot:
 *   `approvedCount >= capacity.value - 1`  →  `0 >= 2 - 1 = 1` is false for
 *   the first approval, `1 >= 1` is true for every subsequent attempt.
 *
 * We use 5 concurrent callers on a capacity-2 event to make the race
 * deterministic: the FOR UPDATE lock ensures transactions are serialized, so
 * the outcome does not depend on clock timing — exactly 1 will win regardless
 * of OS scheduler behaviour.
 */
describe.skipIf(!dbUrl)(
  'ApproveJoinRequestUseCase (concurrent) — capacity invariant under concurrent approvals',
  () => {
    let db: PrismaClient;
    let useCase: ApproveJoinRequestUseCase;

    let hostUserId: string;
    let localEventId: string;
    const requesterIds: string[] = [];
    const trackedJoinRequestIds: string[] = [];

    const CAPACITY = 2; // 1 guest slot
    const CONCURRENT_APPROVERS = 5;

    beforeAll(async () => {
      if (!dbUrl) return;

      db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
      const unitOfWork = new PrismaUnitOfWork(db);
      const joinRequestRepo = new JoinRequestPrismaRepository(db);
      const eventRepo = new EventPrismaRepository(db);
      const publisher = new OutboxEventPublisher();
      const clock = new SystemClock();

      useCase = new ApproveJoinRequestUseCase(
        unitOfWork,
        joinRequestRepo,
        eventRepo,
        publisher,
        clock,
      );

      hostUserId = createId();
      await db.user.create({
        data: {
          id: hostUserId,
          email: `host-${hostUserId}@concurrent.test`,
          displayName: 'Concurrent Test Host',
        },
      });

      const now = new Date();
      localEventId = createId();
      await db.event.create({
        data: {
          id: localEventId,
          hostUserId,
          title: 'Capacity-2 Concurrent Test Event',
          description: null,
          venueAddress: '18 Raffles Quay, Singapore',
          venueCity: 'Singapore',
          venueLatitude: 1.2806,
          venueLongitude: 103.8504,
          startsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
          endsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000 + 3 * 60 * 60 * 1000),
          capacity: CAPACITY,
          category: 'food',
          costSplit: 'own',
          approvalMode: 'manual',
          status: 'published',
          cancellationReason: null,
          createdAt: now,
          updatedAt: now,
        },
      });

      // Seed CONCURRENT_APPROVERS pending join requests, one per distinct requester.
      for (let i = 0; i < CONCURRENT_APPROVERS; i++) {
        const requesterId = createId();
        await db.user.create({
          data: {
            id: requesterId,
            email: `requester-${requesterId}@concurrent.test`,
            displayName: `Concurrent R-${String(i)}`,
          },
        });
        requesterIds.push(requesterId);

        const joinRequestId = createId();
        trackedJoinRequestIds.push(joinRequestId);

        // Insert the pending row directly via Prisma — bypasses the use case
        // so we don't consume an approval slot during setup.
        await db.joinRequest.create({
          data: {
            id: joinRequestId,
            eventId: localEventId,
            requesterUserId: requesterId,
            status: 'pending',
            requestedAt: new Date(),
            decidedAt: null,
            decidedByUserId: null,
            decisionReason: null,
          },
        });
      }
    });

    afterAll(async () => {
      if (!dbUrl) return;

      // Delete outbox events for the seeded join requests and the event itself.
      if (trackedJoinRequestIds.length > 0) {
        await db.outboxEvent
          .deleteMany({
            where: {
              aggregateType: 'JoinRequest',
              aggregateId: { in: trackedJoinRequestIds },
            },
          })
          .catch(() => null);
      }

      // Cascade-deletes join_requests rows.
      await db.event.delete({ where: { id: localEventId } }).catch(() => null);
      await db.outboxEvent
        .deleteMany({ where: { aggregateType: 'Event', aggregateId: localEventId } })
        .catch(() => null);

      if (requesterIds.length > 0) {
        await db.user.deleteMany({ where: { id: { in: requesterIds } } }).catch(() => null);
      }
      await db.user.delete({ where: { id: hostUserId } }).catch(() => null);

      await db.$disconnect();
    });

    it('allows exactly 1 approval and rejects all others with CAPACITY_FULL when concurrent approvals race on a capacity-2 event', async () => {
      // Fire all CONCURRENT_APPROVERS approve calls simultaneously.
      const results = await Promise.allSettled(
        trackedJoinRequestIds.map((joinRequestId) =>
          Promise.resolve(
            runWithContext({ requestId: createId(), actorUserId: hostUserId }, () =>
              useCase.execute({ joinRequestId, actorUserId: hostUserId }),
            ),
          ),
        ),
      );

      const fulfilled = results.filter((r) => r.status === 'fulfilled');
      const rejected = results.filter((r) => r.status === 'rejected');

      // Exactly one approval succeeds.
      expect(fulfilled).toHaveLength(1);

      // All remaining callers must receive CONFLICT / CAPACITY_FULL.
      expect(rejected).toHaveLength(CONCURRENT_APPROVERS - 1);
      for (const r of rejected) {
        expect(r.reason).toMatchObject({
          name: 'AppError',
          code: 'CONFLICT',
          status: 409,
          details: { subcode: 'CAPACITY_FULL' },
        });
      }

      // Database: exactly 1 join_request row has status='approved'.
      const approvedRows = await db.joinRequest.findMany({
        where: { eventId: localEventId, status: 'approved' },
      });
      expect(approvedRows).toHaveLength(1);

      // Database: the remaining rows are still pending (not mutated).
      const pendingRows = await db.joinRequest.findMany({
        where: { eventId: localEventId, status: 'pending' },
      });
      expect(pendingRows).toHaveLength(CONCURRENT_APPROVERS - 1);

      // Outbox: exactly one joinRequests.approved event was published for this event.
      const approvedEvents = await db.outboxEvent.findMany({
        where: {
          type: JOIN_REQUEST_APPROVED,
          aggregateType: 'JoinRequest',
          aggregateId: { in: trackedJoinRequestIds },
        },
      });
      expect(approvedEvents).toHaveLength(1);

      // The published event's payload references the same event.
      const payload = approvedEvents[0]?.payload as { eventId?: string } | null;
      expect(payload?.eventId).toBe(localEventId);
      // Allow up to 30 s — concurrent transactions with row locks can take
      // longer than the default 5 s timeout in congested CI environments.
    }, 30_000);
  },
);
