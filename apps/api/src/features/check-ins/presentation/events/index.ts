import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';

/**
 * Register every consumer the `check-ins` feature owns. Add Consumer objects
 * via `registry.register(...)` here. Other features that care about
 * check-ins' events register their consumers from their own
 * presentation/events/index.ts — not here.
 */
export const registerCheckInsConsumers = (registry: ConsumerRegistry): void => {
  // registry.register(somethingOnUserRegistered({ /* deps */ }));
};
