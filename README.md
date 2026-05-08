# Tribely

Monorepo containing the Tribely mobile app (Flutter) and API (Hono + TypeScript).

## What Tribely is

Tribely is a mobile app where solo travelers create events (drinks, hike, museum, dinner) and others request to join. Launching in **Singapore first**.

## Why a monorepo

The mobile and backend co-evolve: an API change usually requires a matching client change. Keeping both in one repo means:

- AI assistants (and humans) see the contract and the consumer in one context — fewer drift bugs across renamed fields, mismatched enums, stale DTOs.
- Atomic commits that span both sides.
- One repo to clone, one place to track issues.

Cross-language type sharing (TS ↔ Dart) isn't possible via direct import. When we need it, the plan is **OpenAPI codegen**: define schemas once on the API side (Zod), generate an OpenAPI spec, generate a typed Dart client into `apps/mobile/lib/src/generated/`. Until then, types are duplicated and kept in sync manually.

## Layout

```
.
├── apps/
│   ├── api/          # Hono + Prisma + Postgres backend (4-layer Clean Arch)
│   └── mobile/       # Flutter app (3-layer Clean Arch, Riverpod + go_router + Dio)
├── .claude/skills/   # Project-scoped scaffolding + review skills (api-*, mobile-*)
├── package.json      # npm workspaces — only TS packages
├── melos.yaml        # Melos — Flutter packages
└── tsconfig.base.json
```

## Setup

### Prereqs

- Node ≥ 20.18, npm ≥ 10
- Flutter ≥ 3.24, Dart ≥ 3.5
- Postgres 15+ (or Docker)
- Melos (Flutter task runner): `dart pub global activate melos`

### First run

```bash
# Install JS deps
npm install

# Bootstrap Flutter packages
melos bootstrap

# Set up DB
cp apps/api/.env.example apps/api/.env
# edit DATABASE_URL + JWT_SECRET (≥32 chars)
npm run api:db:migrate

# Add Flutter platform code (REQUIRED — repo ships without ios/android folders)
cd apps/mobile && flutter create --org com.tribely --platforms=ios,android .
```

### Day-to-day

```bash
# Run API
npm run api:dev

# Run mobile (with API base URL override)
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://localhost:3000   # http://10.0.2.2:3000 on Android emulator

# Run all migrations + codegen across the monorepo
npm run migrate

# Just codegen
npm run codegen
```

## Architecture (Clean Architecture / DDD)

Both apps follow Clean Architecture, but deliberately use different layer counts:

- **Backend = 4-layer** (`domain/application/infrastructure/presentation`) — backend use cases orchestrate transactions, multiple aggregates, and domain events; the application layer earns its keep.
- **Flutter = 3-layer** (`domain/data/presentation`) — Flutter use cases are thin wrappers around a repository call; an `application/` layer would just add noise.

See [CLAUDE.md](./CLAUDE.md) for the full architecture decisions, citations to canonical sources (Robert Martin, Eric Evans, Reso Coder), and the reasoning behind every layer.

## Adding new code

Use the project skills under `.claude/skills/` — they enforce the layout consistently:

- Backend: `/api-new-feature`, `/api-new-entity`, `/api-new-usecase`, `/api-new-event`, `/api-new-value-object`, `/api-create-migration`, `/api-review-architecture`.
- Mobile: `/mobile-new-feature`, `/mobile-new-usecase`, `/mobile-new-page`, `/mobile-review-architecture`.

Each skill validates input and refuses bad ones (singular feature names, past-tense use case verbs, wrong target stack). Manual wiring (DI, route mounting, Prisma schema) stays manual on purpose.
