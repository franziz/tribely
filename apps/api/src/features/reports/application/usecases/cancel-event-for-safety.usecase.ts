import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { JoinRequestRepository } from '@/features/join-requests/domain/repositories/join-request.repository.js';
import type { RecordModerationActionUseCase } from '@/features/audit/application/usecases/record-moderation-action.usecase.js';
import type { CancelEventForSafetyResult } from '@/features/reports/application/dto/cancel-event-for-safety.result.js';

export interface CancelEventForSafetyInput {
  operatorUserId: string;
  eventId: string;
  justificationText: string; // 1–500 chars
  originatingReportId: string | null; // optional Cat 4 cross-ref
}

const JUSTIFICATION_MAX = 500;
const SAFETY_CANCELLATION_REASON = 'Cancelled by Tribely safety team';

/**
 * CLI-only orchestrator that cancels an event for safety reasons AND records
 * the audit row in ONE wrapping UnitOfWork.
 *
 * Intentionally does NOT call CancelEventUseCase.execute() — that use case
 * opens its own UoW which would break atomicity with the audit-row write
 * (PDPA s24 evidence integrity). This pattern mirrors PerformModerationActionUseCase
 * (TRI-141). PM blessed this deviation; AC #4 updated in Linear.
 *
 * The cancellation reason stored on the Event aggregate is a fixed, user-facing
 * string ("Cancelled by Tribely safety team") — NOT the operator-supplied
 * justification. The safety justification lives ONLY in the audit row
 * (justificationText column). This separation ensures moderation-sensitive
 * operator notes are never exposed to event participants.
 *
 * Concurrent invocation: step 3 pre-checks event.status BEFORE opening the
 * transaction, so the second concurrent invocation sees status='cancelled' on
 * read and throws EVENT_ALREADY_CANCELLED. No row-level lock is needed — this
 * is a CLI; the race window is operationally negligible (both ops would have
 * the same intent, and the audit trail captures both attempts).
 *
 * Zero-RSVP case: notifiedCount=0 is valid; the cancellation and audit write
 * still proceed. The notification consumer (Brief A) is a no-op when the
 * join-request list is empty.
 */
export class CancelEventForSafetyUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly events: EventRepository,
    private readonly joinRequests: JoinRequestRepository,
    private readonly publisher: EventPublisher,
    private readonly recordAudit: RecordModerationActionUseCase,
    private readonly clock: Clock,
  ) {}

  async execute(input: CancelEventForSafetyInput): Promise<CancelEventForSafetyResult> {
    // Step 1: resolve `now` via injected Clock.
    const now = this.clock.now();

    // Step 2: load event — 404 if missing.
    const event = await this.events.findById(input.eventId);
    if (!event) throw AppError.notFound('Event not found');

    // Step 3: refusal pre-flight — terminal/past-end states.
    if (event.status === 'cancelled') {
      throw AppError.conflict('Event already cancelled', { subcode: 'EVENT_ALREADY_CANCELLED' });
    }
    if (event.status === 'completed') {
      throw AppError.conflict('Event already completed', { subcode: 'EVENT_ALREADY_COMPLETED' });
    }
    if (event.endsAt.getTime() < now.getTime()) {
      throw AppError.conflict('Event has ended', { subcode: 'EVENT_PAST_END_TIME' });
    }

    // Step 4: validate justificationText (trimmed, 1–500 chars).
    const trimmedJustification = input.justificationText.trim();
    if (trimmedJustification.length === 0 || trimmedJustification.length > JUSTIFICATION_MAX) {
      throw AppError.unprocessable(
        `Justification must be 1–${String(JUSTIFICATION_MAX)} characters`,
      );
    }

    // Step 5: fetch active joiner count (approved + pending) — used as notifiedCount.
    // Read OUTSIDE the transaction: this is a snapshot for the notification fan-out
    // estimate; Brief A's consumer handles the actual delivery and will re-query if needed.
    const activeJoiners = await this.joinRequests.findByEvent(input.eventId, {
      status: ['approved', 'pending'],
    });
    const notifiedCount = activeJoiners.length;

    // Step 6: open one UnitOfWork — all mutations + audit row commit atomically.
    const auditRowId = createId(); // generated up-front so we can return it post-commit.

    await this.unitOfWork.run(async (ctx) => {
      // 6a. Apply state transition on the aggregate.
      // event.cancel() is idempotent on 'cancelled', but step 3 already throws
      // EVENT_ALREADY_CANCELLED before we reach here — so this call sees a live event.
      event.cancel(SAFETY_CANCELLATION_REASON, now);

      // 6b. Persist the cancelled state.
      await this.events.save(event, ctx);

      // 6c. Publish the domain event (emits events.eventCancelled).
      // Brief A's consumer subscribes to this topic and handles notification fan-out.
      await this.publisher.publish(ctx, ...event.pullEvents());

      // 6d. Record the safety audit row atomically with the state transition (PDPA s24).
      // Both reportId and originatingReportId receive input.originatingReportId:
      // the legacy reportId column is nullable per ae28313; for cancel_event_for_safety
      // the originating report (if any) is the same reference for both columns.
      await this.recordAudit.execute(
        {
          id: auditRowId,
          operatorUserId: input.operatorUserId,
          action: 'cancel_event_for_safety',
          reportId: input.originatingReportId,
          targetType: 'event',
          targetId: input.eventId,
          reason: null, // reason column is for resolve-hide/keep narratives; not used here.
          reasonCode: 'safety',
          justificationText: trimmedJustification,
          originatingReportId: input.originatingReportId,
          contentSnapshot: null,
          reporterUserId: null, // no reporter on cancel_event_for_safety rows (ae28313 made nullable).
          actedAt: now,
        },
        ctx,
      );
    });

    // Step 7: return result.
    return { auditRowId, notifiedCount };
  }
}
