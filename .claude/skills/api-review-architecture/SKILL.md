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

**Check:** `bus.subscribe(` calls should live in `presentation/events/index.ts`. Flag occurrences in `application/`, `domain/`, or `infrastructure/`. **Severity:** warn.

### port-naming

**Check:** Files in `domain/ports/*.ts` should be named `<thing>.port.ts`. **Severity:** warn.

## Output format

Group violations by severity, sort by file path within each group. Each entry: file:line, [rule-name], one-line description, Fix:, Why: + citation. End with `✓ <N> files reviewed. <M> files passed.`

If no violations: `✓ No architecture violations found across <N> files.`

## Be honest about limits

The skill catches structural and import-graph issues. It does NOT catch:
- Wrong domain modeling
- Missing events (a state change that should emit one but doesn't)
- Use cases that orchestrate too much

Note in footer: `Note: this review checks structure and imports only. Domain modeling correctness needs human review.`
