---
name: api-review-architecture
description: BACKEND ONLY. Review changed apps/api/** files against the Clean Arch + DDD + Hexagonal rules in CLAUDE.md. Outputs file:line violations with severity and fix suggestions. Run before commit / PR. Do NOT use for Flutter — use /mobile-review-architecture.
---

# /api-review-architecture

```
/api-review-architecture                   # default: changes vs. main
/api-review-architecture <git-ref>         # changes vs. specific ref (e.g. HEAD~3, origin/main)
/api-review-architecture --staged          # only staged changes
```

**Scope guard:** Reviews backend files only. Filters to `apps/api/src/**/*.ts`. If the diff includes mobile files, mention them in the report's footer but do NOT apply backend rules to them — recommend `/mobile-review-architecture`.

## What this skill does

1. Determines the diff scope:
   - No arg → `git diff --name-only main...HEAD` (or `master` if `main` doesn't exist).
   - `<git-ref>` → `git diff --name-only <ref>...HEAD`.
   - `--staged` → `git diff --cached --name-only`.

2. Filters to backend files only: `apps/api/src/**/*.ts`.

3. For each changed file, runs the rule checks below. Reads file content via Read when needed.

4. Outputs a grouped report with file:line, severity, rule name, fix suggestion, and a citation from CLAUDE.md.

5. If no violations, output `✓ No architecture violations found.`

## The rules

Each rule has a name, a check, and a citation. Cite verbatim.

### domain-purity

**Check:** Files under `apps/api/src/features/*/domain/**/*.ts` must NOT import from:

- `@prisma/client`
- `hono` or `@hono/*`
- `dio`, `argon2`, `jose`, `bcrypt`, `nodemailer`, `axios`, `node:fs`, `node:net`, `node:http`
- `@/features/*/data/*`, `@/features/*/infrastructure/*`, `@/features/*/presentation/*`
- Any sibling feature's `infrastructure/` or `presentation/` (cross-feature import is allowed only for `domain/` of another feature)

Allowed core imports from domain: `@/core/domain/*`, `@/core/errors/*`, `@/core/events/domain-event`, `@/core/events/event-publisher.port`, `@/core/db/unit-of-work.port`.

**Severity:** error.

### usecase-location

**Check:** Files matching `*usecase*.ts` MUST live under `apps/api/src/features/*/application/usecases/`. Flag any in `domain/` or elsewhere. **Severity:** error.

### entity-extends-aggregate-root

**Check:** Classes declared in `apps/api/src/features/*/domain/entities/*.ts` MUST `extends AggregateRoot`. **Severity:** error for aggregate roots; warn for ambiguous helpers.

### value-object-private-constructor

**Check:** Classes in `apps/api/src/features/*/domain/value-objects/*.ts` MUST have a private constructor and a static `create` factory. Direct `new <VO>(...)` outside the file is forbidden. **Severity:** error.

### event-naming

**Check:** Files in `apps/api/src/features/*/domain/events/*.event.ts` MUST export a `const X = '<feature>.<verbPastTense>'`. Reject `events.createEvent` (wrong tense). **Severity:** error.

### repository-tx-context

**Check:** Repository INTERFACES under `apps/api/src/features/*/domain/repositories/*.repository.ts` must declare every method with optional `ctx?: TxContext`. Repository IMPLS under `apps/api/src/features/*/infrastructure/persistence/*.prisma-repository.ts` must accept `ctx?: TxContext` and route through `ctx ? unwrapTx(ctx) : this.db`. **Severity:** error for missing ctx; warn for naming.

### use-case-publishes-via-uow

**Check:** Use cases that call `events.publish(` MUST do so inside `unitOfWork.run(async (ctx) =>`. **Severity:** error.

### no-direct-prisma-in-application-or-domain

**Check:** Files under `apps/api/src/features/*/application/**` and `apps/api/src/features/*/domain/**` MUST NOT import `@prisma/client`, `Prisma`, or anything from `@/core/db/prisma` or `@/core/db/prisma-unit-of-work`. Only `@/core/db/unit-of-work.port` is allowed. **Severity:** error.

### entity-not-anemic

**Check:** Classes in `domain/entities/*.ts` should have at least one method beyond getters/setters. **Severity:** warn.

### mapper-uses-rehydrate

**Check:** Files matching `*.mapper.ts` should construct entities via `<Entity>.rehydrate(...)`, not `new <Entity>(...)`. **Severity:** error.

### no-cross-feature-infra-import

**Check:** Files under `apps/api/src/features/<X>/**` must NOT import from `apps/api/src/features/<Y>/infrastructure/**` or `presentation/**` for X ≠ Y. **Severity:** error.

### subscriber-location

**Check:** Event-handler registration must live in `presentation/events/`. Flag any of the following outside that path:

- `bus.subscribe(` (legacy bus, removed in TRI-38 but rule kept for posterity)
- `registry.register(` (post-TRI-38 ConsumerRegistry pattern)
- Direct `Consumer<...>` factory definitions (e.g. files exporting `(): Consumer<E> => ({ name, topic, handle })`)

Acceptable locations: `apps/api/src/features/<feature>/presentation/events/<verb-on-event>.consumer.ts` (the consumer file itself) and `apps/api/src/features/<feature>/presentation/events/index.ts` (the register fn).

**Severity:** error for `registry.register(` in `application/`/`domain/`/`infrastructure/`; warn for misplaced consumer files.

### driving-adapter-location

**Check:** Files in `core/middleware/` must NOT import from `@/features/<X>/application/**` or `@/features/<X>/infrastructure/**`. A middleware that drives a specific feature is a *driving adapter for that feature* and belongs at `apps/api/src/features/<X>/presentation/middleware/`.

Cross-cutting middleware that doesn't know about any specific feature (e.g. CORS, request-context, error-handler, rate-limit, require-auth) stays in `core/middleware/` — fine.

**Severity:** error.

### port-naming

**Check:** Files in `domain/ports/*.ts` should be named `<thing>.port.ts`. **Severity:** warn.

### no-inline-class-instantiation-in-call

**Check:** Forbid `<expr>.<fn>(new <ClassName>(...))` and `<fn>(new <ClassName>(...), ...)` patterns where a class instance is constructed inline as a call argument. Construct first, name it, pass the variable.

```ts
// ❌ rejected
this.repo.save(new User({ id, email, ... }));

// ✓ accepted
const user = new User({ id, email, ... });
await this.repo.save(user);
```

**Why:** inline instantiation hides the construction site, makes the value unobservable in debuggers, and frustrates `pullEvents()` / aggregate-method-recording patterns where the constructed aggregate must be referenced again *after* the call. This is also where dual-call bugs hide ("did I record the event before saving? after?").

Exceptions: pass-through DTOs that exist solely to bridge an interface boundary (e.g. `new Date()` or `new Error('msg')` literals — primitive-shaped, no semantic identity). Apply the rule to *project-defined* classes — anything imported from `@/features/**`, `@/core/domain/**`, `@/core/events/**`.

**Severity:** error.

### service-returns-model-only

**Check:** Use cases (`apps/api/src/features/*/application/usecases/*.usecase.ts`) and domain services that return a model (entity / aggregate / value object) MUST return that model directly — not wrapped in `{ model, ...extra }`, not as a tuple, not as a plain object that bundles the model with metadata.

```ts
// ❌ rejected — bundles model with extras
async execute(input): Promise<{ user: User; tokenIssued: string; deviceLabel: string | null }> { ... }

// ✓ accepted — single return type
async execute(input): Promise<User> { ... }

// ✓ accepted — explicit DTO type *defined as a domain concept*
async execute(input): Promise<IssuedAuthSession> { ... }
//   where IssuedAuthSession is a named DTO in application/dto/ — NOT an inline object literal
```

**Why:** ad-hoc `{ model, ...extra }` returns scatter the contract across call sites, defeat exhaustive use case typing, and tempt callers to destructure-and-mutate rather than treat the model as the source of truth. If the use case genuinely needs to return more than the model, the bundle MUST be a named DTO type defined in `application/dto/<name>.ts` — not an anonymous object literal in the return position.

**Severity:** error for inline object literals; allowed for named DTOs.

### no-rule-workaround

**Meta-rule.** When a use case, controller, or service appears to *technically* satisfy the named rules above by routing around their intent — flag it. Examples to look for:

- Returning `{ model: user, ...everythingElse }` from a use case after `service-returns-model-only` was added (workaround: hides the violation behind a shape that passes type-checks but defeats the purpose).
- Inlining `new User({...})` inside `repo.save({ ...new User({...}), audit: 'note' })` (workaround: nests the forbidden pattern one level deeper).
- Naming a forbidden import via `import * as anything from '...'` to dodge the import-graph check (workaround: alias-bypass).
- Adding a no-op `ctx?: TxContext` parameter to silence `repository-tx-context` while the impl ignores it (workaround: false compliance).
- Putting feature-specific middleware in `core/middleware/` and re-exporting from a feature path so the import-graph check passes (workaround: indirection laundering).

**Severity:** error. Cite which named rule the pattern is trying to dodge. The reviewer's job is to catch *intent*, not just literal regex matches. When in doubt, flag for human judgement rather than silently accepting.

## Output format

Group violations by severity, sort by file path within each group. Each entry: file:line, [rule-name], one-line description, Fix:, Why: + citation. End with `✓ <N> files reviewed. <M> files passed.`

If no violations: `✓ No architecture violations found across <N> files.`

## Be honest about limits

The skill catches structural and import-graph issues. It does NOT catch:

- Wrong domain modeling
- Missing events (a state change that should emit one but doesn't)
- Use cases that orchestrate too much

Note in footer: `Note: this review checks structure and imports only. Domain modeling correctness needs human review.`
