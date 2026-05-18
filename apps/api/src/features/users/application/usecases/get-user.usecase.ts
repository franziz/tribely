import { AppError } from '@/core/errors/app-error.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import {
  computeIsVerified,
  type VerificationSignalId,
} from '../projections/is-verified.projection.js';
import type { GetUserResult } from '../dto/get-user-result.dto.js';

export interface GetUserInput {
  id: string;
}

export class GetUserUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly signalSet: VerificationSignalId[],
  ) {}

  async execute(input: GetUserInput): Promise<GetUserResult> {
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
