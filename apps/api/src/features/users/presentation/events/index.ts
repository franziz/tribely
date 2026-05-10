import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';
import { logUserRegistered } from './log-user-registered.consumer.js';

/**
 * Register every consumer the `users` feature owns. Called once at boot
 * from buildContainer().
 */
export const registerUsersConsumers = (registry: ConsumerRegistry): void => {
  registry.register(logUserRegistered());
};
