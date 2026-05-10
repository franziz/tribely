# Events core

Per-consumer-offsets event bus, Postgres-backed. Kafka-shaped — the migration to real Kafka/NATS later is mechanical, not a rewrite.

## Mental model

```
   producer use case ──publish(ctx, ...events)──▶ outbox_events  (append-only log; seq BIGSERIAL)
                                                       │
                                                       ▼
                                                ConsumerRegistry  (one Consumer per "consumer group")
                                                       │
                                                       ▼
                                                OutboxDispatcher  (per-tick, per-consumer iteration)
                                                       │
                                                       ▼
                                                consumer.handle(event, ctx)
                                                       │
                                                       ▼
                                                consumer_offsets  (per-consumer cursor, attempts, blockedAt)
```

## Kafka mapping

| Kafka concept             | This impl                                                  |
| ------------------------- | ---------------------------------------------------------- |
| Topic                     | `event.type` string (e.g. `users.userRegistered`)          |
| Partition                 | `aggregateId` (logical; one in-process partition for MVP)  |
| Offset                    | `outbox_events.seq BIGSERIAL`                              |
| Consumer group            | `Consumer.name` (e.g. `auth.issueEmailVerificationOnUserRegistered`) |
| `__consumer_offsets`      | `consumer_offsets` table                                   |
| Manual offset commit      | `UPDATE consumer_offsets SET committedSeq = X` post-success |
| `auto.offset.reset`       | New consumer rows seed `committedSeq = 0` (= "earliest")   |
| Headers (correlation id)  | `outbox_events.requestId` + AsyncLocalStorage at dispatch  |

## Guarantees

- **At-least-once per consumer.** Failures keep `inFlightSeq` set; the same event retries on the next tick.
- **In-order per topic per consumer.** Head-of-line block: a failing event prevents that consumer from advancing past it. Other consumers on the same topic are unaffected.
- **Independent progress per consumer.** Two consumers of the same topic can be at different `committedSeq`. One blocked consumer never blocks the other.
- **Bounded retry.** After `Consumer.maxAttempts` (default 5) consecutive failures on the same event, the consumer's row gets `blockedAt = NOW()` and the dispatcher skips it. Manual unblock:
  ```sql
  UPDATE consumer_offsets SET blockedAt = NULL, attempts = 0 WHERE consumerName = '...';
  ```
- **Atomic publish-side audit.** The `event_audit_logs` "published" row commits in the same transaction as the `outbox_events` row. Partial-publish corruption is impossible.
- **At-least-once correlation.** `requestId` + `actorUserId` are persisted on the outbox row at publish time; the dispatcher re-establishes the AsyncLocalStorage frame at dispatch time, so any downstream events the consumer publishes inherit the same correlation chain.

## Settle delay (the bigserial in-flight tx race)

`OutboxDispatcher.settleDelaySeconds` (default 5) makes the dispatcher refuse to read events with `occurredAt > NOW() - settleDelay`. This defends against the BIGSERIAL race: a transaction with `seq=99` can commit *after* a transaction with `seq=100` finishes, so dispatching `seq=100` before `seq=99` is visible would skip `seq=99` forever for any consumer that advances past it.

Trade-off: 5s of added latency from publish to dispatch. Goes away when we move to Kafka (partition log ordering handles this natively). For MVP traffic this latency is invisible.

## Idempotency contract

Every `Consumer.handle()` MUST be safe to call repeatedly with the same event. The dispatcher delivers each event at-least-once per consumer; transient failures retry the same event with the same `ConsumerContext`. Patterns:

- **Aggregate-level guards.** `User.verifyEmail(now)` no-ops when already verified. `EmailVerificationToken.invalidate(reason, now)` is idempotent.
- **Single-open invariants.** `IssueEmailVerificationUseCase` invalidates any pre-existing open token before issuing a new one — re-delivery sends one fresh code, not five.
- **Lookup-then-act.** Read the current state before deciding; commit only if the state still warrants the action.

If a consumer is genuinely non-idempotent (e.g. a third-party API call without a deduplication key), wrap it in a use case that records "already done" markers in the database keyed on `eventSeq`.

## Migrating to Kafka later

When MVP scale outgrows in-process dispatch (multiple replicas, or true asynchronous workers), the swap is mostly mechanical:

1. **Replace `OutboxDispatcher` with a Kafka producer that drains the outbox.** Same loop, but instead of calling `consumer.handle()`, it publishes the event to a Kafka topic. Use Debezium or a similar CDC connector if you prefer to drop the polling loop entirely.
2. **Replace each `Consumer` with a Kafka consumer in its own consumer group.** The `Consumer.name` becomes the `group.id`. The handler signature stays the same.
3. **Move `consumer_offsets` semantics to Kafka's own offset store.** The table can stay around as a forensic record of "what we committed" for audit reasons, but the source of truth is Kafka.
4. **`AsyncLocalStorage` correlation moves to Kafka headers.** Producer attaches `request-id` + `actor-user-id` as message headers; consumer reads them and opens the same ALS frame.
5. **The `event_audit_logs` table stays — same semantics, different producer.**

What does NOT need to change:
- Domain event factories (`<verbPast>.event.ts`).
- Aggregate `record(event)` calls.
- Use case publish call sites (`this.events.publish(ctx, ...aggregate.pullEvents())`).
- Consumer handler bodies.
- The `/api-new-producer` and `/api-new-consumer` skills.

The domain layer never changes. That's the whole point of the abstraction.

## Where to look

| File                                               | Role                                            |
| -------------------------------------------------- | ----------------------------------------------- |
| `consumer.port.ts`                                 | `Consumer<TEvent>` + `ConsumerContext` types    |
| `consumer-registry.ts`                             | Holds Consumer objects; rejects duplicate names |
| `outbox-event-publisher.ts`                        | Writes outbox + audit row inside same tx        |
| `outbox-dispatcher.ts`                             | Per-consumer iteration loop                     |
| `domain-event.ts`                                  | `DomainEvent` interface                         |
| `event-publisher.port.ts`                          | `EventPublisher` outbound port                  |
| `__test__/`                                        | registry + dispatcher tests                     |

For producer/consumer scaffolding conventions, see `.claude/skills/api-new-producer/` and `.claude/skills/api-new-consumer/`.
