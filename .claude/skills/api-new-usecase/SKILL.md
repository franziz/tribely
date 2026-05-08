---
name: api-new-usecase
description: BACKEND ONLY. Scaffold a use case in apps/api/src/features/<feature>/application/usecases/<verb>-<noun>.usecase.ts. Do NOT use for Flutter — Flutter use cases live in domain/usecases/ with a simpler shape; use /mobile-new-usecase instead.
---

# /api-new-usecase

```
/api-new-usecase <feature> <verb-noun>
```

**Scope guard:** Backend API only. The use case shape here orchestrates UnitOfWork + EventPublisher + repositories. Flutter use cases are simpler wrappers and live in `domain/usecases/`; use `/mobile-new-usecase`.

Examples:
- `/api-new-usecase events create-event` → `events/application/usecases/create-event.usecase.ts` → class `CreateEventUseCase`
- `/api-new-usecase users update-profile` → class `UpdateProfileUseCase`

## Validate

REFUSE and explain if:
- `<feature>` doesn't exist under `apps/api/src/features/`.
- `<verb-noun>` is not in the form `<verb>-<noun>` (`/api-new-usecase events list-events` not `/api-new-usecase events events`).
- Verb is past tense — use cases describe an *intent*, present tense (`create-event`, not `event-created`; past tense is for events).
- File would overwrite an existing one.

## Scaffold

Class name: PascalCase of `<verb-noun>` + `UseCase`. Path: `apps/api/src/features/<feature>/application/usecases/<verb-noun>.usecase.ts`.

Generate:

```ts
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
// import the repositories and ports this use case needs

export interface <PascalName>Input {
  // TODO: typed input — primitives or VOs
}

export interface <PascalName>Result {
  // TODO: typed output — entities or read models
}

/**
 * <one-line description of the user intent>
 */
export class <PascalName>UseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    // TODO: inject repositories + ports needed
    private readonly events: EventPublisher,
  ) {}

  async execute(input: <PascalName>Input): Promise<<PascalName>Result> {
    // 1. Validate input — turn primitives into VOs (will throw on invalid).
    // 2. Load aggregates from repositories.
    // 3. Invoke aggregate methods to produce state changes (which record events).
    // 4. Persist + publish events atomically:
    //
    //    await this.unitOfWork.run(async (ctx) => {
    //      await this.someRepo.save(aggregate, ctx);
    //      await this.events.publish(ctx, ...aggregate.pullEvents());
    //    });
    //
    // 5. Return result.

    throw AppError.internal('not implemented');
  }
}
```

## Print after scaffolding

```
Use case scaffolded at <path>

NEXT STEPS:
  1. Define the Input and Result types.
  2. Add repository / port dependencies to the constructor.
  3. Wire the use case in apps/api/src/core/di/container.ts.
  4. If invoked over HTTP, add a controller method + route.
```

DO NOT auto-edit `container.ts` — that needs to be wired manually.
