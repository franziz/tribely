import type { Consumer } from '@/core/events/consumer.port.js';
import {
  USER_REGISTERED,
  type UserRegisteredEvent,
} from '@/features/users/domain/events/user-registered.event.js';
import type { IssueEmailVerificationUseCase } from '../../application/usecases/issue-email-verification.usecase.js';

export interface IssueEmailVerificationOnUserRegisteredDeps {
  issueEmailVerification: IssueEmailVerificationUseCase;
}

/**
 * After a user registers, issue + email their verification code.
 *
 * Idempotent: IssueEmailVerificationUseCase already invalidates any
 * pre-existing open token before issuing a new one (`reason='replaced'`)
 * and no-ops when the user is already verified. Re-delivery of the same
 * userRegistered event therefore only ever sends *one* fresh code.
 *
 * Errors propagate up so the dispatcher records the dispatch as `failed`
 * and retries on the next tick. After 5 attempts the consumer parks; ops
 * gets a row in `consumer_offsets.blockedAt`. The user can also hit
 * /auth/resend-verification at any time.
 */
export const issueEmailVerificationOnUserRegistered = (
  deps: IssueEmailVerificationOnUserRegisteredDeps,
): Consumer<UserRegisteredEvent> => ({
  name: 'auth.issueEmailVerificationOnUserRegistered',
  topic: USER_REGISTERED,
  async handle(event) {
    await deps.issueEmailVerification.execute({ userId: event.payload.userId });
  },
});
