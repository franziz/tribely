import type { Consumer } from '@/core/events/consumer.port.js';
import { logger } from '@/core/middleware/logger.js';
import {
  REFRESH_TOKEN_ROTATED,
  type RefreshTokenRotatedEvent,
} from '../../domain/events/refresh-token-rotated.event.js';

export const logRefreshTokenRotated = (): Consumer<RefreshTokenRotatedEvent> => ({
  name: 'auth.logRefreshTokenRotated',
  topic: REFRESH_TOKEN_ROTATED,
  handle(event, ctx) {
    logger.info(
      {
        userId: event.payload.userId,
        from: event.payload.refreshTokenId,
        to: event.payload.rotatedToId,
        requestId: ctx.requestId,
      },
      'auth.refreshTokenRotated',
    );
    return Promise.resolve();
  },
});
