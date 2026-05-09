# Tribely

Monorepo for the Tribely mobile app (Flutter) and API (Hono + TypeScript).

## What Tribely is

A mobile app where solo travelers create real-life events (drinks, hike, museum, dinner) and others request to join. Launching in **Singapore first**. Trust + safety is the highest-value driver in this category — auth and verification are the first impressions and shape every product decision around them.

## Why a monorepo

The mobile and backend co-evolve: an API change usually requires a matching client change. Keeping both in one repo means:

- AI assistants (and humans) see the contract and the consumer in one context — fewer drift bugs across renamed fields, mismatched enums, stale DTOs.
- Atomic commits that span both sides.
- One repo to clone, one place to track issues.

Cross-language type sharing (TS ↔ Dart) isn't possible via direct import. The plan when it matters is **OpenAPI codegen**: define schemas once on the API side (Zod), generate an OpenAPI spec, generate a typed Dart client into `apps/mobile/lib/src/generated/`. Until then, types are duplicated and kept in sync manually.

## Layout

```
.
├── apps/
│   ├── api/              # Hono + Prisma + Postgres backend (4-layer Clean Arch)
│   └── mobile/           # Flutter app (3-layer Clean Arch, Riverpod 3 + go_router + Dio)
│       ├── assets/
│       │   ├── fonts/    # Fraunces + General Sans (download once — see fonts/README.md)
│       │   └── images/   # welcome-hero.webp etc
│       ├── design/login/ # Login design spec + photo brief
│       └── lib/src/      # Source
├── .claude/skills/       # Project-scoped scaffolding + review skills (api-*, mobile-*)
├── scripts/              # Helper scripts (port killer, etc.)
├── package.json          # npm workspaces — TS packages
├── pubspec.yaml          # Dart Pub Workspace + Melos 7.x config — Flutter packages
├── CLAUDE.md             # Architecture conventions for future Claude sessions
└── tsconfig.base.json
```

---

## Setup

### Prerequisites

- **Node** ≥ 20.18, **npm** ≥ 10
- **Flutter** ≥ 3.27, **Dart** ≥ 3.6 (required by Pub Workspaces and Melos 7.x)
- **Postgres** 15+ (local install, Docker, or a hosted instance like Neon)
- **Melos 7.x**: `dart pub global activate melos`

### One-time setup

```bash
# 1. Install JS dependencies (npm workspaces)
npm install

# 2. Bootstrap the Dart Pub Workspace (Melos 7.x — no `melos bootstrap` anymore)
dart pub get

# 3. Configure the API
cp apps/api/.env.example apps/api/.env
#    Edit apps/api/.env:
#      DATABASE_URL=postgresql://postgres:postgres@localhost:5432/tribely?schema=public
#      JWT_SECRET=<at least 32 random chars>

# 4. Apply database migrations (Prisma 7.x; prompts for a name on first run)
npm run api:db:migrate

# 5. Generate Flutter platform code (REQUIRED — repo ships without ios/android folders)
cd apps/mobile && flutter create --org com.gotribely --platforms=ios,android .

# 6. Download the brand fonts
#    See apps/mobile/assets/fonts/README.md for links and filenames.
#    Without them the app still runs — Flutter falls back to the system font.

# 7. Configure the mobile app
cp apps/mobile/.env.example.json apps/mobile/.env.json
#    Edit apps/mobile/.env.json — set API_BASE_URL.
#    On Android emulator use http://10.0.2.2:<port>; on iOS simulator localhost is fine.

# 8. (Optional) Drop the welcome hero photo
#    See apps/mobile/design/login/welcome-photo-prompt.md.
#    Save as apps/mobile/assets/images/welcome-hero.webp.
#    Without it the welcome screen renders a clean ink-mark fallback.
```

### Daily commands

**Backend (`apps/api`)**

