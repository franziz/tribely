/**
 * User-blocks domain-event subscribers.
 *
 * No consumers at launch — the `userBlocked` / `userUnblocked` events are
 * published for audit and future use (e.g., notification feature), but no
 * immediate cross-feature reaction is wired here. Join-request cascade is
 * handled synchronously inside `BlockUserUseCase` via `CascadePendingBlocksPort`.
 */
import type { ConsumerRegistry } from '@/core/events/index.js';

export const registerUserBlocksConsumers = (_registry: ConsumerRegistry): void => {
  // No consumers at launch.
};
