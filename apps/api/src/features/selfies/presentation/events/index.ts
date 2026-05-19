import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';

/**
 * Register every consumer the `selfies` feature owns. Add Consumer objects
 * via `registry.register(...)` here. Other features that care about
 * selfies' events register their consumers from their own
 * presentation/events/index.ts — not here.
 */
export const registerSelfiesConsumers = (_registry: ConsumerRegistry): void => {
  // registry.register(somethingOnSelfieDeleted({ /* deps */ }));
};
