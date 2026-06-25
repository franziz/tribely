import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/index.js';
import { AppError } from '@/core/errors/app-error.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';

export interface UpdateUserProfileInput {
  /** The authenticated user's id. Only the owner may update their own profile. */
  userId: string;
  /** All fields are optional patch semantics: absent → unchanged; null → clear. */
  bio?: string | null;
  // avatarUrl is intentionally absent: avatar updates go through the dedicated
  // presign + confirm pipeline (TRI-24). The aggregate's updateProfile method
  // still handles avatarUrl internally — it is only excluded from this use case's
  // input, not from the domain.
  languages?: string[];
  interests?: string[];
  currentCity?: string | null;
  travelerType?: string | null;
  now: Date;
}

export class UpdateUserProfileUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly publisher: EventPublisher,
  ) {}

  async execute(input: UpdateUserProfileInput): Promise<void> {
    await this.unitOfWork.run(async (ctx) => {
      const user = await this.users.findById(input.userId, ctx);
      if (!user) throw AppError.notFound(`User ${input.userId} not found`);

      // Pull only the profile-related keys; spread ensures absent keys stay absent
      // (undefined is not the same as null — absent key = no change).
      const { userId: _userId, now, ...profileFields } = input;
      user.updateProfile({ ...profileFields, now });

      await this.users.save(user, ctx);
      await this.publisher.publish(ctx, ...user.pullEvents());
    });
  }
}
