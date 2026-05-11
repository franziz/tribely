import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';

/**
 * Register every consumer the `events` feature owns. Called once at boot
 * from `buildContainer()`.
 *
 * No consumers in TRI-9 yet — the feature emits but does not yet react to
 * any sibling feature's events. Future consumers (e.g. reacting to
 * `joinRequests.joinRequestApproved` for capacity tracking, TRI-20) register
 * here. The function is wired into the container early so adding consumers
 * later requires no DI surgery.
 */
export const registerEventsConsumers = (_registry: ConsumerRegistry): void => {
  // intentionally empty — see file header
};
