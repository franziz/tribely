# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Conventions are _enforced_ by skills in `.claude/skills/`.** CLAUDE.md is for the _why_; skills are the _how_. Skills are namespaced by target — `/api-*` for backend, `/mobile-*` for Flutter. Never use a backend skill on Flutter code or vice versa.

## What Tribely is

A mobile app where solo travelers create events (drinks, hike, museum, dinner) and others request to join. Launching in **Singapore first**. Some architectural decisions hinge on this — single-user mobile view, English-only MVP, deferred payments. Don't recommend Bali/Lisbon-first launch strategies.

## Repo shape

```
apps/api      — Hono + Prisma + Postgres backend (modular monolith with domain events)
apps/mobile   — Flutter app (Riverpod + go_router + Dio + fpdart)
```

The backend is a modular monolith structured so individual features can be extracted to their own services later by swapping the in-process event bus for NATS/Kafka — without changing feature code. Don't introduce microservices preemptively. Full first-time setup is in [README.md](./README.md).

## Commands

### Backend

```bash
npm install                                     # install JS deps for the workspace
npm run api:dev                                 # tsx watch
npm run api:dev:fresh                           # kill any THIS-project process on port 3000, then start
npm run api:kill-port                           # safely free port 3000 (refuses to kill processes from other projects)
npm run api:build                               # tsc → dist/
npm run api:db:migrate                          # prisma migrate dev (applies pending; prompts for name on schema drift)
npm run api:db:migrate:create                   # prisma migrate dev --create-only (generate without applying)
npm run api:db:studio
npm run typecheck                               # all workspaces
npm run test                                    # all workspaces
npm run --workspace=@tribely/api test path/to/foo.test.ts   # single test
```

`apps/api/.env` must exist before `npm run api:dev`. Copy `.env.example`; set `DATABASE_URL` and a `JWT_SECRET` of ≥32 chars. Env is parsed by Zod at boot — invalid values throw.

### Mobile

The mobile package is a single Flutter app at `apps/mobile/`. There is **no Melos and no Pub Workspaces** — Melos was dropped in TRI-1 because Pub Workspaces breaks `custom_lint`'s analyzer plugin in CI, and with one Flutter package the orchestration overhead doesn't earn its weight. Reintroduce Melos (and possibly Pub Workspaces) when a second Flutter package arrives AND `custom_lint` ships verified workspace support.

```bash
cd apps/mobile && flutter pub get                                              # fetch deps
cd apps/mobile && flutter create --org com.tribely --platforms=ios,android .   # REQUIRED on first run — repo ships without ios/android folders
npm run mobile:run                                                              # reads apps/mobile/.env.json (use http://10.0.2.2:<port> on Android emulator)
npm run mobile:analyze                                                          # cd apps/mobile && flutter analyze
npm run mobile:test                                                             # cd apps/mobile && flutter test
npm run mobile:codegen                                                          # cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
cd apps/mobile && dart run build_runner watch --delete-conflicting-outputs     # watch mode
cd apps/mobile && flutter test test/path/to/foo_test.dart                      # single test
```

### Cross-stack

```bash
npm run migrate                 # api:db:migrate + mobile:codegen
npm run codegen                 # api:db:generate + mobile:codegen
```

### Pre-commit local checks

Run all four CI gates locally before `git commit` — CI is minutes, local is seconds, and `format:check` is a separate CI step that's easy to forget when only running typecheck/lint/test:

```bash
# API
npm run --workspace=@tribely/api format:check && npm run --workspace=@tribely/api typecheck && npm run --workspace=@tribely/api lint && npm run --workspace=@tribely/api test
# Mobile
npm run mobile:format:check && npm run mobile:analyze && npm run mobile:test
```

## CI

GitHub Actions workflows live in `.github/workflows/`:

- `ci.yml` — entry: triggers, path filters via `dorny/paths-filter`, dispatches reusable jobs, `ci-passed` aggregate gate
- `_api.yml`, `_mobile.yml` — reusable workflows (`workflow_call`)
- Composite actions in `.github/actions/{setup-api,setup-mobile}/`

