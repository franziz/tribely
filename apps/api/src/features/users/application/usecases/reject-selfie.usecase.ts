import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/index.js';
import { AppError } from '@/core/errors/app-error.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import type { SelfieFailureCategory } from '../../domain/value-objects/selfie-failure-category.js';

export interface RejectSelfieInput {
  userId: string;
  failureCategory: SelfieFailureCategory;
}

export class RejectSelfieUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: RejectSelfieInput): Promise<void> {
    await this.unitOfWork.run(async (ctx) => {
      const user = await this.users.findById(input.userId, ctx);
      if (!user) throw AppError.notFound(`User ${input.userId} not found`);

      // Idempotency via natural-key check on aggregate state:
      // If the aggregate already reflects this exact rejection (status=rejected,
      // same failureCategory, and at least one attempt recorded), the event was
      // already emitted and persisted. Short-circuit to prevent double-increment
      // and duplicate event emission. We do NOT consult the outbox — the
      // aggregate state IS the idempotency boundary. If the status or category
      // has changed since the first call, this is a new rejection and proceeds.
      if (
        user.selfieStatus === 'rejected' &&
        user.selfieLastFailureCategory === input.failureCategory &&
        user.selfieAttemptCount > 0
      ) {
        return; // already applied — no-op
      }

      user.recordSelfieRejection({ failureCategory: input.failureCategory, now: this.clock.now() });

      await this.users.save(user, ctx);
      await this.publisher.publish(ctx, ...user.pullEvents());
    });
  }
}
