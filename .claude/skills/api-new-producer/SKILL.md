---
name: api-new-producer
description: BACKEND ONLY. Scaffold a domain event + producer call-site reminder in apps/api/src/features/<feature>/. Wraps /api-new-event and adds the publisher-side guidance for the per-consumer-offsets event bus (TRI-38).
---

# /api-new-producer

```
/api-new-producer <feature> <verb-past>
```

**Scope guard:** Backend API only. Domain events are a backend concept (transactional outbox, AsyncLocalStorage correlation, ConsumerRegistry). Mobile reacts to backend events through API responses, not its own event system.

**Why this exists alongside `/api-new-event`:** the event scaffold is identical, but the *producer story* changed in TRI-38. requestId / actorUserId are now picked up automatically from AsyncLocalStorage at publish time — devs no longer thread `meta` through use case signatures. This skill makes that pattern visible at scaffold time so it doesn't get re-discovered the hard way.

Examples:

- `/api-new-producer events event-created` → constant `EVENT_CREATED = 'events.eventCreated'`
- `/api-new-producer join-requests request-approved` → constant `REQUEST_APPROVED = 'joinRequests.requestApproved'`

## Validate

REFUSE if:

- `<feature>` doesn't exist at `apps/api/src/features/<feature>/`.
- `<verb-past>` is not past tense — events record what _happened_. Use `event-created` not `create-event` (that's a use case).
- File `apps/api/src/features/<feature>/domain/events/<verb-past>.event.ts` already exists.

## Scaffold

Same shape as `/api-new-event` — emit the canonical event factory file at:

`apps/api/src/features/<feature>/domain/events/<verb-past>.event.ts`

- `CONSTANT_NAME` = SCREAMING_SNAKE_CASE of `<verb-past>`.
- `TypeName` = PascalCase of `<verb-past>` + `Event`.
- `factoryName` = camelCase of `<verb-past>`.
- `eventTypeString` = `<featureCamel>.<verbPastCamel>`.

```ts
import type { DomainEvent } from '@/core/events/domain-event.js';

export const <CONSTANT_NAME> = '<eventTypeString>' as const;

export interface <TypeName>Payload {
  // TODO: id-like fields + timestamp; keep payloads small and serializable
  occurredAt: string;
}

export type <TypeName> = DomainEvent<<TypeName>Payload> & {
  type: typeof <CONSTANT_NAME>;
};

export const <factoryName> = (payload: <TypeName>Payload): <TypeName> => ({
  type: <CONSTANT_NAME>,
  aggregateType: '<TODO: AggregateName>',
  aggregateId: '<TODO: payload.<idField>>',
  payload,
  version: 1,
});
```

## Print after scaffolding

```
Event scaffolded at <path>

NEXT STEPS — producer side:

1. Fill in the Payload fields (small, JSON-serializable, immutable).
2. Set aggregateType + aggregateId in the factory.

3. In your aggregate's state-changing method, record the event:
       this.record(<factoryName>({ /* payload fields */ }));

4. In your use case, after the operation succeeds:
       await this.unitOfWork.run(async (ctx) => {
         await this.<repository>.save(aggregate, ctx);
         await this.events.publish(ctx, ...aggregate.pullEvents());
       });

   The publisher reads requestId + actorUserId from AsyncLocalStorage
   automatically — no need to thread `meta` through your use case.

   For non-HTTP callers (boot, future cron jobs, CLI scripts), wrap in:
       runAsSystem('<context-label>', async () => { ... });
   without it the audit trail records requestId=null and logs a WARN.

5. To consume this event from another feature, run:
       /api-new-consumer <consuming-feature> <verb-imperative>-on-<verb-past>
```

## Expected output (eyeball regression check)

For `/api-new-producer events event-created`, the file at `apps/api/src/features/events/domain/events/event-created.event.ts` should contain `EVENT_CREATED = 'events.eventCreated'`, `EventCreatedPayload`, `EventCreatedEvent`, and a `eventCreated(payload)` factory.
