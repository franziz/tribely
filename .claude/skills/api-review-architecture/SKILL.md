---
name: api-review-architecture
description: BACKEND ONLY. Review WIP code for SOLID/DDD/Hexagonal/Clean Arch compliance and Tribely-specific architecture rules. Run on demand via /api-review-architecture or after finishing a logical unit of source-file changes. Reports violations only — NEVER suggests fixes, NEVER edits code. Scope is strictly WIP files; committed/unchanged files are out of scope unless explicitly requested via <git-ref>.
---

# /api-review-architecture

```
/api-review-architecture                    # default: WIP scope (modified + untracked, both staged and unstaged)
/api-review-architecture <git-ref>          # changes vs. specific ref (e.g. HEAD~3, origin/main)
/api-review-architecture --staged           # only staged changes
```

**Scope guard:** Reviews backend files only. Filters to `apps/api/src/**/*.ts` (and migrations under `apps/api/prisma/migrations/**` when relevant). If the diff includes mobile files, mention them in the footer but do NOT apply backend rules to them — recommend `/mobile-review-architecture`.

## Strict constraints (read first)

These are **non-negotiable**:

- **NEVER suggest fixes**, propose alternatives, write code, recommend refactors, or describe the correct version. The Issue cell states only what is wrong and which rule it violates. Decoupling observation from prescription forces the user (or the next implementation step) to decide between "fix here" vs. "acceptable for the WIP iteration".
- **NEVER edit any file** — this skill is read-only.
- **NEVER review files outside the WIP set** returned by Step 1. Committed unchanged files are out of scope even if a violation is spotted while reading them for context.
- **NEVER add "no violation, included for completeness" rows** — only flag actual violations.
- **NEVER flag stylistic preferences** that aren't an actual rule violation. If you can't cite a specific rule by name, drop the finding.
- **NEVER fabricate `file:line` citations**. If you can't pin a violation to specific lines, do not include it.
- **NEVER flag missing tests, missing docs, or commit-message style** — those are different review concerns.
- If multiple distinct violations on the same line, list them as separate rows.
- If no violations in a section, write `No violations found.` instead of an empty table.
- For **judgment rules (Section B)**, the output MUST include the cited Q&A trace, not just the verdict. A verdict without reasoning fails the skill's own contract.
- **Section A output is the final table only.** Do NOT narrate self-corrections, "considered then dropped" rows, intermediate reasoning, or duplicated empty tables. If a finding is considered and rejected during review, drop it silently — only the verdict (final table or `No violations found.`) appears in the report. Section B's mandatory Q&A traces are the *only* place reasoning narration belongs in the output.

## Procedure

### 1. Identify the WIP file set

`git status --short` collapses untracked directories into a single entry, so combine modified + individually-listed untracked sources:

```bash
{ git diff --name-only HEAD; git ls-files --others --exclude-standard; } \
  | grep -E '^apps/api/(src/.*\.ts|prisma/migrations/.*\.sql)$' \
  | sort -u
```

When `<git-ref>` is provided, replace `git diff --name-only HEAD` with `git diff --name-only <ref>...HEAD`. When `--staged` is provided, use `git diff --name-only --cached`.

If the resulting list is empty → exit with `✓ No backend files changed.`

### 2. Classify each WIP file by layer

The layer determines which rules apply most heavily. Layer-irrelevant files are skipped silently.

