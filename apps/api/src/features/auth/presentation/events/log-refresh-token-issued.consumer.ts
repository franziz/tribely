import type { Consumer } from '@/core/events/consumer.port.js';
import { logger } from '@/core/middleware/logger.js';
import {
  REFRESH_TOKEN_ISSUED,
  type RefreshTokenIssuedEvent,
} from '../../domain/events/refresh-token-issued.event.js';

export const logRefreshTokenIssued = (): Consumer<RefreshTokenIssuedEvent> => ({
  name: 'auth.logRefreshTokenIssued',
  topic: REFRESH_TOKEN_ISSUED,
  handle(event, ctx) {
    logger.info(
      {
        userId: event.payload.userId,
        refreshTokenId: event.payload.refreshTokenId,
        deviceLabel: event.payload.deviceLabel,
        requestId: ctx.requestId,
      },
      'auth.refreshTokenIssued',
    );
    return Promise.resolve();
  },
});
