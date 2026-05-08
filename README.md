# Tribely

Monorepo containing the Tribely mobile app (Flutter) and API (Hono + TypeScript).

## Why a monorepo

The mobile and backend co-evolve: an API change usually requires a matching client change. Keeping both in one repo means:

- AI assistants (and humans) see the contract and the consumer in one context — fewer drift bugs across renamed fields, mismatched enums, stale DTOs.
- Atomic commits that span both sides.
- One repo to clone, one place to track issues.

Cross-language type sharing (TS ↔ Dart) isn't possible via direct import. When we need it, the plan is **OpenAPI codegen**: define schemas once on the API side (Zod), generate an OpenAPI spec, generate a typed Dart client into `apps/mobile/lib/src/generated/`. Until that's set up, types are duplicated between sides on purpose — kept in sync manually because there's only one feature.

## Layout

```
.
├── apps/
│   ├── api/          # Hono + Prisma + Postgres backend
│   └── mobile/       # Flutter app (Riverpod + go_router + Dio)
├── pnpm-workspace.yaml
├── melos.yaml
└── tsconfig.base.json
```

## Architecture (Clean Architecture / DDD)

Both apps follow the same layering. **Repository is the only data abstraction the domain knows about.** Datasources are an internal detail of the data layer.

### API (`apps/api/src/features/<name>/`)

```
domain/
  entities/            Pure business types (no I/O)
  repositories/        Interfaces — what domain can fetch/save
  services/            External-dependency interfaces (mailer, payment, push)
  usecases/            One class per user intent — the only thing controllers call
data/
  models/              DTOs / Prisma row mappers (toEntity)
  datasources/         Interface + Prisma impl colocated
  repositories/        Concrete impls of domain repositories
  services/            Concrete impls of domain services (jwt, sendgrid, etc.)
presentation/
  routes/              Hono route registration
  controllers/         Thin glue between request → use case → response
  schemas/             Zod schemas (validation + types)
```

Cross-feature plumbing lives in `apps/api/src/core/`: env config, Prisma client, error types, Hono middleware, DI container.

### Mobile (`apps/mobile/lib/src/features/<name>/`)

```
domain/
  entities/            Pure Dart classes
  repositories/        Abstract interfaces returning Either<Failure, T>
  usecases/            Implements UseCase<T, Params>
data/
  models/              fromJson / toEntity DTOs
  datasources/         AuthRemoteDatasource + Impl colocated
  repositories/        Concrete impls catching DioException → Failure
presentation/
  pages/               ConsumerWidget screens
  widgets/             Feature-scoped widgets
  providers/           Riverpod providers (use case + controller wiring)
  controllers/         StateNotifier — owns AuthState transitions
  state/               Sealed state classes
```

Cross-feature plumbing lives in `apps/mobile/lib/src/core/`: config, DI (`get_it`), networking (`dio`), routing (`go_router`), error types, theme, secure storage.

### Why repositories return `Either<Failure, T>` on mobile but throw on API

- API: throwing `AppError` is fine because Hono's `onError` middleware converts to HTTP responses uniformly.
- Mobile: UI needs to render error states declaratively. `Either` makes failures part of the type, eliminating uncaught-exception UI bugs.

## Setup

### Prereqs

- Node ≥ 20.18, pnpm ≥ 9
- Flutter ≥ 3.24, Dart ≥ 3.5
- Postgres 15+ (or Docker)
- Melos (Flutter task runner): `dart pub global activate melos`

### First run

```bash
# Install JS deps
pnpm install

# Bootstrap Flutter packages
melos bootstrap

# Set up DB
cp apps/api/.env.example apps/api/.env
# edit DATABASE_URL + JWT_SECRET
pnpm api:db:migrate

# Add Flutter platform code (run once)
cd apps/mobile && flutter create --org com.tribely --platforms=ios,android .
```

### Day-to-day

```bash
# Run API
pnpm api:dev

# Run mobile (with API base URL override)
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://localhost:3000

# Codegen (freezed/json_serializable)
melos run build_runner
```

## Adding a new feature

1. **Backend** — copy the `auth` feature folder under `apps/api/src/features/`, rename, edit. Wire it into `core/di/container.ts` and `app.ts`.
2. **Mobile** — copy the `auth` feature folder under `apps/mobile/lib/src/features/`, rename. Register dependencies in `core/di/service_locator.dart` and add routes in `core/router/app_router.dart`.
3. **Shared types across stack** — duplicate the type on both sides for now. When duplication starts to hurt, add OpenAPI codegen (Zod → OpenAPI → Dart client) rather than reaching for a shared TS package — Flutter can't import TS directly.

## Conventions

- One use case per user intent (`SignInUseCase`, not `AuthUseCase.signIn(...)`).
- Domain knows about repositories and (occasionally) domain services. Domain never imports anything from `data/`.
- Datasource interfaces live in `data/datasources/` next to their implementation, not in `domain/`. The repository is the abstraction the domain depends on.
- Models (`data/models/`) own JSON serialization and the `toEntity()` mapper.
