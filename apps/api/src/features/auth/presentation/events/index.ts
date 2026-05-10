import type { EventBus } from '@/core/events/event-bus.port.js';
import { logger } from '@/core/middleware/logger.js';
import {
  USER_REGISTERED,
  type UserRegisteredEvent,
} from '@/features/users/domain/events/user-registered.event.js';
import type { IssueEmailVerificationUseCase } from '../../application/usecases/issue-email-verification.usecase.js';
import {
  CREDENTIAL_ISSUED,
  type CredentialIssuedEvent,
} from '../../domain/events/credential-issued.event.js';
import {
  REFRESH_TOKEN_ISSUED,
  type RefreshTokenIssuedEvent,
} from '../../domain/events/refresh-token-issued.event.js';
import {
  REFRESH_TOKEN_REUSE_DETECTED,
  type RefreshTokenReuseDetectedEvent,
} from '../../domain/events/refresh-token-reuse-detected.event.js';
import {
  REFRESH_TOKEN_REVOKED,
  type RefreshTokenRevokedEvent,
} from '../../domain/events/refresh-token-revoked.event.js';
import {
  REFRESH_TOKEN_ROTATED,
  type RefreshTokenRotatedEvent,
} from '../../domain/events/refresh-token-rotated.event.js';
import {
  USER_SIGNED_IN,
  type UserSignedInEvent,
} from '../../domain/events/user-signed-in.event.js';

export interface AuthSubscriberDeps {
  issueEmailVerification: IssueEmailVerificationUseCase;
}

export const registerAuthSubscribers = (bus: EventBus, deps: AuthSubscriberDeps): void => {
  bus.subscribe<CredentialIssuedEvent>(CREDENTIAL_ISSUED, (event) => {
    logger.info({ userId: event.payload.userId }, 'auth.credentialIssued');
  });

  // After a user registers, issue + email a verification code. Runs through
  // the transactional outbox, so this is at-least-once — IssueEmailVerification
  // is idempotent on userId. Failures here are logged but not rethrown:
  // sign-up has already committed, and the user can hit /resend-verification
  // if the email never arrives.
  bus.subscribe<UserRegisteredEvent>(USER_REGISTERED, async (event) => {
    try {
      await deps.issueEmailVerification.execute({ userId: event.payload.userId });
    } catch (err) {
      logger.error(
        { err, userId: event.payload.userId },
        'auth.issueEmailVerification failed (user can resend)',
      );
    }
  });

  bus.subscribe<UserSignedInEvent>(USER_SIGNED_IN, (event) => {
    logger.info({ userId: event.payload.userId }, 'auth.userSignedIn');
  });

  bus.subscribe<RefreshTokenIssuedEvent>(REFRESH_TOKEN_ISSUED, (event) => {
    logger.info(
      {
        userId: event.payload.userId,
        refreshTokenId: event.payload.refreshTokenId,
        deviceLabel: event.payload.deviceLabel,
      },
      'auth.refreshTokenIssued',
    );
  });

  bus.subscribe<RefreshTokenRotatedEvent>(REFRESH_TOKEN_ROTATED, (event) => {
    logger.info(
      {
        userId: event.payload.userId,
        from: event.payload.refreshTokenId,
        to: event.payload.rotatedToId,
      },
      'auth.refreshTokenRotated',
    );
  });

  bus.subscribe<RefreshTokenRevokedEvent>(REFRESH_TOKEN_REVOKED, (event) => {
    logger.info(
      {
        userId: event.payload.userId,
        refreshTokenId: event.payload.refreshTokenId,
        reason: event.payload.reason,
      },
      'auth.refreshTokenRevoked',
    );
  });

  // Critical security signal — escalate logging to WARN. Real production
  // handlers might also notify the user via email and lock the account.
  bus.subscribe<RefreshTokenReuseDetectedEvent>(REFRESH_TOKEN_REUSE_DETECTED, (event) => {
    logger.warn(
      {
        userId: event.payload.userId,
        refreshTokenId: event.payload.refreshTokenId,
      },
      'auth.refreshTokenReuseDetected',
    );
  });
};
