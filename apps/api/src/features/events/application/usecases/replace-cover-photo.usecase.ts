import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { Event } from '../../domain/entities/event.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';

export interface ReplaceCoverPhotoInput {
  eventId: string;
  actorUserId: string;
  coverPhotoStorageKey: string;
}

/**
 * Replace the cover photo on an existing Event. Host-only: only the host
 * may call this endpoint; AC6 requires the 403 be enforced server-side,
 * not merely UI-hidden.
 *
 * Ownership-prefix guard: `coverPhotoStorageKey` must start with
 * `events/<actorUserId>/` — rejects cross-host key injection, mirrors
 * `CreateEventUseCase` (TRI-49) and `ConfirmAvatarUploadUseCase` (TRI-24).
 *
 * The aggregate handles the no-op case internally — if the supplied key
 * matches the current key, no event is recorded and `updatedAt` is left alone.
 *
 * AC3/AC5: the HTTP schema requires a non-null, non-empty key, so there is
 * no "remove cover" path through this use case.
 */
export class ReplaceCoverPhotoUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly events: EventRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: ReplaceCoverPhotoInput): Promise<Event> {
    const event = await this.events.findById(input.eventId);
    if (!event) throw AppError.notFound(`Event ${input.eventId} not found`);

    // AC6: host-only enforced server-side (mirrors update-event.usecase.ts:56-60).
    if (event.hostUserId !== input.actorUserId) {
      throw AppError.forbidden('Only the host may replace the cover photo');
    }

    // Ownership-prefix guard (security-critical): rejects cross-host key injection
    // (mirrors create-event.usecase.ts:103-111).
    const expectedPrefix = `events/${input.actorUserId}/`;
    if (!input.coverPhotoStorageKey.startsWith(expectedPrefix)) {
      throw AppError.forbidden('coverPhotoStorageKey does not belong to this host', {
        hostUserId: input.actorUserId,
        coverPhotoStorageKey: input.coverPhotoStorageKey,
      });
    }

    event.setCoverPhoto(input.coverPhotoStorageKey, this.clock.now());

    const pending = event.pullEvents();
    if (pending.length === 0) {
      // No-op — key unchanged, don't even open a transaction.
      return event;
    }

    await this.unitOfWork.run(async (ctx) => {
      await this.events.save(event, ctx);
      await this.publisher.publish(ctx, ...pending);
    });

    return event;
  }
}
