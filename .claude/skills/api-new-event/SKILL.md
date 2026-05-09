---
name: api-new-event
description: BACKEND ONLY. Scaffold a domain event in apps/api/src/features/<feature>/domain/events/<name>.event.ts following the <feature>.<verbPastTense> naming convention.
---

# /api-new-event

```
/api-new-event <feature> <verb-past>
```

**Scope guard:** Backend API only. Domain events are a backend concept (transactional outbox, EventBus, subscribers). Mobile reacts to backend events through API responses, not its own event system.

Examples:

- `/api-new-event events event-created` → constant `EVENT_CREATED = 'events.eventCreated'`
- `/api-new-event join-requests request-approved` → constant `REQUEST_APPROVED = 'joinRequests.requestApproved'`

## Validate

REFUSE if:

- `<feature>` doesn't exist.
- Name is not in past tense — events record what _happened_. Use `event-created` not `create-event` (that's a use case).
- Would overwrite an existing event file.

## Scaffold

Path: `apps/api/src/features/<feature>/domain/events/<verb-past>.event.ts`.

- `CONSTANT_NAME` = SCREAMING_SNAKE_CASE of `<verb-past>`.
- `TypeName` = PascalCase of `<verb-past>` + `Event`.
- `factoryName` = camelCase of `<verb-past>`.
- `eventTypeString` = `<featureCamel>.<verbPastCamel>` — e.g. `joinRequests.requestApproved`.

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

NEXT STEPS:
  1. Fill in the Payload fields (small, JSON-serializable, immutable).
  2. Set aggregateType + aggregateId in the factory.
  3. Have the aggregate record this event in the relevant state-changing method:
     this.record(<factoryName>({...}));
  4. (If any other feature subscribes) add a handler in that feature's
     presentation/events/index.ts:
       bus.subscribe<<TypeName>>(<CONSTANT_NAME>, async (event) => { ... });
```
