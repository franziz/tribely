import type { EventBus } from '@/core/events/event-bus.port.js';
import { logger } from '@/core/middleware/logger.js';
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

export const registerAuthSubscribers = (bus: EventBus): void => {
  bus.subscribe<CredentialIssuedEvent>(CREDENTIAL_ISSUED, (event) => {
    logger.info({ userId: event.payload.userId }, 'auth.credentialIssued');
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
