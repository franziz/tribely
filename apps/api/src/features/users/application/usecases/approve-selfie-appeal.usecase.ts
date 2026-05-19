import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/index.js';
import { AppError } from '@/core/errors/app-error.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';

export interface ApproveSelfieAppealInput {
  userId: string;
}

export class ApproveSelfieAppealUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: ApproveSelfieAppealInput): Promise<void> {
    await this.unitOfWork.run(async (ctx) => {
      const user = await this.users.findById(input.userId, ctx);
      if (!user) throw AppError.notFound(`User ${input.userId} not found`);

      user.recordSelfieAppealApproved({ now: this.clock.now() });

      await this.users.save(user, ctx);
      await this.publisher.publish(ctx, ...user.pullEvents());
    });
  }
}
