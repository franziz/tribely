# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo shape

Monorepo with a Flutter mobile app and a Hono/TypeScript backend. They co-evolve, so an API change usually requires a matching client change in the same PR.

```
apps/api      — Hono + Prisma + Postgres backend
apps/mobile   — Flutter app (Riverpod + go_router + Dio + fpdart)
```

There is **no** `packages/shared`. A TS-only shared package can't be consumed by Flutter, so cross-language type sharing is deferred to OpenAPI codegen (Zod → OpenAPI spec → generated Dart client into `apps/mobile/lib/src/generated/`) when it's actually needed. Don't reintroduce `packages/shared` unless a second TS consumer exists (admin web, worker, etc.).

## Commands

### Backend (`apps/api`, run from repo root)

```bash
pnpm install                    # install JS deps for the workspace
pnpm api:dev                    # tsx watch on src/index.ts
pnpm api:build                  # tsc → dist/
pnpm api:start                  # node dist/index.js (after build)
pnpm api:db:generate            # prisma generate
pnpm api:db:migrate             # prisma migrate dev (creates migration + applies)
pnpm --filter @tribely/api db:migrate:deploy   # production migrations
pnpm --filter @tribely/api db:studio           # prisma studio
pnpm --filter @tribely/api typecheck
pnpm --filter @tribely/api test                # vitest run
pnpm --filter @tribely/api test:watch
```

Single test: `pnpm --filter @tribely/api exec vitest run path/to/foo.test.ts` (or `-t "test name"` for grep).

`apps/api/.env` must exist before `pnpm api:dev` works. Copy `.env.example` and set `DATABASE_URL` and a `JWT_SECRET` of ≥32 chars — env is parsed by Zod at boot and will throw on invalid values (`apps/api/src/core/config/env.ts`).

### Mobile (`apps/mobile`)

```bash
melos bootstrap                                          # pub get across Flutter packages
cd apps/mobile && flutter create --org com.tribely --platforms=ios,android .   # one-time, fills in iOS/Android folders (non-destructive)
flutter run --dart-define=API_BASE_URL=http://localhost:3000
melos run analyze
melos run test
melos run build_runner          # one-shot codegen
melos run build_runner:watch
```

Single Flutter test: `cd apps/mobile && flutter test test/path/to/foo_test.dart`.

Android emulator → use `http://10.0.2.2:3000` instead of `localhost` for the API base URL.

## Architecture (Clean Architecture / DDD)

Both apps use the **same three-layer split** per feature: `domain/` → `data/` → `presentation/`. Cross-feature plumbing lives in `core/`. Match the existing `auth/` feature exactly when adding a new feature — it's the canonical template.

### The non-obvious conventions

These differ from typical Flutter Clean Architecture tutorials and were chosen deliberately. Don't "fix" them:

- **Datasource interfaces live in `data/datasources/`, colocated with their impl. NOT in `domain/`.** The Repository is the only data abstraction the domain knows about. Datasources are an internal detail of the repository (e.g., the repo coordinates `RemoteDataSource` + `LocalDataSource` for offline-first, cache-then-network, etc.). If domain knew about datasources, the repository pattern would be leaking its implementation.
- **Domain has `entities/`, NOT `models/`.** Models (DTOs with JSON serialization) live in `data/models/` and own the `toEntity()` mapper.
- **`domain/services/` is reserved for genuine external dependencies the *business* cares about** — mailer, payment gateway, push, JWT token issuance. Not data fetching plumbing.
- **One use case per user intent.** `SignInUseCase`, not `AuthUseCase.signIn(...)`. Use cases are the only thing controllers/StateNotifiers should call.
- **Mobile repositories return `Either<Failure, T>` (fpdart); API repositories throw `AppError`.** This is asymmetric on purpose:
  - API: throwing flows into Hono's `onError` middleware (`apps/api/src/core/middleware/error-handler.ts`) which produces a uniform `{ error: { code, message, details? } }` HTTP shape. Errors are constructed via the `AppError.validation/unauthorized/notFound/conflict/...` factories — don't throw raw `Error`.
  - Mobile: UI needs to render error states declaratively, so failures are part of the type signature. The repository impl catches `DioException` and maps the inner `ServerException`/`NetworkException` to a typed `Failure` (see `auth_repository_impl.dart` `_runAuth` for the pattern to copy).
- **Domain layer never imports from `data/` or `presentation/`.** Domain has no Prisma, no Dio, no Flutter, no Hono imports.

### DI

- **API**: hand-rolled DI in `apps/api/src/core/di/container.ts`. `buildContainer()` constructs all singletons in dependency order. Wire new use cases here, then expose them through controllers.
- **Mobile**: `get_it` in `apps/mobile/lib/src/core/di/service_locator.dart` for the dependency graph; Riverpod providers in each feature wrap the use cases for UI consumption (`auth_providers.dart` is the template). The split: `get_it` for "what does the app depend on" (set up once at boot), Riverpod for "what does this widget tree depend on" (with rebuild semantics).

### Routes & state

- API: routes are built per-feature (`buildAuthRoutes(container)`) and mounted in `apps/api/src/core/../app.ts`. Validation uses `zValidator` from `@hono/zod-validator`; the schema files in `presentation/schemas/` are the source of truth for both validation and types.
- Mobile: `go_router` in `apps/mobile/lib/src/core/router/app_router.dart`. Auth state is a sealed class hierarchy (`AuthState` → `AuthInitial`/`AuthLoading`/`AuthAuthenticated`/`AuthUnauthenticated`/`AuthError`); pages `ref.listen` for transitions and `ref.watch` for render state.

## Adding a new feature

1. **Backend** — duplicate `apps/api/src/features/auth/`, rename, edit. Register use cases in `core/di/container.ts`. Mount routes in `core/../app.ts`.
2. **Mobile** — duplicate `apps/mobile/lib/src/features/auth/`, rename. Register datasource/repository/use cases in `core/di/service_locator.dart`. Add routes in `core/router/app_router.dart`. Build a Riverpod provider file matching `auth_providers.dart`.

Don't introduce a new layering shape per feature — consistency is the point.

## Collaboration style

The repo owner explicitly invites pushback on architectural choices. When something is asked for that conflicts with the conventions above, name the trade-off and propose the alternative rather than silently complying or silently refusing.
