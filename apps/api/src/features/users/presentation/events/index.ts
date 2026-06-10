import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';
import { logUserRegistered } from './log-user-registered.consumer.js';
import { resetSafetyReminderOnCheckInFlagged } from './reset-safety-reminder-on-check-in-flagged.consumer.js';

export interface UsersConsumerDeps {
  resetSafetyReminderSeen: { execute(input: { userId: string }): Promise<void> };
}

/**
 * Register every consumer the `users` feature owns. Called once at boot
 * from buildContainer().
 */
export const registerUsersConsumers = (
  registry: ConsumerRegistry,
  deps: UsersConsumerDeps,
): void => {
  registry.register(logUserRegistered());
  registry.register(
    resetSafetyReminderOnCheckInFlagged({ resetSafetyReminderSeen: deps.resetSafetyReminderSeen }),
  );
};