When adding a new check surface (deploy, e2e, web): create a new reusable workflow + composite action, dispatch from `ci.yml`. Don't touch existing files.

All third-party actions are SHA-pinned with `# vX.Y.Z` comments — Dependabot only alerts on SHA-pinned actions.

## Architecture — backend (`apps/api`)

Sources: [Robert Martin's Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html), [Eric Evans's DDD layered architecture](https://www.domainlanguage.com/ddd/), [Domain-Driven Hexagon](https://github.com/Sairyss/domain-driven-hexagon), [Ardalis Clean Architecture](https://github.com/ardalis/cleanarchitecture).

### Layers (per feature)

```
features/<name>/
  domain/                              # Enterprise business rules. ZERO infra imports.
    entities/                          # Aggregate roots — extend AggregateRoot, methods not data bags
    value-objects/                     # Email, Password — private ctor + create() factory
    events/                            # Domain events this feature emits
    services/                          # ONLY true domain services (stateless ops across aggregates)
    repositories/                      # Interfaces — methods accept optional TxContext
    ports/                             # Outbound interfaces: PasswordHasher, TokenIssuer, Mailer, Clock
  application/                         # Application business rules — orchestration only
    usecases/                          # One class per user intent. Constructor injection.
                                       # Wraps state-changing work in unitOfWork.run(...)
  infrastructure/                      # Driven adapters
    persistence/                       # <aggregate>.prisma-repository.ts + <aggregate>.mapper.ts
    adapters/                          # Concrete impls of domain ports — JWT, argon2, mailer, clock
  presentation/                        # Driving adapters
    http/  controllers/  routes/  schemas/   # Zod schemas
    events/                            # Subscribers — translate bus events into use case calls
```

### Why `application/` and `domain/` are separate (4-layer)

Robert Martin's Clean Architecture defines two distinct kinds of business rules:

- **Enterprise Business Rules** (Evans's Domain Layer) — exist regardless of any application. "A user has an email." Embodied as Entities, Value Objects, Aggregates.
- **Application Business Rules** (Evans's Application Layer) — specific to _this_ application's flows. "Sign-up creates a credential AND a user atomically and emits two events." Embodied as use cases.

The split gives reusability (domain works for API + ops CLI + scheduled jobs), testability (domain tests are pure), and future extraction (domain travels untouched when extracting a service).

### Why `infrastructure/` and `presentation/` are separate (driven vs. driving adapters)

Hexagonal architecture: every adapter either _receives_ a call from outside (driving — HTTP controller, event subscriber, CLI) or _makes_ a call outside (driven — DB repository, mailer, payment gateway). They sit on opposite sides of the application core.

A subscriber listens for an event and calls a use case — same role as a controller, just for the bus instead of HTTP. So subscribers live in `presentation/events/`, not `application/`.

### Aggregates and events

Aggregates extend `AggregateRoot` (in `core/domain/`). State-changing methods record events. Application services pull events off the aggregate after a successful operation and publish them via `EventPublisher` inside the same `UnitOfWork`:

```typescript
const credential = Credential.issue({ userId, passwordHash, now }); // records event
await unitOfWork.run(async (ctx) => {
  await credentials.save(credential, ctx);
  await events.publish(ctx, ...credential.pullEvents()); // atomic with save
});
```

IDs are generated by the use case via `createId()` from `@paralleldrive/cuid2`, NOT by the database. This keeps the domain authoritative over identity. `Aggregate.create({ id, ... })` accepts its id explicitly.

### Transactional outbox + per-consumer offsets (TRI-38)

`EventPublisher.publish(ctx, ...events)` writes to `outbox_events` in the supplied transaction. Each event gets a monotonic `seq BIGSERIAL`. The `OutboxDispatcher` polls and delivers events to each registered `Consumer` independently — Kafka-shaped fan-out, Postgres-backed.

```typescript
// A consumer reacts to another feature's event:
export const issueEmailVerificationOnUserRegistered = (deps): Consumer<UserRegisteredEvent> => ({
  name: 'auth.issueEmailVerificationOnUserRegistered', // PK in consumer_offsets — stable across deploys
  topic: USER_REGISTERED,
  async handle(event, ctx) {
    await deps.issueEmailVerification.execute({ userId: event.payload.userId });
  },
});
```

**Each Consumer is a Kafka consumer group of one.** `Consumer.name` is the primary key in `consumer_offsets` — must be globally unique and stable across deploys (Convention: `<feature>.<verbPresentImperativeOnSourceEvent>`). Independent progress per consumer; a failing consumer head-of-line blocks **only itself**, never sibling consumers of the same topic. Bounded retry (default 5 attempts) → `blockedAt` is set; ops manually unblocks.

**Use `/api-new-producer` and `/api-new-consumer` skills.** Scaffolding enforces the naming + idempotency contract. Don't subscribe inline.

**Handlers MUST be idempotent.** At-least-once delivery; transient failures retry the same event with the same `ConsumerContext`.

### Request-context propagation (AsyncLocalStorage)

`requestId` + `actorUserId` flow through every async boundary inside a single HTTP request via `AsyncLocalStorage`. The `requestContext` middleware opens the frame; `requireAuth` upgrades `actorUserId` after JWT verify; `OutboxEventPublisher` reads the frame and persists both onto the outbox row; the dispatcher re-establishes the frame at dispatch time so downstream events the consumer publishes inherit the same correlation chain (Kafka headers semantics in Postgres form).

**Use cases stay clean** — no `meta` parameter threading. Just `useCase.execute(input)`. The publisher reads ALS automatically.

**Non-HTTP callers (boot, future cron jobs, CLI) MUST wrap in `runAsSystem(label, fn)`** from `core/context/system-context.ts`. Without it, the publisher logs WARN and persists `requestId=null`, rotting the audit chain. The `label` is your audit-visible identity (`boot.dispatcher-warmup`, `cron.prune-refresh-tokens`).

### Audit (HTTP + event lifecycle)

Two narrow audit tables, both keyed by `requestId` for cross-table joins:

- `http_audit_logs` — one row per inbound HTTP request. Method, path, status, duration, actor, IP, UA, errorCode. **No body content stored** (PDPA-friendly for the Singapore launch).
- `event_audit_logs` — one row per event lifecycle phase: `published` (producer-side, atomic with outbox row), `dispatched` / `failed` / `blocked` (consumer-side).

Lives in `features/audit/` (bounded context with its own verbs + retention policy, not in `core/`).

### TxContext is opaque to the domain

`UnitOfWork.run(work)` passes a `TxContext` to the closure. Domain code treats it as an opaque marker — only infrastructure adapters (via `unwrapTx` in `core/db/prisma-unit-of-work.ts`) can extract the underlying Prisma transaction client. **No Prisma type leaks into the domain.**

### Bounded-context rule

Feature B never queries feature A's tables directly. It either:

1. Calls A's repository through its public interface (cross-feature import allowed for _interfaces_, never impls).
2. Subscribes to A's domain events and maintains its own read model (preferred for true decoupling).

## Architecture — mobile (`apps/mobile`)

Sources: [TDD Clean Architecture for Flutter (Reso Coder)](https://github.com/ResoCoder/flutter-tdd-clean-architecture-course), [Flutter Clean Architecture with Riverpod](https://github.com/uuttssaavv/flutter-clean-architecture-riverpod).

### Layers (per feature) — 3 layers, NOT 4

```
features/<snake_name>/
  domain/                              # Pure Dart — no Flutter, no Dio, no Riverpod
    entities/                          # Equatable classes
    repositories/                      # Abstract interfaces returning Either<Failure, T>
    usecases/                          # Implements UseCase<T, Params>; Future<Either<Failure, T>>
  data/
    models/                            # JSON serialization + toEntity()
    datasources/                       # RemoteDataSource (interface + impl colocated)
    repositories/                      # Concrete impls — catch DioException → Failure
  presentation/
    pages/                             # ConsumerWidget screens
    widgets/                           # Feature-scoped widgets
    providers/                         # Riverpod providers wiring use cases
    controllers/                       # StateNotifier — owns state transitions
    state/                             # Sealed state classes
```

### Why Flutter is 3-layer (NOT 4-layer like the API)

Flutter use cases are thin wrappers: `call(params) => repository.method()`. They don't orchestrate transactions, multiple aggregates, or events. Adding an `application/` layer for thin wrappers is over-engineering on the client. Reso Coder's tutorial and the Riverpod community examples both keep use cases in `domain/usecases/` — we follow that convention. **The asymmetry is intentional**, not an inconsistency to "fix."

### Why mobile keeps `data/datasources/` (the API doesn't)

On the API, Prisma is the persistence layer — a separate datasource layer adds dead weight. On the mobile, the datasource layer is meaningful (REST + cache + local DB are genuinely different sources, and the repository orchestrates them). The Flutter community convention earns its keep here.

### Why repositories return `Either<Failure, T>` on mobile but throw on API

- API: throwing `AppError` flows into Hono's `onError` middleware producing a uniform HTTP shape.
- Mobile: UI needs to render error states declaratively; failures are part of the type signature, eliminating uncaught-exception UI bugs.

## Common conventions across both stacks

### What is a "feature"

A feature folder = a **bounded context**: a slice of the domain with its own ubiquitous language, its own aggregate(s), its own lifecycle.

**Tests for "is this a feature?":**

1. Owns at least one aggregate root + persistence nobody else writes to (backend) / a coherent set of screens with their own state (mobile).
2. Has its own verbs the business cares about (`CreateEvent`, `ApproveJoinRequest`).
3. Could be extracted to its own service (backend) or its own package (mobile) later without rewriting it.
4. The domain expert recognizes its name as a thing in the business.

**NOT a feature:**

- Infrastructure (event bus, file storage, logging) → `core/`.
- Only invoked from one feature with no independent lifecycle → sub-concept inside that feature.
- Data another feature already owns (avatar upload is part of `users`).

**Naming:** plural noun, kebab-case backend (`events`, `join-requests`), snake_case mobile (`events`, `join_requests`).

### One use case per intent

`CreateEventUseCase`, not `EventsUseCase.create(...)`. One file per intent. Both stacks.

## Adding new code — use the skills

```
# Backend
/api-new-feature <plural-kebab-name>
/api-new-entity <feature> <SingularName>
/api-new-usecase <feature> <verb-noun>
/api-new-event <feature> <verb-past>
/api-new-value-object <feature> <Name>
/api-create-migration [<migration-name>]
/api-review-architecture [<git-ref>]

# Mobile
/mobile-new-feature <plural-kebab-name>
/mobile-new-usecase <feature> <verb-noun>
/mobile-new-page <feature> <page-name> [--stateful]
/mobile-review-architecture [<git-ref>]

# Cross-stack
/repo-review-consistency [<glob>]    # tooling / CI / SOT consistency audit (flagging only)
```

Full skill index: [.claude/skills/README.md](./.claude/skills/README.md). Skills validate input and refuse misapplied invocations (singular feature names, wrong stack, past-tense use case verbs, etc.).

### Manual wiring after scaffolding (deliberately not automated)

After scaffolding, you must:

1. Register dependencies in `apps/api/src/core/di/container.ts` or `apps/mobile/lib/src/core/di/service_locator.dart`.
2. Mount routes (`apps/api/src/app.ts` for backend, `apps/mobile/lib/src/core/router/app_router.dart` for mobile).
3. Backend subscribers: call `register<Name>Subscribers(bus)` from `buildContainer()`.
4. Backend schema changes: use `/api-create-migration`.

## Common gotchas

- **Events must be past-tense** (`event-created`, not `create-event` — that's a use case).
- **No `data/datasources/` on the API.** Backend uses `infrastructure/persistence/<aggregate>.prisma-repository.ts` directly.
- **No Prisma types in `domain/` or `application/` (backend).** Only `@/core/db/unit-of-work.port` is allowed. The opaque `TxContext` is intentional.
- **Mobile session-state is the only sanctioned cross-feature `presentation/` import.** Features may import `auth/presentation/providers/auth_providers.dart` to read `sessionControllerProvider` for current-user identity; every other cross-feature `presentation/`-to-`presentation/` import violates the bounded-context rule. Session identity is genuinely app-global state, not feature state — duplicating it per feature would fragment auth and invite drift on logout/refresh.
- **Mobile `flutter create` is required on first run** — repo ships without `ios/`/`android/` folders.
- **`outbox_events` is append-only.** Per-consumer progress lives in `consumer_offsets`, not on the event row. Migrations that drop the outbox table lose in-flight events for every consumer.
- **Consumers must register with a stable, globally-unique `name`.** It's the primary key in `consumer_offsets`. Renaming a Consumer in code without a migration that renames the offset row resets it to `committedSeq=0` and replays all history — usually NOT what you want.
- **AsyncLocalStorage is invisible state — easy to lose across the outbox boundary.** The publisher persists `requestId` on the outbox row at publish time and the dispatcher re-establishes the frame at dispatch time, so consumers see correlation. But any publish path NOT inside a `runWithContext` / `runAsSystem` frame (boot, cron, CLI, tests that bypass middleware) silently writes `requestId=null` and logs WARN. Wrap non-HTTP entry points in `runAsSystem('label', fn)`.
- **Two features can share an HTTP route prefix via additive `app.route()` mounts.** When feature B needs endpoints under feature A's prefix (e.g., `join-requests` adds `POST /events/:id/join-requests` while `events` already owns `app.route('/events', buildEventRoutes(...))`), keep B's routes in B's router file and add a second `app.route('/events', buildJoinRequestsRoutes(...))` in `apps/api/src/app.ts`. Hono v4 `app.route()` at the same prefix merges — it does NOT override the first mount. Do not shoehorn B's endpoints into A's router file (bounded-context violation). Only path-level collisions need avoiding; Hono's first-registered-wins on exact ties.
- **Don't apply API skills to mobile or vice versa.** They have intentionally different layering. Skills carry scope guards but the AI should also reject misapplied invocations on its own.
- **Mobile lint plugin: top-level `plugins:`, NOT `analyzer.plugins: - custom_lint`.** `riverpod_lint` uses the Dart 3.5+ `analysis_server_plugin` mechanism in `apps/mobile/analysis_options.yaml`. The `analyzer.plugins:` form (custom_lint host) has an upstream synthesizer bug that breaks resolution.
- **Branch protection on `main` is NOT enforced** (GitHub free-tier private repo limitation). CI checks are advisory; manual discipline replaces automated gating until plan upgrade. `ruleset-main.json` at repo root is uploaded but inert.
- **For pub.dev / npm version ground truth, query the registry API, not git tags.** `curl https://pub.dev/api/packages/<pkg>` returns actual published versions plus analyzer/sdk constraints. Git tags can include unreleased prereleases (e.g., `0.10.0+1` exists as a tag but not on pub.dev).
- **Lint configs are deliberately strict.** API uses `tseslint.configs.strictTypeChecked`; mobile uses `flutter_lints` + 8 added rules + Dart's `strict-casts/inference/raw-types`. Tighten code to satisfy lints — don't loosen the lint config.
- **Email auth uses 6-digit codes, not magic-link URLs.** Mobile-first; universal-links wait on production deployment (TRI-2). `EmailSender.sendVerification` / `sendPasswordReset` take `{ to, code }`, not `{ to, url }`.
- **Production sender domain is `gotribely.com`** (not `tribely.app`). `EMAIL_FROM` defaults to `onboarding@resend.dev` in code so dev "just works" without DNS verification; production must override once `gotribely.com` DKIM is set up in Resend.
- **CI test steps need `DATABASE_URL` + `JWT_SECRET` set as placeholders.** `env.ts` parses `process.env` at module load and throws on missing required vars; any test that transitively imports the logger (or anything from `core/`) fails to collect. `_api.yml`'s test step sets dummy values — copy that pattern when adding new test surfaces.
- **Vitest does not auto-load `.env`.** Integration tests that need real env vars (e.g., `RESEND_API_KEY`) must `import 'dotenv/config'` at the top of the test file. Without it, `process.env.X` is `undefined` and `it.skipIf(!process.env.X)` silently skips the suite even when `apps/api/.env` is present.

## Agent orchestration & role boundaries

This repo uses a multi-agent workflow (definitions in `.claude/agents/`). The orchestrator (main loop) coordinates; specialized agents execute. Role boundaries are binding, not advisory.

### Role map

- **`ceo`** — strategic direction, scope alignment with the Singapore launch. Non-technical. No code, no Linear.
- **`product-manager`** — sole authority on Linear writes (Tribely team only). Decomposes business goals into product requirements with acceptance criteria. No code.
- **`ui-ux-designer`** — UI/UX design specifications, competitor pattern research, layout/hierarchy/flow decisions. Consulted ONLY when an issue has user-facing design surface (new screens, flows, design-system additions). Produces specs and rationale, NOT code. Skipped for backend, tooling, or UI work that follows an already-specified design.
- **`engineering-lead`** — translates PRODUCT requirements into TECHNICAL requirements. Triages reviews, signs off on architecture. Surfaces follow-up items to PM; does NOT create Linear tickets directly.
- **`software-engineer`** — code, CLI, migrations, tests, debugging only. No Linear, no PR creation, no stakeholder comms.
- **`architecture-reviewer`** — runs `/api-review-architecture` / `/mobile-review-architecture`, reports findings only. No code edits, no Linear.
- **`qa`** — runs test scripts, surfaces failures to SWE. No code, no Linear.

### Orchestrator rules

- **Branch-first when starting a Linear ticket.** Before any code changes, create a feature branch named `<type>/TRI-XX-<short-slug>` where `<type>` is `feat` / `chore` / `fix` / `refactor` (matching the eventual commit's Conventional Commits prefix). Land all related work on the branch, then open a PR via `/github-pr`. Direct commits to `main` are for one-off corrections only — not feature work.
- **Delegate execution; don't run directly.** Bash commands (migrations, tests, git operations on project code), `Edit`/`Write` on source files, npm/flutter invocations — all go through the `software-engineer` agent, not the orchestrator's tool calls. The orchestrator's job is routing, summarizing agent reports, and asking the user for decisions. Trivial read-only context-gathering for routing decisions is fine; execution is not.
- **Linear / PR work is orchestrator- or PM-routed via skills**, not delegated to SWE. Use `/linear-techdebt`, `/linear-create-issue`, `/linear-bug`, `/github-pr`, `/github-commit` — invoke as skills, or route to `product-manager`. Never to `software-engineer`.
- **Commits split by logical scope.** When invoking `/github-commit`, enumerate the logical groups in the diff (feature vs tooling vs refactor vs CLAUDE.md edits) so the skill produces one commit per scope. Never bias toward "single bundled commit" — bundled commits dilute review scope and complicate reverts. Refactors done in service of a feature can be bundled with it; tooling and skill changes are always separate.
- **Hero-flow PRs and time-dependent-validator changes require a manual on-device smoke before PR.** `/work-on-issue` Step 8.5 generates a named, click-by-click checklist; orchestrator posts it to the user and pastes it into the PR description. No automated harness (deferred); no auto-Done.
- **Don't bypass PATH with absolute tool paths.** When a CLI tool (e.g., `gh`, `flutter`) is not on PATH, report it and ask the user — don't hunt `/opt/homebrew/bin/`, `/usr/local/bin/`, `~/.local/bin/` to invoke it directly. The user keeps tools off PATH intentionally; reaching around defeats that gating.
- **Agent-to-agent communication.** Without Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`), there is no direct messaging — orchestrator relays. With Agent Teams enabled, `SendMessage` is available but async (queued, not live). Reviewer-to-Eng-Lead handoffs flow through the orchestrator or the inbox; agents must emit memo content inline so it can be relayed regardless.

## Collaboration style

The repo owner explicitly invites pushback on architectural choices. When something is asked for that conflicts with the conventions above, name the trade-off and propose the alternative rather than silently complying or silently refusing. Conventions exist for documented reasons — but they're not laws. Argue back when a rule isn't earning its weight.
