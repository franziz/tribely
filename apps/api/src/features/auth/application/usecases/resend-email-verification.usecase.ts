import { AppError } from '@/core/errors/app-error.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { IssueEmailVerificationUseCase } from './issue-email-verification.usecase.js';

export interface ResendEmailVerificationInput {
  userId: string;
}

/**
 * Re-issues a verification code for the current user. Thin wrapper over
 * IssueEmailVerificationUseCase that adds two policy checks the issue path
 * doesn't care about:
 *   - 404 if the user doesn't exist (sanity check; should never happen on
 *     an auth-required route)
 *   - 409 if the user is already verified (saves a useless email send and
 *     gives the mobile client a clean signal to update its UI)
 *
 * The route layer adds a 1/min/user rate limit on top.
 */
export class ResendEmailVerificationUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly issue: IssueEmailVerificationUseCase,
  ) {}

  async execute(input: ResendEmailVerificationInput): Promise<void> {
    const user = await this.users.findById(input.userId);
    if (!user) throw AppError.notFound('User not found');
    if (user.isEmailVerified()) {
      throw AppError.conflict('Email already verified');
    }
    await this.issue.execute({ userId: user.id });
  }
}
