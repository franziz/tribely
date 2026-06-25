import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/index.js';
import { AppError } from '@/core/errors/app-error.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import type { SelfieRepository } from '@/features/selfies/domain/repositories/selfie.repository.js';

export interface ApproveSelfieInput {
  userId: string;
}

/**
 * Moderator approves a pending selfie submission.
 *
 * Transitions both aggregates atomically in one UnitOfWork:
 *   - User: sets selfieStatus → 'approved', records `users.selfieApproved`.
 *   - Selfie: sets status → 'approved', sets approvedAt.
 *
 * Idempotency: if the User aggregate already reflects approval
 * (selfieStatus === 'approved'), we short-circuit — no mutation, no event.
 * This mirrors the guard in ApproveSelfieAppealUseCase.
 *
 * Guard: selfieStatus must be 'pending' (else 409 CONFLICT) on the non-
 * idempotent path. A missing active selfie row is a data-integrity anomaly
 * (user shows pending but no selfie row) — that path still applies the User
 * state change so the admin queue is cleared, and the missing Selfie row is
 * tolerated (it may have been swept already).
 */
export class ApproveSelfieUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly selfies: SelfieRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: ApproveSelfieInput): Promise<void> {
    await this.unitOfWork.run(async (ctx) => {
      const user = await this.users.findById(input.userId, ctx);
      if (!user) throw AppError.notFound(`User ${input.userId} not found`);

      // Idempotency: already approved — no-op (mirrors ApproveSelfieAppealUseCase).
      if (user.selfieStatus === 'approved') return;

      if (user.selfieStatus !== 'pending') {
        throw AppError.conflict(
          `Cannot approve selfie: user ${input.userId} selfieStatus is ` +
            `'${String(user.selfieStatus)}', expected 'pending'`,
        );
      }

      const now = this.clock.now();

      // Transition the User aggregate — records users.selfieApproved.
      user.approveSelfie({ now });

      // Transition the Selfie aggregate if an active row exists.
      const selfie = await this.selfies.findActiveByUserId(input.userId, ctx);
      if (selfie) {
        selfie.approve(now);
        await this.selfies.save(selfie, ctx);
      }

      await this.users.save(user, ctx);
      await this.publisher.publish(ctx, ...user.pullEvents());
    });
  }
}