| Command                                                     | Purpose                                                       |
| ----------------------------------------------------------- | ------------------------------------------------------------- |
| `npm run api:dev`                                           | tsx watch on `src/index.ts`                                   |
| `npm run api:dev:fresh`                                     | Free port 3000 (only this project's process), then start dev  |
| `npm run api:kill-port`                                     | Free port 3000 safely (refuses processes from other projects) |
| `npm run api:build`                                         | tsc → `dist/`                                                 |
| `npm run api:start`                                         | `node dist/index.js` (after build)                            |
| `npm run api:db:migrate`                                    | Apply pending migrations + prompt for name on schema drift    |
| `npm run api:db:migrate:create`                             | Generate a migration file without applying                    |
| `npm run api:db:studio`                                     | Open Prisma Studio                                            |
| `npm run --workspace=@tribely/api test path/to/foo.test.ts` | Run a single test                                             |

**Mobile (`apps/mobile`)**

| Command                                         | Purpose                                                                  |
| ----------------------------------------------- | ------------------------------------------------------------------------ |
| `npm run mobile:run`                            | Run mobile (reads `apps/mobile/.env.json` via `--dart-define-from-file`) |
| `npm run mobile:build:apk` / `mobile:build:ios` | Release build (also reads `.env.json`)                                   |
| `melos run analyze`                             | flutter analyze across packages                                          |
| `melos run test`                                | flutter test across packages                                             |
| `melos run build_runner`                        | One-shot codegen                                                         |
| `melos run build_runner:watch`                  | Watch-mode codegen                                                       |
| `flutter test test/path/to/foo_test.dart`       | Run a single test                                                        |

**Cross-stack (run from repo root)**

| Command             | Purpose                                   |
| ------------------- | ----------------------------------------- |
| `npm run typecheck` | tsc --noEmit across all TS workspaces     |
| `npm run test`      | vitest across all TS workspaces           |
| `npm run migrate`   | API DB migrate + mobile codegen           |
| `npm run codegen`   | API Prisma generate + mobile build_runner |

---

## Architecture

Both apps follow Clean Architecture, but deliberately use different layer counts.

|        | Backend (`apps/api`)                                             | Mobile (`apps/mobile`)                                               |
| ------ | ---------------------------------------------------------------- | -------------------------------------------------------------------- |
| Layers | 4 — `domain` / `application` / `infrastructure` / `presentation` | 3 — `domain` / `data` / `presentation`                               |
| Why    | Use cases orchestrate transactions, multiple aggregates, events  | Use cases are thin wrappers; an `application/` layer would add noise |
| State  | `AggregateRoot` records events; outbox guarantees atomicity      | Riverpod 3 `Notifier` + sealed states + fpdart `Either<Failure, T>`  |
| Errors | Repositories throw `AppError`; Hono middleware uniforms it       | Repositories return `Either<Failure, T>` for declarative UI states   |

See [CLAUDE.md](./CLAUDE.md) for full conventions: citations (Robert Martin, Eric Evans, Domain-Driven Hexagon, Ardalis, Reso Coder), why each layer exists, ports/adapters, the bounded-context rule, common gotchas.

### What's currently implemented

**Backend — auth foundation:**

```
POST /auth/sign-up         email + password + displayName  → user + access + refresh tokens
POST /auth/sign-in         email + password               → user + access + refresh tokens
POST /auth/refresh         refresh token                  → rotated tokens (reuse-detection wipes all sessions)
POST /auth/sign-out        refresh token                  → revokes one session (idempotent)
POST /auth/sign-out-all    auth required                  → revokes all sessions for the current user
GET  /auth/me              auth required                  → current user
GET  /users/:id            public                         → user profile
GET  /health
```

Behind these:

- Bounded contexts: `users` owns the User aggregate (identity); `auth` owns Credential + RefreshToken aggregates.
- Refresh-token rotation with reuse-detection — leaked tokens trigger a sign-out-all on detection.
- Transactional outbox — every state change publishes a domain event atomically with the data write.
- Rate limits (in-memory, swappable for Redis): 5/min sign-up, 10/min sign-in, 30/min refresh per IP.
- Argon2 password hashing, JWT access tokens (15 min), opaque SHA-256-hashed refresh tokens (30 days).
- Ports for everything: `PasswordHasher`, `AccessTokenIssuer`, `RefreshTokenHasher`, `RateLimiter`, `UnitOfWork`, `Clock`, `EventPublisher`. Domain code never imports Prisma.

**Mobile — login experience:**

- Splash → silent refresh against `/auth/refresh` → routes to home or welcome
- Welcome → mood photo + headline + sign-in/sign-up CTAs
- Sign-in / Sign-up — full state matrix (idle/submitting/success/error/disabled), banners for 401/429/network/conflict, password-strength meter, "show / hide" text toggle, AutofillHints
- Forgot password sheet — honest MVP placeholder
- Home — auto-dismissing greeting, sign-out
- Equatorial Editorial design system — Fraunces + General Sans, teak teal + ember coral palette, paper grain overlay, hand-drawn ink mark with stroke-dash animation
- Riverpod 3 Notifier API throughout (StateNotifier is legacy in 3.x)
- go_router with redirect logic driven by `SessionController` state
- Dark + light themes, full reduced-motion support, WCAG AA contrast verified

The full login design spec — rationale, screen-by-screen, all states, microcopy — lives at [`apps/mobile/design/login/spec.md`](./apps/mobile/design/login/spec.md).

### What's NOT yet built

- Apple Sign-In (required if Google Sign-In ships first — Apple Store rule)
- Google Sign-In (deferred — see CLAUDE.md design notes; ~3-4h of work when needed)
- Password reset flow (entry point exists; backend not built — currently directs to support email)
- Email verification
- Profile management beyond display name
- Anything beyond auth (events, join requests, chats, reviews — those are new bounded contexts)

---

## Adding new code — use the skills

Project-scoped Claude Code skills under `.claude/skills/` enforce the conventions. Each skill validates input and refuses misapplied invocations (singular feature names, past-tense use case verbs, wrong target stack).

| Skill                         | Scope   | Purpose                                                                           |
| ----------------------------- | ------- | --------------------------------------------------------------------------------- |
| `/api-new-feature`            | Backend | Bootstrap a bounded-context feature (4-layer scaffold)                            |
| `/api-new-entity`             | Backend | Aggregate root + paired Prisma mapper                                             |
| `/api-new-usecase`            | Backend | Orchestrating use case in `application/usecases/`                                 |
| `/api-new-event`              | Backend | Domain event with `<feature>.<verbPastTense>` naming                              |
| `/api-new-value-object`       | Backend | VO with private ctor + `create()` factory                                         |
| `/api-create-migration`       | Backend | Generate Prisma migration with AI-suggested name + destructive-change warnings    |
| `/api-review-architecture`    | Backend | Check changed `apps/api/**` files against 13 architecture rules                   |
| `/mobile-new-feature`         | Mobile  | Bootstrap a feature (3-layer scaffold, Reso Coder convention)                     |
| `/mobile-new-usecase`         | Mobile  | Use case implementing `UseCase<T, Params>` returning `Future<Either<Failure, T>>` |
| `/mobile-new-page`            | Mobile  | `ConsumerWidget` page; `--stateful` adds Notifier controller + sealed state       |
| `/mobile-review-architecture` | Mobile  | Check changed `apps/mobile/lib/**` files against Flutter rules                    |

Manual wiring (DI registration, route mounting, Prisma schema edits) stays manual on purpose — those need judgement about exact placement.

Full skill index and rationale: [`.claude/skills/README.md`](./.claude/skills/README.md).

---

## Stack pin-points

Every dependency is on its current stable as of the last bump (verified via Context7).

**API:**

- Hono 4.10+, `@hono/node-server`, `@hono/zod-validator`
- Prisma 7.6+ with `@prisma/adapter-pg` driver adapter (Prisma 7 moved the connection URL out of `schema.prisma` into `prisma.config.ts`; the runtime client connects via the pg driver)
- Zod 3.24 (Zod 4 is out but Hono ecosystem hasn't fully caught up)
- Pino 10, jose 6, argon2 0.43, `@paralleldrive/cuid2` for IDs
- Vitest 3, TypeScript 5.9

**Mobile:**

- Flutter 3.27+, Dart 3.6+ (Pub Workspaces minimum)
- Riverpod 3.0+ (Notifier API; **`StateNotifier` is legacy in 3.x** — moved to `flutter_riverpod/legacy.dart`)
- Freezed 3, go_router 16+, Dio 5.9, fpdart 1.1, get_it 8.2, custom_lint 0.8
- Custom design system (no Material You defaults, no third-party UI kits)

---

## Troubleshooting

**`npm run api:dev` fails with `Port 3000 is held by ...`** — another local service has the port. Run `npm run api:kill-port` first (it refuses to kill processes outside this repo, so you'll get a clear error pointing at the PID for manual handling).

**Prisma error: `The datasource property 'url' is no longer supported in schema files`** — Prisma 7 moved this. The fix is already in place: connection URL lives in `apps/api/prisma.config.ts` and the runtime client uses `@prisma/adapter-pg`. If you see this after pulling, run `npm install` to pick up the adapter.

**Mobile build complains about missing Fraunces / General Sans** — fonts must be downloaded into `apps/mobile/assets/fonts/`. See `assets/fonts/README.md` for links. Without them the app falls back to the system font and prints a one-time warning at startup.

**Welcome screen renders an ink mark instead of a photo** — that's the asset-missing fallback. Drop a `welcome-hero.webp` into `apps/mobile/assets/images/`. The brief at `apps/mobile/design/login/welcome-photo-prompt.md` explains what to source.

**`flutter run` errors about missing iOS/Android folders** — run `flutter create --org com.gotribely --platforms=ios,android .` from `apps/mobile/`. It's non-destructive (only fills in missing platform folders).

**Prisma migration fails with "schema drift"** — your local DB diverged from the migration history. Either (a) `npx --workspace=@tribely/api prisma migrate reset` to wipe local data and replay (only safe in dev), or (b) regenerate the schema by hand. The `/api-create-migration` skill helps with the latter.

**Riverpod errors about `StateNotifierProvider`** — Riverpod 3.x moved it to a legacy import. New code uses `NotifierProvider` with the `Notifier` API; see `apps/mobile/lib/src/features/auth/presentation/controllers/sign_in_controller.dart` for the canonical pattern.

---

## Contributing

This is a small, opinionated codebase. The conventions in [CLAUDE.md](./CLAUDE.md) aren't laws — but they exist for documented reasons. Argue back when a rule isn't earning its weight; don't silently bypass it. The project skills are the easiest way to keep new code consistent with what's already there.
