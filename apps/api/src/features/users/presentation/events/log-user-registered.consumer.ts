import type { Consumer } from '@/core/events/consumer.port.js';
import { logger } from '@/core/middleware/logger.js';
import {
  USER_REGISTERED,
  type UserRegisteredEvent,
} from '../../domain/events/user-registered.event.js';

/**
 * Diagnostic consumer: logs every userRegistered event. Idempotent — logging
 * the same event twice is harmless. Lives in the users feature so the audit
 * trail attributes "I observed this" to the right bounded context.
 */
export const logUserRegistered = (): Consumer<UserRegisteredEvent> => ({
  name: 'users.logUserRegistered',
  topic: USER_REGISTERED,
  handle(event, ctx) {
    logger.info(
      {
        userId: event.payload.userId,
        email: event.payload.email,
        requestId: ctx.requestId,
        attempt: ctx.attempt,
      },
      'users.userRegistered',
    );
    return Promise.resolve();
  },
});
