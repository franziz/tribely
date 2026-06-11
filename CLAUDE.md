# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Conventions are _enforced_ by skills in `.claude/skills/`.** CLAUDE.md is for the _why_; skills are the _how_. Skills are namespaced by target — `/api-*` for backend, `/mobile-*` for Flutter. Never use a backend skill on Flutter code or vice versa.

> **Stack-specific architecture and gotchas live in `.claude/rules/`**, path-scoped to load only when Claude works on matching files:
> - [`.claude/rules/api-architecture.md`](./.claude/rules/api-architecture.md) — backend layering, outbox/events, backend gotchas. Loads on `apps/api/**`.
> - [`.claude/rules/mobile-architecture.md`](./.claude/rules/mobile-architecture.md) — Flutter 3-layer, sanctioned cross-feature imports, mobile gotchas. Loads on `apps/mobile/**`.

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
npm run mobile:analyze                                                          # flutter analyze
npm run mobile:test                                                             # flutter test
npm run mobile:format                                                           # dart format .
npm run mobile:format:check                                                     # CI gate — fails on any unformatted file
npm run mobile:codegen                                                          # dart run build_runner build --delete-conflicting-outputs
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

## Cross-cutting gotchas

- **Don't apply API skills to mobile or vice versa.** They have intentionally different layering. Skills carry scope guards but the AI should also reject misapplied invocations on its own.
- **Branch protection on `main` IS enforced.** Direct pushes are rejected server-side (`GH006: Changes must be made through a pull request`) and the `CI passed` status check is required before merge — the previously-inert `ruleset-main.json` is now active. All changes to `main`, including docs / tooling / `.claude/**` / `CLAUDE.md`, go through a PR. Do NOT attempt or recommend direct commits to `main`; open a PR via `/github-pr`.
- **`/github-pr` is a user-global skill (`~/.claude/skills/`) whose defaults are tuned for another project — override them for this repo.** It defaults to base branch `dev` and auto-detects `lns-XX` Linear ids; this repo uses base **`main`** and **`TRI-XX`** ids in the `loonas` org. When invoking it, pass `--base main` and add the Linear link manually (`https://linear.app/loonas/issue/TRI-XX`). Do NOT "fix" this by editing the global skill — that would break the owner's other projects; the per-repo override belongs here.
- **For pub.dev / npm version ground truth, query the registry API, not git tags.** `curl https://pub.dev/api/packages/<pkg>` returns actual published versions plus analyzer/sdk constraints. Git tags can include unreleased prereleases (e.g., `0.10.0+1` exists as a tag but not on pub.dev).
- **Lint configs are deliberately strict.** API uses `tseslint.configs.strictTypeChecked`; mobile uses `flutter_lints` + 8 added rules + Dart's `strict-casts/inference/raw-types`. Tighten code to satisfy lints — don't loosen the lint config.
- **Cloud-provisioning tickets follow agents-draft / human-executes.** For tickets that require real cloud-account credentials (S3 bucket create, IAM user/policy, DNS, Resend domain verification, etc.), agents author the selection decision + a copy-pasteable CLI runbook under `docs/runbooks/<slug>.md`; the repo owner executes provisioning against the real cloud account out-of-band. The PR ships the SELECTION + code stubs + runbook; the resource itself is provisioned after merge. Don't try to have the orchestrator or SWE run `aws s3 mb` / `gcloud` / `wrangler` — they don't have credentials and shouldn't. TRI-77 (selfie storage) is the precedent.
- **`scripts/` and `tools/` are a deliberate split, not duplication.** `scripts/` holds Node-based dev helpers run by humans during local dev (`kill-port.mjs` etc); `tools/` holds the POSIX-shell build/ops chain (`build.sh`, `config.yml`, shared `lib/*.sh`) invoked by CI and the Docker image build. The split is by executable-language and consumer, not by feature — keep dev ergonomics out of the buildchain and vice versa.

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
- **Agent-to-agent communication.** Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) is enabled. The orchestrator runs each `/work-on-issue` cycle as a team of persistent, named teammates and re-engages them via `SendMessage` — async/queued, not live (send, the teammate wakes, replies, goes idle; no polling). Re-engagement preserves a teammate's context, so it carries only the delta, not a re-stated brief. The orchestrator still drives all messaging and gates every decision: agents reply self-contained **inline to the orchestrator** (which relays, e.g. reviewer→EL); they do NOT initiate peer-to-peer sends. See `.claude/skills/work-on-issue/SKILL.md` → "Coordination model" for the full choreography.

## Collaboration style

The repo owner explicitly invites pushback on architectural choices. When something is asked for that conflicts with the conventions above, name the trade-off and propose the alternative rather than silently complying or silently refusing. Conventions exist for documented reasons — but they're not laws. Argue back when a rule isn't earning its weight.