| Path pattern | Layer |
|---|---|
| `apps/api/src/features/<f>/presentation/http/...` | driving (HTTP controllers, routes, Zod schemas) |
| `apps/api/src/features/<f>/presentation/events/...` | driving (event-bus consumers) |
| `apps/api/src/features/<f>/presentation/middleware/...` | driving (feature-specific middleware) |
| `apps/api/src/features/<f>/application/usecases/...` | application (use cases) |
| `apps/api/src/features/<f>/application/dto/...` | application (DTOs) |
| `apps/api/src/features/<f>/domain/entities/...` | domain (aggregate roots) |
| `apps/api/src/features/<f>/domain/value-objects/...` | domain (VOs) |
| `apps/api/src/features/<f>/domain/events/...` | domain (events) |
| `apps/api/src/features/<f>/domain/repositories/...` | domain (repository interfaces) |
| `apps/api/src/features/<f>/domain/ports/...` | domain (outbound ports) |
| `apps/api/src/features/<f>/domain/services/...` | domain (stateless cross-aggregate services) |
| `apps/api/src/features/<f>/infrastructure/persistence/...` | driven (Prisma repos + mappers) |
| `apps/api/src/features/<f>/infrastructure/adapters/...` | driven (concrete adapters) |
| `apps/api/src/core/...` | core (cross-cutting infra) |
| `apps/api/src/app.ts`, `apps/api/src/core/di/container.ts` | wiring |
| `apps/api/prisma/migrations/...` | migration |

### 3. Apply Section A — Structural rules

Walk every WIP file. For each rule, only apply it to files in the layers it targets. When a rule has an exception clause, apply it; an exception that fires is *not* a violation.

### 4. Apply Section B — Judgment rules

For each judgment rule that applies to the WIP set, run the numbered cross-examination. Cite `file:line` per answer. Derive the verdict from the cited answers — never assert a verdict without showing the trace.

### 5. Output the report

