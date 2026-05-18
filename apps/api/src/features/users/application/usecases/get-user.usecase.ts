import { AppError } from '@/core/errors/app-error.js';
import type { User } from '../../domain/entities/user.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import {
  computeIsVerified,
  type VerificationSignalId,
} from '../projections/is-verified.projection.js';

export interface GetUserInput {
  id: string;
}

export class GetUserUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly signalSet: VerificationSignalId[],
  ) {}

  async execute(input: GetUserInput): Promise<{ user: User; isVerified: boolean }> {
    const user = await this.users.findById(input.id);
    if (!user) throw AppError.notFound(`User ${input.id} not found`);

    const isVerified = computeIsVerified(
      {
        emailVerifiedAt: user.emailVerifiedAt,
        // TODO(TRI-16): replace with user.phoneVerifiedAt once phone column lands
        phoneVerifiedAt: null,
        // TODO(TRI-23): replace with user.selfieApprovedAt once selfie column lands
        selfieApprovedAt: null,
      },
      this.signalSet,
    );

    return { user, isVerified };
  }
}
