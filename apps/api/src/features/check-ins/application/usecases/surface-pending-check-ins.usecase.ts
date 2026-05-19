import { createId } from '@paralleldrive/cuid2';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { PostEventCheckIn } from '../../domain/entities/post-event-check-in.js';
import type { PostEventCheckInRepository } from '../../domain/repositories/post-event-check-in.repository.js';
import type { PostEventCheckInAuditPort } from '../ports/post-event-check-in-audit.port.js';
import type { PendingCheckIn } from '../dto/pending-check-in.dto.js';
import type { SurfacePendingCheckInsResult } from '../dto/surface-pending-check-ins.result.js';

const TITLE_TRUNCATE_MAX = 40;
const WINDOW_HOURS_MIN = 3;
const WINDOW_DAYS_MAX = 7;

export interface SurfacePendingCheckInsInput {
  userId: string;
}

/**
 * Surfaces pending post-event check-ins for an attendee.
 *
 * Triggered on the foreground-resume flow. For every event the user attended
 * that ended in the 3h–7d window, ensures a PostEventCheckIn row exists
 * (idempotent: skips if row already present per the @@unique constraint) and
 * returns all currently-pending check-ins enriched with event title, host
 * display name, and event end time.
 *
 * The 3h lower bound gives the event a grace period to close before nudging
 * the attendee. The 7d upper bound keeps the prompt set from growing unbounded.
 *
 * Audit wire (A7 exception): for each newly-created check-in, calls
 * RecordPostEventCheckInEventUseCase.execute({..., reason: 'created'}, ctx)
 * inside the same UoW — the audit row commits atomically with the aggregate
 * row (PDPA s25 evidence-integrity pattern).
 */
export class SurfacePendingCheckInsUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly checkIns: PostEventCheckInRepository,
    private readonly eventRepo: EventRepository,
    private readonly userRepo: UserRepository,
    private readonly publisher: EventPublisher,
    private readonly recordAuditEvent: PostEventCheckInAuditPort,
    private readonly clock: Clock,
  ) {}

  async execute(input: SurfacePendingCheckInsInput): Promise<SurfacePendingCheckInsResult> {
    const now = this.clock.now();

    // Look-back window: endsAt ∈ (now - 7d, now - 3h)
    // sinceEndsAt = lower bound (exclusive) = now - 7d
    // untilEndsAt = upper bound (exclusive) = now - 3h
    const sinceEndsAt = new Date(now.getTime() - WINDOW_DAYS_MAX * 24 * 60 * 60 * 1000);
    const untilEndsAt = new Date(now.getTime() - WINDOW_HOURS_MIN * 60 * 60 * 1000);

    await this.unitOfWork.run(async (ctx) => {
      const attendances = await this.checkIns.findApprovedAttendancesWithoutCheckIn(
        input.userId,
        { sinceEndsAt, untilEndsAt },
        ctx,
      );

      for (const attendance of attendances) {
        const checkIn = PostEventCheckIn.create({
          id: createId(),
          userId: input.userId,
          eventId: attendance.eventId,
          hostUserId: attendance.hostUserId,
          now,
        });

        await this.checkIns.save(checkIn, ctx);
        await this.publisher.publish(ctx, ...checkIn.pullEvents());

        // A7 exception: audit row commits atomically with check-in row.
        await this.recordAuditEvent.execute(
          {
            checkInId: checkIn.id,
            userId: input.userId,
            eventId: attendance.eventId,
            reason: 'created',
            occurredAt: now,
          },
          ctx,
        );
      }
    });

    // Re-query after creation to return the full pending set.
    // Read-only — no transaction context needed.
    const pending = await this.checkIns.listPendingForUser(input.userId);

    // Enrich each pending check-in with event + host data.
    const items: PendingCheckIn[] = await Promise.all(
      pending.map(async (checkIn) => {
        const [event, host] = await Promise.all([
          this.eventRepo.findById(checkIn.eventId),
          this.userRepo.findById(checkIn.hostUserId),
        ]);

        const rawTitle = event?.title ?? checkIn.eventId;
        const eventTitle =
          rawTitle.length > TITLE_TRUNCATE_MAX
            ? `${rawTitle.slice(0, TITLE_TRUNCATE_MAX)}…`
            : rawTitle;

        return {
          id: checkIn.id,
          eventId: checkIn.eventId,
          eventTitle,
          hostDisplayName: host?.displayName.value ?? checkIn.hostUserId,
          endedAt: event?.endsAt ?? checkIn.createdAt,
          createdAt: checkIn.createdAt,
        };
      }),
    );

    return { items };
  }
}
