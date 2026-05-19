import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';

/**
 * Register every consumer the `reviews` feature owns. Add Consumer objects
 * via `registry.register(...)` here. Other features that care about
 * reviews' events register their consumers from their own
 * presentation/events/index.ts — not here.
 */
export const registerReviewsConsumers = (registry: ConsumerRegistry): void => {
  // No consumers yet. Brief 3A (cascade-on-user-deletion) will add one.
  void registry;
};