Use the exact structure under [Output format](#output-format).

---

## Section A — Structural rules

Each rule has: **Targets** (which layers), **Check**, optional **Exceptions**, **Severity**.

### A1. domain-purity

**Targets:** `domain/**/*.ts`.

**Check:** No imports from `@prisma/client`, `hono`, `@hono/*`, `dio`, `argon2`, `jose`, `bcrypt`, `nodemailer`, `axios`, `node:fs`, `node:net`, `node:http`, or any sibling feature's `infrastructure/`/`presentation/`/`application/` paths.

**Allowed core imports from domain:** `@/core/domain/*`, `@/core/errors/*`, `@/core/events/domain-event`, `@/core/events/event-publisher.port`, `@/core/db/unit-of-work.port`, `@/core/observability/logger.port`. (Other ports under `core/*.port.ts` are allowed — they're outbound interfaces, not infrastructure.)

**Exception:** cross-feature imports of *another feature's `domain/`* are allowed (interfaces only). Cross-feature `application/`/`infrastructure/`/`presentation/` imports are not.

**Severity:** error.

### A2. usecase-location

**Targets:** files matching `*.usecase.ts`.

**Check:** Must live under `apps/api/src/features/*/application/usecases/`. Flag any in `domain/`, `presentation/`, or elsewhere.

**Severity:** error.

### A3. entity-extends-aggregate-root

**Targets:** `domain/entities/*.ts`.

**Check:** The primary class declared in the file must `extends AggregateRoot` (from `@/core/domain/aggregate-root`).

**Exception:** files exporting only types/interfaces (no class) are not entities and not flagged.

**Severity:** error for aggregate roots; warn for ambiguous helpers.

### A4. value-object-private-constructor

**Targets:** `domain/value-objects/*.ts`.

**Check:** Classes must have a `private constructor` and a static factory (`create`, `fromHash`, `fromQuery`, etc.). Direct `new <VO>(...)` outside the file is forbidden.

**Exception:** state-machine VOs that compose lifecycle (e.g. `OneTimeCodeLifecycle`) MAY expose factory methods named differently from `create` (e.g. `create` + `rehydrate`) as long as the constructor is private.

**Severity:** error.

### A5. event-naming

**Targets:** `domain/events/*.event.ts`.

**Check:** File must export `const X = '<feature>.<verbPastTense>' as const`. Past-tense verb required (`emailVerificationConsumed`, not `consumeEmailVerification`).

**Severity:** error.

### A6. repository-tx-context

**Targets:** `domain/repositories/*.repository.ts` (interface) + `infrastructure/persistence/*.prisma-repository.ts` (impl).

**Check:**
- Interface: every method declares optional `ctx?: TxContext`.
- Impl: every method accepts `ctx?: TxContext` and routes through `ctx ? unwrapTx(ctx) : this.db`.

**Workaround flag:** an impl that accepts `ctx?` but ignores it (always uses `this.db`) is a Rule A17 (no-rule-workaround) violation, not a A6 pass.

**Severity:** error.

### A7. use-case-publishes-via-uow

**Targets:** `application/usecases/*.usecase.ts`.

**Check:** Every call to `this.events.publish(` must be inside a `this.unitOfWork.run(async (ctx) => ...)` block, and the first argument to `publish` must be that block's `ctx`.

**Severity:** error.

### A8. no-direct-prisma-in-application-or-domain

**Targets:** `application/**`, `domain/**`.

**Check:** No imports of `@prisma/client`, the `Prisma` namespace, `@/core/db/prisma`, or `@/core/db/prisma-unit-of-work`. Only `@/core/db/unit-of-work.port` is allowed.

**Severity:** error.

### A9. entity-not-anemic

**Targets:** `domain/entities/*.ts`.

**Check:** Class has at least one method beyond getters/setters and the constructor.

**Severity:** warn.

### A10. mapper-uses-rehydrate

**Targets:** `infrastructure/persistence/*.mapper.ts`.

**Check:** Maps DB rows to entities via `<Entity>.rehydrate({...})`, never `new <Entity>(...)`.

**Severity:** error.

### A11. no-cross-feature-infra-import

**Targets:** all files under `apps/api/src/features/<X>/...`.

**Check:** No imports from `apps/api/src/features/<Y>/infrastructure/...` or `apps/api/src/features/<Y>/presentation/...` for `X ≠ Y`. Cross-feature imports are restricted to:
- `domain/` (interfaces — repository ports, domain services, value-object types)
- `application/dto/` (result/input DTOs)
- `application/ports/` (structural ports that abstract over a sibling-feature application service — e.g., `UserCapabilitiesPort` consumed by `events/`)
- `application/usecases/` (when explicitly composed via DI)

`application/ports/` differs from `domain/ports/`: domain ports describe outbound dependencies the domain itself needs (Clock, Mailer, PasswordHasher); application ports describe the *structural shape* of another feature's application service that the consuming feature treats as a dependency. Both layers can host ports legitimately — domain for infra-shaped collaborators, application for use-case-shaped ones.

**Severity:** error.

### A12. subscriber-location

**Targets:** files defining or registering event consumers.

**Check:** Consumer factories (`(): Consumer<E> => ({ name, topic, handle })`) and `registry.register(...)` calls must live under `presentation/events/`. Acceptable locations: `presentation/events/<verb-on-event>.consumer.ts` for consumers, `presentation/events/index.ts` for the register fn.

**Workaround flag:** wrapping `registry.register` inside a helper imported from `application/` to dodge the location rule is a Rule A17 violation.

**Severity:** error in `application/`/`domain/`/`infrastructure/`; warn for misplaced consumer files.

### A13. driving-adapter-location

**Targets:** `core/middleware/*.ts`.

**Check:** Middleware in `core/middleware/` must NOT import from `@/features/<X>/application/**` or `@/features/<X>/infrastructure/**`. Feature-specific middleware belongs at `apps/api/src/features/<X>/presentation/middleware/`.

**Exception:** cross-cutting middleware that knows about no specific feature (CORS, request-context, error-handler, rate-limit, require-auth, audit-http) stays in `core/middleware/`.

**Severity:** error.

### A14. port-naming

**Targets:** `domain/ports/*.ts`, `core/**/*.port.ts`.

**Check:** Files must end in `.port.ts`. Interface name should match the file (e.g. `password-hasher.port.ts` exports `PasswordHasher`).

**Severity:** warn.

### A15. no-inline-class-instantiation-in-call

**Targets:** all files.

**Check:** Forbid `<expr>.<fn>(new <ClassName>(...))` and `<fn>(new <ClassName>(...), ...)` for project-defined classes. Construct first, name the variable, then pass.

```ts
// ❌
this.repo.save(new User({ id, email }));
this.events.publish(ctx, new UserRegistered({ ... }));

// ✓
const user = User.register({ id, email, ... });
await this.repo.save(user);
```

**Exceptions:**
- Primitives + framework types: `new Date()`, `new Map()`, `new Set()`, `new Hono()`, `new Error('msg')`.
- Factory-method calls (`User.register(...)`, `Email.create(...)`, `HashedPassword.fromHash(...)`) — these are not `new` and are explicitly the preferred pattern.
- Statement-level construction (`const x = new X(...)`) — fine.

**Why:** inline `new` hides the construction site, makes the value unobservable in debuggers, and frustrates `pullEvents()` patterns where the constructed aggregate must be referenced again *after* the call.

**Severity:** error.

### A16. service-returns-model-only

**Targets:** `application/usecases/*.usecase.ts`, `domain/services/*.ts`.

**Check:** When a use case or domain service returns a model (entity / aggregate / value object), it must return that model directly OR a named DTO defined in `application/dto/*.ts`. Inline object literals like `Promise<{ user: User; tokenIssued: string }>` are forbidden.

```ts
// ❌
async execute(input): Promise<{ user: User; revoked: number }> { ... }

// ✓
async execute(input): Promise<User> { ... }

// ✓ (DTO defined in application/dto/auth-result.ts)
async execute(input): Promise<IssuedAuthSession> { ... }
```

**Workaround flag:** declaring `interface FooResult { ... }` *inside* the use case file (instead of `application/dto/`) to satisfy the named-DTO clause is a Rule A17 violation. Named DTOs live in `application/dto/`.

**Allowed without DTO:** `Promise<void>`, `Promise<number>` (e.g. count), `Promise<string>` (e.g. id-only return).

**Severity:** error.

### A17. no-rule-workaround (meta-rule)

**Targets:** all files.

**Check:** Flag patterns that *technically* satisfy the literal text of a named rule (A1–A16) while preserving the spirit-of-the-rule problem.

Examples to look for:

- Returning `{ model, ...everythingElse }` after A16 was flagged (workaround: type-checks pass, intent is the same).
- Inlining `new User({...})` inside `repo.save({ ...new User({...}), audit: 'note' })` (nested A15 violation).
- Naming a forbidden import via `import * as anything from '...'` to dodge A1's import check (alias-bypass).
- Declaring `ctx?: TxContext` on a repo method that always uses `this.db` (false A6 compliance).
- Re-exporting feature-specific middleware from `core/middleware/` to dodge A13 (indirection laundering).
- `// eslint-disable-next-line` style suppressions to silence type-checks that would expose a violation.
- Defining a result-DTO type inside the use case file instead of `application/dto/` to dodge A16 (location-laundering).

The reviewer's job is to catch *intent*, not just literal regex matches. When in doubt, flag for human judgement.

**Severity:** error. Cite which named rule the pattern is dodging.

---

## Section B — Judgment rules

Judgment rules answer "does this design make sense?" via numbered cross-examination. The output **must** include the cited Q&A trace; a bare verdict is not acceptable.

Each judgment rule resolves to one of three verdicts:

- **pass** — every question answered cleanly; no smell.
- **smell-with-note** — one or more answers reveal a concern that *might* be acceptable; documented for human judgement. Smells do not block; they're flagged for the user to dispatch.
- **fail** — at least one answer reveals a concrete violation of the rule's intent.

### B1. aggregate-boundary-coherence

**Targets:** new or modified aggregates under `domain/entities/*.ts`.

For each aggregate touched, answer:

1. **What invariants does this aggregate enforce?** List them by reading every state-changing method. Cite `file:line` per invariant.
2. **For each invariant, what data does it inspect?** Is that data inside this aggregate, or does it reach into another aggregate?
3. **Does any method on this aggregate take ANOTHER aggregate as a parameter and modify state based on it?** If yes, the responsibility belongs to a domain service or use case orchestration — not the aggregate.
4. **Is the persistence owned by exactly one repository?** No other feature writes to this aggregate's table.
5. **Are multiple aggregates committed in one transaction by some use case?** If yes, classify: (a) shared invariant — they should be one aggregate; (b) process atomicity — independent invariants but joint commit is a correctness requirement.

**Verdict derivation:**
- All five clean → pass.
- (5) is process atomicity AND the use case documents the rationale (in a comment or DTO name) → pass.
- (5) is process atomicity AND the use case does *not* document the rationale → smell-with-note.
- (3) reveals a cross-aggregate parameter → fail.
- (4) reveals shared persistence ownership across features → fail.

### B2. usecase-grain

**Targets:** new or modified use cases under `application/usecases/*.usecase.ts`.

For each use case, answer:

1. **State the use case's intent in one sentence using domain verbs.** If the sentence needs "and" twice, the use case is doing too many things.
2. **List every state mutation it triggers** (every `repo.save(...)` and `events.publish(...)`). Are all mutations consequences of the single intent, or is one of them an independent business decision?
3. **Could any branch of the logic be removed and the intent still hold?** If yes, that branch belongs in a separate use case or a downstream consumer.
4. **Does `execute()` take boolean/enum parameters that pick between behaviors?** Each `if (mode === ...)` branch is usually a separate use case in disguise.
5. **Is there a `try/catch` *inside* the unit-of-work block** that swallows specific failures? If yes — was that recovery a deliberate domain decision, or implicit "make tests pass"?

**Verdict:**
- All clean → pass.
- (2) reveals an independent business decision living inline → smell-with-note (caller can justify, or it should move to a consumer).
- (3) reveals removable branches without breaking intent → fail.
- (4) reveals modal parameters → fail.

### B3. domain-event-grain

**Targets:** new events under `domain/events/*.event.ts` AND `aggregate.record(...)` call sites.

For each new event, answer:

1. **Is the event named for what happened, not what should happen next?** "`OrderShipped`" ✓; "`SendShipmentEmail`" ✗ — that's a command in disguise.
2. **Does the payload contain the *facts* of what happened, not the inputs that triggered it?** A `userRegistered` payload should contain `userId`, `email`, `registeredAt` — not the raw HTTP request body.
3. **Could two different consumers care about this event for different reasons?** If only one consumer ever will, the event might be a covert RPC. Imagine the second consumer; if you can't, it's a smell.
4. **Is the grain right?** Too coarse: consumers must filter. Too fine: consumers must orchestrate multiple events to act. Sanity check: does the event name read like a fact in the ubiquitous language?
5. **Is the event recorded *inside* the aggregate method that produced the state change**, not synthesized in a use case from raw inputs? Synthesizing events outside the aggregate is a Section A violation surface (the use case is doing the aggregate's job).

**Verdict:**
- All clean → pass.
- (3) reveals a single-consumer event with no plausible second → smell-with-note (it's working today; flag for review).
- (1) reveals a command-in-disguise → fail.
- (5) reveals events synthesized outside the aggregate → fail.

### B4. transactional-consistency-rationale

**Targets:** use cases that call `repo.save(...)` on more than one aggregate type inside a single `unitOfWork.run(...)` block.

For each such use case, answer:

1. **Which aggregates are committed together?** List them with `file:line`.
2. **For each aggregate, list its independent invariants.** Do any of these invariants reach across aggregates?
3. **Is the joint commit motivated by a shared invariant** (the aggregates form one consistency boundary and should arguably be one aggregate), or **by process atomicity** (independent invariants, but a partial commit would leave the system in a broken state)?
4. **If process atomicity, what specific failure does the joint commit prevent?** Document the failure scenario.
5. **Could the consistency requirement be enforced by an event-driven reaction instead of a joint commit** (e.g. emit `auth.passwordReset`, have a `RevokeRefreshTokensOnPasswordReset` consumer)? Pros vs. cons:
   - Joint-commit pro: stronger atomicity guarantee. Con: couples the use case to side-effects.
   - Event-driven pro: decouples the side-effect, allows fan-out. Con: window where new password is in effect but old sessions still alive (until consumer fires).

**Verdict:**
- (3) is shared invariant → fail (the aggregates are mis-modeled — should merge).
- (3) is process atomicity AND (4) is documented → pass.
- (3) is process atomicity AND (4) is undocumented → smell-with-note.
- (5) reveals the joint commit is for convenience rather than correctness → smell-with-note (event-driven would be cleaner; flag for human dispatch).

### B5. dependency-direction-semantic

**Targets:** all WIP files. Goes beyond Rule A1 (which is import-graph-level).

For each domain port and each use case that uses one, answer:

1. **What does the port abstract over?** Name the domain concept (e.g. "issue an opaque short code"), not the technology (e.g. "talk to the SHA-256 library").
2. **Does the port's signature leak infrastructure shapes?** Examples:
   - `Logger.info(payload: pino.Bindings, msg: string)` — leaks Pino. ✗
   - `Logger.info(payload: Record<string, unknown>, msg: string)` — abstract. ✓
   - `EmailSender.send(to: string, html: string)` — leaks "html is the format", forces every adapter to render HTML even when the channel is logging-stub. Maybe ✗ depending on context.
3. **Does the port's *return type* leak infrastructure?** A repo returning `PrismaPromise` does. A repo returning `Promise<Aggregate | null>` doesn't.
4. **If the adapter were swapped for a different transport** (Postgres → DynamoDB, Pino → OpenTelemetry, Resend → SES), would the port shape still make sense? If not, it's an infrastructure interface in domain clothing.

**Verdict:**
- All clean → pass.
- (2) or (3) leaks infrastructure shapes → smell-with-note (might be deliberate for now; flag).
- (4) reveals the port only makes sense for one specific adapter → fail (the abstraction is fake).

---

## Output format

Group violations by section. Within each section, sort by file path. Use this **exact** structure:

````markdown
## Architecture Review Report

**Scope:** `<diff-spec>` (e.g. `WIP files (modified + untracked)`, or `main...HEAD`).

### Files Reviewed
- `apps/api/src/features/auth/application/usecases/reset-password.usecase.ts`
- `apps/api/src/features/auth/domain/entities/password-reset-token.ts`
- ...

### Section A — Structural violations

| # | File | Location | Issue |
|---|------|----------|-------|
| 1 | `apps/api/src/features/auth/application/usecases/foo.usecase.ts` | line 42 (execute) | [A7] events.publish called outside unitOfWork.run block. |
| 2 | `apps/api/src/features/auth/domain/entities/widget.ts` | line 18 (constructor) | [A3] class Widget does not extends AggregateRoot. |

### Section B — Judgment findings

#### B1. aggregate-boundary-coherence — `password-reset-token.ts`

1. **Invariants:** code matches stored hash (`password-reset-token.ts:115`); max-5-attempts (`one-time-code-lifecycle.ts:122`); single-use (`...:96-105`); expiry (`...:83-85`); no-consume-after-invalidation (`...:98-100`).
2. **Data inspected:** all five invariants inspect only fields inside the aggregate + composed `OneTimeCodeLifecycle` VO. No cross-aggregate reach.
3. **Cross-aggregate parameters:** none.
4. **Persistence ownership:** only `PasswordResetTokenRepository`.
5. **Multi-aggregate transactions:** `ResetPasswordUseCase` commits PasswordResetToken + Credential + RefreshToken[] together. Process atomicity (no shared invariant). Rationale documented in use case docstring (`reset-password.usecase.ts:30-40`).

**Verdict: pass.**

#### B2. usecase-grain — `reset-password.usecase.ts`

[…similar Q&A trace…]

**Verdict: smell-with-note** — see Q3.

### Summary

- Total WIP files reviewed: 14
- Section A violations: 2
- Section B findings: 0 fail / 1 smell-with-note / 4 pass
- Overall: ⚠️ Minor issues
````

### Issue cell rules

- **Start with the rule code in brackets:** `[A7]`, `[B3]`.
- **No prescription.** Describe what is wrong, not how to fix it.
- **Cite location precisely.** `line N`, `lines N-M`, `lines N, P, Q (functionName)`. The location must include the containing function/method/class when applicable. `line 42 (execute)` is valid; `line 42` alone is acceptable only when the line is at module top-level (e.g. an import).

### Verdict legend

| Verdict | Meaning |
|---|---|
| pass | Section A: no violations. Section B: every Q&A clean. |
| smell-with-note | Section B only. Concern surfaced but not necessarily wrong. Caller dispatches. |
| fail | Concrete violation. |
| ✅ Clean | 0 fail across both sections. 0 smells (or smells acknowledged in PR description). |
| ⚠️ Minor issues | Section A warnings only, OR Section B smells only, OR ≤3 Section A errors that are mechanical to fix. |
| ❌ Major issues | Any Section B fail, OR ≥4 Section A errors, OR any A17 (workaround) flag. |

---

## What this skill does NOT check

- **Wrong domain modeling** beyond what B1 catches. Whether the bounded context is the right shape, whether the ubiquitous language is consistent across the codebase, whether the domain expert would recognize the verbs — these still need a human.
- **Use cases that orchestrate too much.** B2 catches "intent has two ANDs"; it doesn't catch "this 200-line use case has been growing for six months and nobody noticed".
- **Performance.** No N+1 detection, no query-fanout review, no transaction-duration review.
- **Security correctness.** Enumeration leaks, timing attacks, secret-in-log review — out of scope.
- **API contract drift.** Breaking changes to HTTP bodies / response shapes — out of scope.
- **Test coverage / test quality.** Out of scope.

If a finding is suspected but doesn't fit a named rule, add a footer note: `Out-of-rule observation: ...` — clearly separated from the formal violations.

---

## Coexistence with other skills

- Run **before** any test-quality review skill: structural issues (e.g. A6 / A7 / B1 fail) often manifest as cascading test failures that a test reviewer would mis-classify as regressions.
- Run **after** scaffolding skills (`/api-new-feature`, `/api-new-usecase`, etc.): the scaffolding sets up valid structure; this skill catches drift.
- Run **before** `/repo-review-consistency`: tooling/CI consistency is downstream of architecture correctness.
- Mobile is a separate review surface — never apply backend rules to `apps/mobile/**`.

---

## Why these constraints

- **No-fix policy** — pairing observation with prescription concentrates authorial control in the reviewer rather than the user. Keeping the report observation-only forces the user (or the next implementation step) to decide between "fix here" vs. "this is acceptable for the WIP iteration".
- **WIP-only scope** — reviewing committed unchanged files would produce noise the user has already accepted (or chosen to defer). The WIP boundary is the user's contract surface for this turn.
- **Sectioned A vs. B** — structural rules are deterministic and should produce the same output for the same diff every run. Judgment rules are LLM-bound and may produce different smells across runs; isolating them in Section B with mandatory Q&A traces makes the variance auditable.
- **Mandatory Q&A traces in Section B** — a verdict without reasoning is indistinguishable from hallucination. Forcing the trace makes the judgment reproducible-enough to argue with.
- **Strict rule list** — these rules are extracted from real Tribely incidents and CLAUDE.md. They override any general best-practice the LLM might import from training data.

---

## Honest about limits

The skill is rigorous about what it claims to check. It does not:

- Replace human design review for novel architectural decisions.
- Catch hallucinations in its own Section B traces — verify cited lines if a verdict feels off.
- Adapt to local exceptions outside the documented Exception clauses. If your team has decided "we don't enforce A14 in this feature" — document that decision in CLAUDE.md so the skill can read it; otherwise findings will keep firing.

If a Section B verdict is contested, the cited Q&A trace is the artifact to argue with — not the verdict itself.
