import { createId } from '@paralleldrive/cuid2';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import { AppError } from '@/core/errors/app-error.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { Event } from '@/features/events/domain/entities/event.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { SafetyReminderMarkerPort } from '@/features/users/application/ports/safety-reminder-marker.port.js';
import { JoinRequest, type JoinRequestEventSnapshot } from '../../domain/entities/join-request.js';
import type { JoinRequestRepository } from '../../domain/repositories/join-request.repository.js';

export interface RequestToJoinEventInput {
  eventId: string;
  requesterUserId: string;
  acknowledgedSafetyReminder?: boolean;
}

/**
 * Submit a request to join an event.
 *
 * Two paths converge in the same use case:
 *   - MANUAL approval — request lands pending; the host decides later.
 *   - AUTO approval — request lands pending+approved in the same aggregate
 *     (the `JoinRequest.request({ autoApprove: true })` factory records both
 *     events). The capacity check runs inside the same SELECT FOR UPDATE
 *     transaction that produced the approval, so two concurrent auto-joins
 *     can't both grab the last seat.
 *
 * Pre-checks (status, host self-join, existing active request) happen OUTSIDE
 * the transaction so the common-case rejection path doesn't acquire a row lock.
 * The auto-approve path then RE-VERIFIES `status === 'published'` and
 * `endsAt > now` after acquiring the lock — between the pre-read and the lock,
 * the host could have cancelled the event.
 *
 * Capacity rule: `approvedCount < event.capacity.value - 1` (capacity includes
 * the host, so the seats available to requesters are `capacity - 1`). The
 * aggregate itself stays ignorant of capacity — it lives in the use case
 * because it requires a cross-aggregate count.
 */
export class RequestToJoinEventUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly joinRequests: JoinRequestRepository,
    private readonly events: EventRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
    private readonly safetyReminderMarker: SafetyReminderMarkerPort,
  ) {}

  async execute(input: RequestToJoinEventInput): Promise<JoinRequest> {
    // Set-on-tap: if the client sent the safety acknowledgement, mark it seen
    // in its own independent UoW BEFORE the join transaction. This way the
    // seen-flag persists even if the subsequent join fails (capacity, conflict,
    // etc.) — the user is not re-shown the safety sheet on retry.
    if (input.acknowledgedSafetyReminder === true) {
      await this.safetyReminderMarker.execute({
        userId: input.requesterUserId,
        eventId: input.eventId,
      });
    }

    const now = this.clock.now();

    const event = await this.events.findById(input.eventId);
    if (!event) throw AppError.notFound(`Event ${input.eventId} not found`);

    assertEventAcceptingRequests(event, now);

    if (event.hostUserId === input.requesterUserId) {
      throw AppError.conflict('You cannot join your own event', {
        subcode: 'CANNOT_JOIN_OWN_EVENT',
      });
    }

    const existing = await this.joinRequests.findActiveByEventAndRequester(
      input.eventId,
      input.requesterUserId,
    );
    if (existing) {
      throw AppError.conflict('You already have an active request for this event', {
        subcode: 'ACTIVE_REQUEST_EXISTS',
      });
    }

    const latest = await this.joinRequests.findLatestByRequesterAndEvent(
      input.requesterUserId,
      input.eventId,
    );
    if (latest?.status === 'removed_by_host') {
      throw AppError.forbidden('You cannot request to join this event again', {
        subcode: 'REMOVED_BY_HOST_REREQUEST_BLOCKED',
      });
    }

    const autoApprove = event.approvalMode === 'auto';
    const id = createId();

    const jr = await this.unitOfWork.run(async (ctx) => {
      let snapshotSource = event;
      if (autoApprove) {
        // Re-read under FOR UPDATE so the capacity count + approve happen
        // serialized with sibling approvals/auto-joins. If status changed
        // between pre-read and lock, fail loudly.
        const locked = await this.events.findByIdForUpdate(input.eventId, ctx);
        if (!locked) throw AppError.notFound(`Event ${input.eventId} not found`);
        assertEventAcceptingRequests(locked, now);
        const approvedCount = await this.joinRequests.countApproved(locked.id, ctx);
        if (approvedCount >= locked.capacity.value - 1) {
          throw AppError.conflict('Event is full', { subcode: 'CAPACITY_FULL' });
        }
        snapshotSource = locked;
      }

      const snapshot = buildSnapshot(snapshotSource);
      const created = JoinRequest.request({
        id,
        eventId: input.eventId,
        requesterUserId: input.requesterUserId,
        now,
        autoApprove,
        hostUserId: snapshotSource.hostUserId,
        eventSnapshot: snapshot,
      });

      // Race-loser on the partial unique (eventId, requesterUserId WHERE
      // status IN ('pending','approved')) surfaces as AppError.conflict here
      // — the Prisma repo maps it to subcode ACTIVE_REQUEST_EXISTS so the
      // pre-check and the post-check converge on the same shape.
      await this.joinRequests.save(created, ctx);
      await this.publisher.publish(ctx, ...created.pullEvents());
      return created;
    });

    return jr;
  }
}

const assertEventAcceptingRequests = (event: Event, now: Date): void => {
  if (event.status === 'cancelled') {
    throw AppError.conflict('Event has been cancelled', { subcode: 'EVENT_CANCELLED' });
  }
  if (event.status === 'completed' || event.endsAt.getTime() <= now.getTime()) {
    throw AppError.conflict('Event has already started or ended', {
      subcode: 'EVENT_ALREADY_STARTED',
    });
  }
  if (event.status !== 'published') {
    // draft — not publicly visible, so 404-shape would be misleading; 409 with
    // a distinct subcode makes the "exists but not joinable" case explicit.
    throw AppError.conflict('Event is not open to requests', {
      subcode: 'EVENT_NOT_PUBLISHED',
    });
  }
};

const buildSnapshot = (event: Event): JoinRequestEventSnapshot => ({
  startsAt: event.startsAt,
  endsAt: event.endsAt,
  venue: {
    address: event.venue.address,
    city: event.venue.city,
    latitude: event.venue.latitude,
    longitude: event.venue.longitude,
  },
  hostUserId: event.hostUserId,
});
