import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';
import type { IssueEmailVerificationUseCase } from '../../application/usecases/issue-email-verification.usecase.js';
import { issueEmailVerificationOnUserRegistered } from './issue-email-verification-on-user-registered.consumer.js';
import { logCredentialIssued } from './log-credential-issued.consumer.js';
import { logRefreshTokenIssued } from './log-refresh-token-issued.consumer.js';
import { logRefreshTokenReuseDetected } from './log-refresh-token-reuse-detected.consumer.js';
import { logRefreshTokenRevoked } from './log-refresh-token-revoked.consumer.js';
import { logRefreshTokenRotated } from './log-refresh-token-rotated.consumer.js';
import { logUserSignedIn } from './log-user-signed-in.consumer.js';

export interface AuthConsumerDeps {
  issueEmailVerification: IssueEmailVerificationUseCase;
}

/**
 * Register every consumer the `auth` feature owns. Called once at boot
 * from buildContainer().
 */
export const registerAuthConsumers = (registry: ConsumerRegistry, deps: AuthConsumerDeps): void => {
  registry.register(logCredentialIssued());
  registry.register(logUserSignedIn());
  registry.register(logRefreshTokenIssued());
  registry.register(logRefreshTokenRotated());
  registry.register(logRefreshTokenRevoked());
  registry.register(logRefreshTokenReuseDetected());
  registry.register(
    issueEmailVerificationOnUserRegistered({
      issueEmailVerification: deps.issueEmailVerification,
    }),
  );
};
