import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';

/**
 * Register every consumer the `support` feature owns. Add Consumer objects
 * via `registry.register(...)` here. Other features that care about
 * support's events register their consumers from their own
 * presentation/events/index.ts — not here.
 */
export const registerSupportConsumers = (_registry: ConsumerRegistry): void => {
  // registry.register(somethingOnUserRegistered({ /* deps */ }));
};
