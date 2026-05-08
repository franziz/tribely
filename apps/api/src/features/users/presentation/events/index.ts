import type { EventBus } from '@/core/events/event-bus.port.js';
import { logger } from '@/core/middleware/logger.js';
import {
  USER_REGISTERED,
  type UserRegisteredEvent,
} from '../../domain/events/user-registered.event.js';

/**
 * Subscribers for events the `users` feature reacts to. Even though the
 * feature emits userRegistered itself, no internal handler is required —
 * other features (e.g. notifications) subscribe from their own
 * presentation/events/index.ts.
 */
export const registerUsersSubscribers = (bus: EventBus): void => {
  bus.subscribe<UserRegisteredEvent>(USER_REGISTERED, (event) => {
    logger.info(
      { userId: event.payload.userId, email: event.payload.email },
      'users.userRegistered',
    );
  });
};
