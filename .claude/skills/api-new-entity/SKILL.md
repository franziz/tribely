---
name: api-new-entity
description: BACKEND ONLY. Scaffold an aggregate root entity in apps/api/src/features/<feature>/domain/entities/<name>.ts, extending AggregateRoot with create/rehydrate factories and a paired Prisma mapper. Do NOT use for Flutter — Flutter entities don't extend AggregateRoot.
---

# /api-new-entity

```
/api-new-entity <feature> <SingularPascalName>
```

**Scope guard:** Backend API only. Backend entities are aggregate roots that record domain events and have rich behavior. Flutter entities are simpler value-equality classes (Equatable).

Examples:
- `/api-new-entity events Event` → `events/domain/entities/event.ts` + `events/infrastructure/persistence/event.mapper.ts`
- `/api-new-entity users User` → `users/domain/entities/user.ts` + mapper

## Validate

REFUSE and explain if:
- `<feature>` doesn't exist under `apps/api/src/features/`.
- Name is plural (`Events` instead of `Event`) — entities are singular.
- Name is camelCase or kebab-case — must be PascalCase singular noun.
- File would overwrite an existing one.

## Scaffold the entity

Path: `apps/api/src/features/<feature>/domain/entities/<kebab-name>.ts`.

```ts
import { AggregateRoot } from '@/core/domain/aggregate-root.js';

/**
 * <Name> aggregate root.
 *
 * <one-line description of the aggregate's responsibility in the bounded context>
 *
 * Construction paths:
 *   - `<Name>.create(...)` — new instance. Records `<feature>.<name>Created` event.
 *   - `<Name>.rehydrate(...)` — reconstituting from persistence. No events.
 */
export class <Name> extends AggregateRoot {
  private constructor(
    public readonly id: string,
    // TODO: private fields — VOs preferred over primitives
    public readonly createdAt: Date,
    private _updatedAt: Date,
  ) {
    super();
  }

  static create(input: {
    id: string;
    // TODO: input fields
    now: Date;
  }): <Name> {
    const instance = new <Name>(input.id, /* TODO */ input.now, input.now);
    // TODO: instance.record(<created event factory>(...));
    return instance;
  }

  static rehydrate(state: {
    id: string;
    // TODO: state fields
    createdAt: Date;
    updatedAt: Date;
  }): <Name> {
    return new <Name>(state.id, /* TODO */ state.createdAt, state.updatedAt);
  }

  get updatedAt(): Date {
    return this._updatedAt;
  }

  // TODO: methods that change state should also record events.
}
```

## Scaffold the mapper

Path: `apps/api/src/features/<feature>/infrastructure/persistence/<kebab-name>.mapper.ts`.

```ts
import type { <Name> as <Name>Row } from '@prisma/client';
import { <Name> } from '../../domain/entities/<kebab-name>.js';

export const to<Name> = (row: <Name>Row): <Name> =>
  <Name>.rehydrate({
    id: row.id,
    // TODO: map row → state, wrapping primitives in VOs
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  });

export const toRow = (entity: <Name>): <Name>Row => ({
  id: entity.id,
  // TODO: map entity → row, unwrapping VOs to primitives
  createdAt: entity.createdAt,
  updatedAt: entity.updatedAt,
});
```

## Print after scaffolding

```
Entity scaffolded:
  - apps/api/src/features/<feature>/domain/entities/<kebab>.ts
  - apps/api/src/features/<feature>/infrastructure/persistence/<kebab>.mapper.ts

NEXT STEPS:
  1. Add the Prisma model and migrate via /api-create-migration.
  2. Define value objects for non-primitive fields:
     /api-new-value-object <feature> <Name>
  3. Define the "created" event:
     /api-new-event <feature> <name>-created
  4. Wire the event into <Name>.create() — call this.record(<eventFactory>(...)).
  5. Build the repository: domain/repositories/<kebab>.repository.ts (interface)
     and infrastructure/persistence/<kebab>.prisma-repository.ts (impl).
  6. Register dependencies in core/di/container.ts.
```
