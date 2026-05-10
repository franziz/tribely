import type { Consumer } from '@/core/events/consumer.port.js';
import { logger } from '@/core/middleware/logger.js';
import {
  REFRESH_TOKEN_REUSE_DETECTED,
  type RefreshTokenReuseDetectedEvent,
} from '../../domain/events/refresh-token-reuse-detected.event.js';

/**
 * Critical security signal — escalate to WARN. Future iteration: also
 * notify the user via email and consider locking the account.
 */
export const logRefreshTokenReuseDetected = (): Consumer<RefreshTokenReuseDetectedEvent> => ({
  name: 'auth.logRefreshTokenReuseDetected',
  topic: REFRESH_TOKEN_REUSE_DETECTED,
  handle(event, ctx) {
    logger.warn(
      {
        userId: event.payload.userId,
        refreshTokenId: event.payload.refreshTokenId,
        requestId: ctx.requestId,
      },
      'auth.refreshTokenReuseDetected',
    );
    return Promise.resolve();
  },
});
