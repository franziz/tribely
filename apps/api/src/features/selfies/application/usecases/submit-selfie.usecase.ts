import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/index.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { Selfie } from '../../domain/entities/selfie.js';
import type { SelfieRepository } from '../../domain/repositories/selfie.repository.js';

export interface SubmitSelfieInput {
  userId: string;
  storageKey: string;
}

/**
 * Records a new pending selfie submission for the authenticated user.
 *
 * Guards:
 *   - `selfieAppealLockedAt !== null`  → 409 CONFLICT (user is locked out via
 *     the appeal path; they must await moderator approval before re-submitting).
 *   - `selfieStatus === 'approved'`    → 409 CONFLICT (already verified).
 *   - `selfieStatus === 'pending'`     → 409 CONFLICT (review already in flight).
 *   - `storageKey` prefix !== `uploads/<userId>/` → 403 FORBIDDEN (key doesn't
 *     belong to this user — rejects cross-user key injection).
 *
 * On success: creates a pending Selfie row and atomically publishes its
 * collected events (none at time of writing — YAGNI no submit event per EL).
 * The pending row surfaces in the admin moderation queue (TRI-13).
 */
export class SubmitSelfieUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly selfies: SelfieRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: SubmitSelfieInput): Promise<void> {
    // Validate storageKey ownership before hitting the DB.
    const expectedPrefix = `uploads/${input.userId}/`;
    if (!input.storageKey.startsWith(expectedPrefix)) {
      throw AppError.forbidden('storageKey does not belong to this user', {
        userId: input.userId,
        storageKey: input.storageKey,
      });
    }

    await this.unitOfWork.run(async (ctx) => {
      const user = await this.users.findById(input.userId, ctx);
      if (!user) throw AppError.notFound(`User ${input.userId} not found`);

      // TRI-70 lockout rule: appeal lock blocks re-submission.
      if (user.selfieAppealLockedAt !== null) {
        throw AppError.conflict(
          'Your account is locked out of selfie submission. ' + 'Please contact support to appeal.',
          { code: 'SELFIE_APPEAL_LOCKED' },
        );
      }

      if (user.selfieStatus === 'approved') {
        throw AppError.conflict('Your identity has already been verified.');
      }

      if (user.selfieStatus === 'pending') {
        throw AppError.conflict(
          'A selfie is already under review. ' + 'Please wait for the current review to complete.',
        );
      }

      const selfie = Selfie.create({
        id: createId(),
        userId: input.userId,
        storageKey: input.storageKey,
        now: this.clock.now(),
      });

      await this.selfies.save(selfie, ctx);
      await this.publisher.publish(ctx, ...selfie.pullEvents());
    });
  }
}
