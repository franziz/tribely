# Project skills

Project-scoped Claude Code skills that enforce Tribely's architecture conventions. CLAUDE.md documents the _why_; these skills are the _how_.

Skills are **namespaced by target** (`api-*` for backend, `mobile-*` for Flutter) so the AI never accidentally uses an API skill in mobile code or vice versa. Each skill carries an explicit scope guard in its description and refuses misapplied invocations.

## Backend (`apps/api`) — Hono + Prisma + TypeScript

| Skill                      | Purpose                                                                                              |
| -------------------------- | ---------------------------------------------------------------------------------------------------- |
| `/api-new-feature`         | Bootstrap a bounded-context feature folder (4-layer: domain/application/infrastructure/presentation) |
| `/api-new-usecase`         | Add a use case in `application/usecases/` (orchestrates UnitOfWork + EventPublisher + repos)         |
| `/api-new-entity`          | Add an aggregate root extending `AggregateRoot`, with paired Prisma mapper                           |
| `/api-new-event`           | Add a domain event with `<feature>.<verbPastTense>` naming                                           |
| `/api-new-producer`        | Add a domain event + producer-side guidance (ALS-based requestId propagation, TRI-38)                |
| `/api-new-consumer`        | Add a `Consumer<TEvent>` for the per-consumer-offsets event bus (TRI-38)                             |
| `/api-new-value-object`    | Add a VO with private ctor + `create()` factory                                                      |
| `/api-create-migration`    | Generate a new Prisma migration from schema diff (suggests names, warns on destructive changes)      |
| `/api-review-architecture` | Review changed `apps/api/**` files against 13 architecture rules                                     |

## Flutter (`apps/mobile`) — Riverpod + Dio + fpdart

| Skill                         | Purpose                                                                                 |
| ----------------------------- | --------------------------------------------------------------------------------------- |
| `/mobile-new-feature`         | Bootstrap a feature folder (3-layer: domain/data/presentation, Reso Coder convention)   |
| `/mobile-new-usecase`         | Add a use case implementing `UseCase<T, Params>` returning `Future<Either<Failure, T>>` |
| `/mobile-new-page`            | Add a `ConsumerWidget` page; `--stateful` adds StateNotifier controller + sealed state  |
| `/mobile-review-architecture` | Review changed `apps/mobile/lib/**` files against Flutter rules                         |

## Cross-stack — tooling, CI, configs

| Skill                      | Purpose                                                                                                                                                                 |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/repo-review-consistency` | Flag drift between SOT and copies (Node/Flutter/Dart/Melos versions), CI ↔ local script parity, action SHA pinning, format coverage gaps. **Flags only — never fixes.** |
| `/work-on-issue`           | Orchestrator script for delivering a Linear issue end-to-end via the PM → CEO → EL → SWE(s) → reviewer + qa loop → `/github-pr` workflow. **Orchestrator-only.**        |
| `/learn`                   | Reflect on the current conversation; distill agent-ability + workflow learnings into agent/skill definitions; clean up migrated memory entries. **Orchestrator-only.** |

## Why backend and mobile have different rules

The two stacks have intentionally different layering — see CLAUDE.md → "Why Flutter is 3-layer". In short: backend use cases orchestrate transactions, multiple aggregates, and events; Flutter use cases are thin wrappers around a repository call returning `Either<Failure, T>`. Forcing the same rigor on the client adds noise without benefit.

## Evolving a skill

Edit the relevant `SKILL.md`. The next invocation picks up the change. Don't add skills speculatively — prefer adding a rule to the existing review skill, or codifying a new convention in CLAUDE.md first.
