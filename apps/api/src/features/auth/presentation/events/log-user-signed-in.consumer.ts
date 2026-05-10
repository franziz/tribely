import type { Consumer } from '@/core/events/consumer.port.js';
import { logger } from '@/core/middleware/logger.js';
import {
  USER_SIGNED_IN,
  type UserSignedInEvent,
} from '../../domain/events/user-signed-in.event.js';

export const logUserSignedIn = (): Consumer<UserSignedInEvent> => ({
  name: 'auth.logUserSignedIn',
  topic: USER_SIGNED_IN,
  handle(event, ctx) {
    logger.info({ userId: event.payload.userId, requestId: ctx.requestId }, 'auth.userSignedIn');
    return Promise.resolve();
  },
});
