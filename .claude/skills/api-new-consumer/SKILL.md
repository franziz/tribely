---
name: api-new-consumer
description: BACKEND ONLY. Scaffold a Consumer that subscribes to a domain event in apps/api/src/features/<feature>/presentation/events/. Use when a feature needs to react to another feature's event under the per-consumer-offsets event bus (TRI-38).
---

# /api-new-consumer

```
/api-new-consumer <feature> <verb-imperative>-on-<source-event>
```

**Scope guard:** Backend API only. Consumer + ConsumerRegistry are backend concepts; mobile reacts to API responses, not events.

**Why a verb-on-event filename:** the consumer's filename describes what it _does_ in response to a fact. Mirrors the `Consumer.name` convention `<feature>.<camelVerbOnSourceEvent>`, which becomes the primary key in `consumer_offsets`. Stable name = stable offset across deploys.

Examples:

- `/api-new-consumer auth issue-email-verification-on-user-registered`
  → file: `auth/presentation/events/issue-email-verification-on-user-registered.consumer.ts`
  → consumer name: `auth.issueEmailVerificationOnUserRegistered`
- `/api-new-consumer notifications notify-host-on-request-approved`
  → consumer name: `notifications.notifyHostOnRequestApproved`

## Validate

REFUSE if:

- `<feature>` doesn't exist at `apps/api/src/features/<feature>/`.
- `<verb-imperative>` looks past tense — consumers _do_, events _are_. Use `notify-host` not `host-notified`.
- `<source-event>` does NOT exist as `apps/api/src/features/*/domain/events/<source-event>.event.ts` (grep across all features). Suggest the closest matches if not found.
- File `apps/api/src/features/<feature>/presentation/events/<verb-imperative>-on-<source-event>.consumer.ts` already exists.

## Scaffold

Path: `apps/api/src/features/<feature>/presentation/events/<verb-imperative>-on-<source-event>.consumer.ts`.

- `<sourceFeature>` = the feature folder where `<source-event>.event.ts` lives.
- `<SOURCE_CONSTANT>` = the event's exported SCREAMING_SNAKE constant (e.g. `USER_REGISTERED`).
- `<SourceEvent>` = the event's exported type (e.g. `UserRegisteredEvent`).
- `<CamelVerbOnSourceEvent>` = PascalCase of `<verb-imperative>-on-<source-event>` (e.g. `IssueEmailVerificationOnUserRegistered`).
- `<camelVerbOnSourceEvent>` = camelCase of same.

```ts
import type { Consumer } from '@/core/events/consumer.port.js';
import {
  <SOURCE_CONSTANT>,
  type <SourceEvent>,
} from '@/features/<sourceFeature>/domain/events/<source-event>.event.js';

export interface <CamelVerbOnSourceEvent>Deps {
  // TODO: inject the use case(s) this consumer calls.
  // Lightweight log/metric consumers can leave this empty.
}

/**
 * <One-line summary: what this consumer does when the event fires.>
 *
 * Idempotency: this MUST be idempotent. The dispatcher delivers each event
 * at-least-once per consumer; transient failures retry the SAME event
 * with the SAME ConsumerContext. Lean on use-case-level guards
 * (already-applied checks, replaced-token invariants) to absorb retries.
 */
export const <camelVerbOnSourceEvent> = (
  deps: <CamelVerbOnSourceEvent>Deps,
): Consumer<<SourceEvent>> => ({
  name: '<feature>.<camelVerbOnSourceEvent>',
  topic: <SOURCE_CONSTANT>,
  // maxAttempts: 5,  // override here if 5 isn't right for this consumer
  async handle(event, ctx) {
    // TODO: implement. Use deps.<useCase>.execute(...) to delegate.
    // ctx.requestId / ctx.actorUserId carry the original HTTP correlation —
    // any downstream events you publish inherit the same chain via ALS.
    throw new Error('not implemented');
  },
});
```

## Print after scaffolding

```
Consumer scaffolded at <path>

NEXT STEPS:

1. Implement handle(). The handler MUST be idempotent — at-least-once delivery.

2. If you need a new use case:
       /api-new-usecase <feature> <verb-imperative>
   If you're calling an existing use case, just inject it via Deps.

3. Register the consumer in apps/api/src/features/<feature>/presentation/events/index.ts:
       registry.register(<camelVerbOnSourceEvent>({ /* deps */ }));
   And ensure registerXConsumers(...) is called from buildContainer().

4. Behavioural guarantees (TRI-38):
   - Independent progress per consumer — your failure does not block sibling
     consumers of the same topic.
   - Head-of-line block on failure — your consumer retries the SAME event
     until success or maxAttempts (default 5).
   - After maxAttempts, consumer_offsets.blockedAt is set. Manual unblock:
       UPDATE consumer_offsets SET blockedAt = NULL, attempts = 0 WHERE consumerName = '...';
   - Late-joining consumers seed at committedSeq=0 (process all backfill).
     To start at "latest" instead, seed manually in a migration.

5. Audit: every dispatch outcome (dispatched / failed / blocked) writes a
   row to event_audit_logs with the original requestId. Query with:
       SELECT * FROM event_audit_logs WHERE consumerName = '<feature>.<camelVerbOnSourceEvent>' ORDER BY recordedAt DESC;
```

## Expected output (eyeball regression check)

For `/api-new-consumer auth issue-email-verification-on-user-registered`, the file at `apps/api/src/features/auth/presentation/events/issue-email-verification-on-user-registered.consumer.ts` should:
- Import `Consumer` from `@/core/events/consumer.port.js`.
- Import `USER_REGISTERED` + `UserRegisteredEvent` from `@/features/users/domain/events/user-registered.event.js`.
- Export `issueEmailVerificationOnUserRegistered(deps)` returning a `Consumer<UserRegisteredEvent>` with `name: 'auth.issueEmailVerificationOnUserRegistered'`.
