---
name: api-new-feature
description: BACKEND ONLY. Scaffold a new bounded-context feature in apps/api/src/features/<name>/ following the 4-layer Clean Arch + DDD + Hexagonal structure (domain/application/infrastructure/presentation). Do NOT use for Flutter — use /mobile-new-feature instead.
---

# /api-new-feature

```
/api-new-feature <plural-kebab-name>
```

**Scope guard:** Backend API only (`apps/api/`). If asked to scaffold something in `apps/mobile/`, refuse and direct to `/mobile-new-feature`. The two stacks have deliberately different layering (4-layer for API, 3-layer for Flutter — see CLAUDE.md).

Creates `apps/api/src/features/<name>/` matching the canonical layout (`auth` and `users` are the reference templates).

## Validate the input

REFUSE and explain why if any of these are true:

- Name is singular (`event` instead of `events`).
- Name suggests infrastructure (`logging`, `cache`, `queue`, `mailer`) — those belong in `core/`.
- Name is too vague (`common`, `shared`, `utils`, `data`).
- A folder with that name already exists under `apps/api/src/features/`.
- The bounded-context checklist in CLAUDE.md ("What is a feature") mostly fails.

If you're unsure whether the concept is a feature, ask the user the four checklist questions before scaffolding.

## Walk through the bounded-context checklist

Before creating files, confirm with the user:
1. Does this own at least one aggregate root + persistence nobody else writes to?
2. Does it have its own verbs the business cares about?
3. Could it be extracted to its own service later without rewriting it?
4. Does the domain expert recognize its name as a thing in the business?

If they answer "no" to most, recommend folding the concept into an existing feature or `core/`.

## Scaffold the folder structure

Compute `<PascalName>` (kebab-case → PascalCase: `join-requests` → `JoinRequests`).

Create:

```
apps/api/src/features/<name>/
  domain/
    entities/.gitkeep
    value-objects/.gitkeep
    events/.gitkeep
    repositories/.gitkeep
    services/.gitkeep
    ports/.gitkeep
  application/
    usecases/.gitkeep
  infrastructure/
    persistence/.gitkeep
    adapters/.gitkeep
  presentation/
    http/
      controllers/.gitkeep
      routes/.gitkeep
      schemas/.gitkeep
    events/index.ts
```

`presentation/events/index.ts` body:

```ts
import type { EventBus } from '@/core/events/event-bus.port.js';

/**
 * Subscribers for events the `<name>` feature reacts to.
 * Other features that care about <name>'s events register their handlers
 * from their own presentation/events/index.ts — not here.
 */
export const register<PascalName>Subscribers = (bus: EventBus): void => {
  // Subscribe handlers here when this feature needs to react to events.
};
```

## After scaffolding — print this checklist

```
Feature scaffolded at apps/api/src/features/<name>/

NEXT STEPS (manual — these require judgement):

  1. Add Prisma model(s) for your aggregate(s) — use /api-create-migration
     to author the migration with a meaningful name.

  2. Define your aggregate(s):
     /api-new-entity <name> <SingularName>

  3. Add value objects with validation:
     /api-new-value-object <name> <Name>

  4. Define domain events for state changes other features care about:
     /api-new-event <name> <verb-past>

  5. Define outbound ports for external dependencies:
     - Create files manually in domain/ports/<name>.port.ts
     - Then implement adapters in infrastructure/adapters/

  6. Repository: interface in domain/repositories/<aggregate>.repository.ts;
     impl in infrastructure/persistence/<aggregate>.prisma-repository.ts;
     mapper in infrastructure/persistence/<aggregate>.mapper.ts.
     Methods MUST accept an optional ctx?: TxContext.

  7. Write your first use case:
     /api-new-usecase <name> <verb-noun>

  8. HTTP layer (if the feature has endpoints):
     - presentation/http/schemas/<name>.schemas.ts (Zod)
     - presentation/http/controllers/<name>.controller.ts
     - presentation/http/routes/<name>.routes.ts (export buildXRoutes)

  9. Wire dependencies in apps/api/src/core/di/container.ts.
 10. Mount routes in apps/api/src/app.ts.
 11. Call register<PascalName>Subscribers(bus) at the end of buildContainer().
```

DO NOT auto-edit `container.ts`, `app.ts`, or the Prisma schema — those require judgement about exact placement.
