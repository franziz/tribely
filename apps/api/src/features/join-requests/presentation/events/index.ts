import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';

/**
 * Register every consumer the `join-requests` feature owns. Empty for TRI-20 —
 * the feature emits but doesn't yet react to sibling events. Future consumers
 * (e.g. reacting to `events.eventCancelled` to auto-cancel pending requests)
 * register here.
 */
export const registerJoinRequestsConsumers = (_registry: ConsumerRegistry): void => {
  // intentionally empty — see file header
};
