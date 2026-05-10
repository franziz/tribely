import type { DomainEvent } from './domain-event.js';

/**
 * One Consumer = one Kafka consumer group. The dispatcher iterates every
 * registered consumer per tick, advancing each one's offset independently.
 *
 * `name` MUST be globally unique and stable across deploys — it's the
 * primary key in `consumer_offsets`. Convention: `<feature>.<verbInPresent>On<SourceEvent>`,
 * camelCase. Example: `auth.issueEmailVerificationOnUserRegistered`.
 *
 * `topic` is the event type string (e.g. `users.userRegistered`) — same
 * value as `event.type`. Stored denormalized on `consumer_offsets.topic`
 * so we can index/filter by topic at query time.
 *
 * `maxAttempts` (default 5): after this many consecutive failures on the
 * same event, the dispatcher sets `blockedAt` and stops retrying. Manual
 * intervention required to clear (UPDATE consumer_offsets SET blockedAt =
 * NULL, attempts = 0).
 *
 * `handle` MUST be idempotent. The dispatcher delivers each event at-least-
 * once per consumer; a transient handler failure is retried with the same
 * event on the next tick. Use case-level idempotency (e.g. user-already-
 * verified no-op, replaced-token invariants) is the right place to absorb
 * this — see /api-new-consumer skill for the convention.
 */
export interface Consumer<TEvent extends DomainEvent = DomainEvent> {
  readonly name: string;
  readonly topic: TEvent['type'];
  readonly maxAttempts?: number;
  handle(event: TEvent, ctx: ConsumerContext): Promise<void>;
}

/**
 * Context the dispatcher hands to the handler. `requestId` + `actorUserId`
 * are the values persisted on the outbox row at publish time; the
 * dispatcher re-establishes them in AsyncLocalStorage before calling
 * `handle`, so any downstream events the consumer publishes inherit the
 * same correlation chain (Kafka headers semantics).
 */
export interface ConsumerContext {
  readonly requestId: string | null;
  readonly actorUserId: string | null;
  /** 1-based attempt counter for *this* event/consumer pair. */
  readonly attempt: number;
}
