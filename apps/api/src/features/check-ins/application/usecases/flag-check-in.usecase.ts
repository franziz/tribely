import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import { AppError } from '@/core/errors/app-error.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { PostEventCheckInRepository } from '../../domain/repositories/post-event-check-in.repository.js';
import type { PostEventCheckInAuditPort } from '../ports/post-event-check-in-audit.port.js';

export interface FlagCheckInInput {
  id: string;
  userId: string;
  reportBody: string;
  disclaimerAcknowledged: boolean;
}

/**
 * Attendee flags a pending post-event check-in with a safety report
 * (transitions pending → flagged).
 *
 * Errors:
 *   - 404 NOT_FOUND when the check-in does not exist.
 *   - 403 FORBIDDEN when the requesting user is not the attendee on the check-in.
 *   - 422 UNPROCESSABLE disclaimerNotAcknowledged when disclaimerAcknowledged is false.
 *   - 422 UNPROCESSABLE REPORT_EMPTY when reportBody is blank.
 *   - 422 UNPROCESSABLE REPORT_TOO_LONG when reportBody exceeds 2000 chars.
 *   - 409 CONFLICT (from aggregate) when the check-in is not in pending status.
 *
 * The flag use case does NOT send email — that is strictly the consumer's job
 * (Brief B6). This use case only emits the checkIns.checkInFlagged domain event.
 *
 * Audit wire (A7 exception): RecordPostEventCheckInEventUseCase joins the same
 * UoW transaction — the audit row commits atomically with the state mutation.
 */
export class FlagCheckInUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly checkIns: PostEventCheckInRepository,
    private readonly publisher: EventPublisher,
    private readonly recordAuditEvent: PostEventCheckInAuditPort,
    private readonly clock: Clock,
  ) {}

  async execute(input: FlagCheckInInput): Promise<{ ok: true }> {
    const now = this.clock.now();

    await this.unitOfWork.run(async (ctx) => {
      const checkIn = await this.checkIns.findById(input.id, ctx);
      if (!checkIn) {
        throw AppError.notFound(`Check-in ${input.id} not found`);
      }

      if (checkIn.userId !== input.userId) {
        throw AppError.forbidden('Only the attendee may flag this check-in');
      }

      // Business rule: the attendee must explicitly acknowledge the 999 disclaimer
      // before submitting. The schema accepts any boolean so the subcode is
      // preserved for operators; the enforcement lives here per AC6.
      if (!input.disclaimerAcknowledged) {
        throw AppError.unprocessable('You must acknowledge the 999 disclaimer before submitting.', {
          subcode: 'check-ins.disclaimerNotAcknowledged',
        });
      }

      // Aggregate validates REPORT_EMPTY / REPORT_TOO_LONG / CONFLICT status.
      checkIn.flag({
        reportBody: input.reportBody,
        disclaimerAcknowledged: input.disclaimerAcknowledged,
        now,
      });

      await this.checkIns.save(checkIn, ctx);
      await this.publisher.publish(ctx, ...checkIn.pullEvents());

      // A7 exception: audit row commits atomically with check-in mutation.
      await this.recordAuditEvent.execute(
        {
          checkInId: input.id,
          userId: input.userId,
          eventId: checkIn.eventId,
          reason: 'flagged',
          occurredAt: now,
        },
        ctx,
      );
    });

    return { ok: true };
  }
}
