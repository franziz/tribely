import type { Consumer } from '@/core/events/consumer.port.js';
import { logger } from '@/core/middleware/logger.js';
import {
  REFRESH_TOKEN_REVOKED,
  type RefreshTokenRevokedEvent,
} from '../../domain/events/refresh-token-revoked.event.js';

export const logRefreshTokenRevoked = (): Consumer<RefreshTokenRevokedEvent> => ({
  name: 'auth.logRefreshTokenRevoked',
  topic: REFRESH_TOKEN_REVOKED,
  handle(event, ctx) {
    logger.info(
      {
        userId: event.payload.userId,
        refreshTokenId: event.payload.refreshTokenId,
        reason: event.payload.reason,
        requestId: ctx.requestId,
      },
      'auth.refreshTokenRevoked',
    );
    return Promise.resolve();
  },
});
