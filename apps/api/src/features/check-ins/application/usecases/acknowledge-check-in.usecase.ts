import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import { AppError } from '@/core/errors/app-error.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { PostEventCheckInRepository } from '../../domain/repositories/post-event-check-in.repository.js';
import type { PostEventCheckInAuditPort } from '../ports/post-event-check-in-audit.port.js';

export interface AcknowledgeCheckInInput {
  id: string;
  userId: string;
}

/**
 * Attendee acknowledges a pending post-event check-in (transitions pending → ok).
 *
 * Errors:
 *   - 404 NOT_FOUND when the check-in does not exist.
 *   - 403 FORBIDDEN when the requesting user is not the attendee on the check-in.
 *   - 409 CONFLICT (from aggregate) when the check-in is not in pending status.
 *
 * Audit wire (A7 exception): RecordPostEventCheckInEventUseCase joins the same
 * UoW transaction — the audit row commits atomically with the state mutation.
 */
export class AcknowledgeCheckInUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly checkIns: PostEventCheckInRepository,
    private readonly publisher: EventPublisher,
    private readonly recordAuditEvent: PostEventCheckInAuditPort,
    private readonly clock: Clock,
  ) {}

  async execute(input: AcknowledgeCheckInInput): Promise<{ ok: true }> {
    const now = this.clock.now();

    await this.unitOfWork.run(async (ctx) => {
      const checkIn = await this.checkIns.findById(input.id, ctx);
      if (!checkIn) {
        throw AppError.notFound(`Check-in ${input.id} not found`);
      }

      if (checkIn.userId !== input.userId) {
        throw AppError.forbidden('Only the attendee may acknowledge this check-in');
      }

      checkIn.acknowledge({ now });

      await this.checkIns.save(checkIn, ctx);
      await this.publisher.publish(ctx, ...checkIn.pullEvents());

      // A7 exception: audit row commits atomically with check-in mutation.
      await this.recordAuditEvent.execute(
        {
          checkInId: input.id,
          userId: input.userId,
          eventId: checkIn.eventId,
          reason: 'acknowledged',
          occurredAt: now,
        },
        ctx,
      );
    });

    return { ok: true };
  }
}
