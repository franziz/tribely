---
name: repo-review-consistency
description: CROSS-STACK. Review repo-wide tooling and CI/local consistency. Flags drift between SOT and copies, CI ↔ local script parity, action SHA pinning, format coverage gaps. Outputs file:line violations with severity. Does NOT auto-fix — flagging only. Run periodically or before opening a PR that touches package.json / pubspec.yaml / .github/**.
---

# /repo-review-consistency

```
/repo-review-consistency                   # default: full repo audit
/repo-review-consistency <path-glob>       # narrow to a subset (e.g. ".github/**")
/repo-review-consistency --staged          # only files in the staged diff
```

**Scope:** cross-stack. Reads root `package.json`, `pubspec.yaml`, `.nvmrc`, `apps/api/package.json`, `apps/mobile/pubspec.yaml`, `.github/workflows/**`, `.github/actions/**`, `.gitignore`, `.prettierignore`. Does NOT review code structure inside `apps/api/src/**` or `apps/mobile/lib/**` — that's `/api-review-architecture` and `/mobile-review-architecture`.

**Critical:** this skill **flags only**. Never apply fixes. Output violations and let the caller decide which to address.

## What this skill does

1. Determines scope (default: full audit; `<glob>` or `--staged` narrows).
2. Loads all relevant config files in parallel.
3. Runs each rule below; for each violation collects file:line, severity, rule-name, fix suggestion, and (when relevant) a citation from CLAUDE.md or repo conventions.
4. Outputs a grouped report.

## The rules

### tool-version-sot-drift

**Check:** For each tool, the version must be named in exactly one canonical source-of-truth file. Other files referencing the same tool must either read from SOT or contain a constraint compatible with SOT — never an independent pin.

| Tool     | SOT                                                                 | Where copies must align                                                                                                                                     |
| -------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Node     | `.nvmrc`                                                            | `package.json` `engines.node` (constraint), `setup-api/action.yml` (must read via `node-version-file: .nvmrc`, not `node-version: 22`)                      |
| Flutter  | `apps/mobile/pubspec.yaml` `environment.flutter` (exact, no quotes) | Root `pubspec.yaml` must match exact, `setup-mobile/action.yml` must read via `flutter-version-file: apps/mobile/pubspec.yaml` (not `flutter-version: 3.x`) |
| Dart SDK | `apps/mobile/pubspec.yaml` `environment.sdk`                        | Root `pubspec.yaml` must match. Constraint must be satisfiable by Dart shipped with the pinned Flutter                                                      |
| Melos    | `apps/mobile/pubspec.yaml` `dev_dependencies.melos`                 | `setup-mobile/action.yml` `dart pub global activate melos X.Y.Z` must use the same exact version                                                            |

**Severity:** error if a hard pin diverges across files; warn if SOT is via constraint when an exact pin exists elsewhere.

### ci-local-script-parity

**Check:** For each step in `.github/workflows/_api.yml` and `_mobile.yml` that runs project commands, the same operation must be reachable from `npm run` or `melos run`. The CI step should _call_ the script, not duplicate its body.

Specifically:

- CI step `npm run --workspace=@tribely/api X` is OK (calls the script).
- CI step `melos run X` is OK.
- CI step that runs `cd apps/X && <bare command>` is **flagged** if `<bare command>` has an existing or trivially addable Melos/npm equivalent.

**Severity:** error.

### direct-command-bypass

**Check:** Both CI and root `package.json` scripts must NOT use `cd apps/mobile && <flutter|dart> X` for operations that compose across packages.

Composing operations (forbidden as direct):

- `dart run build_runner` → must use `melos run build_runner`
- `flutter analyze` → must use `melos run analyze`
- `flutter test` (with or without `--coverage`) → must use `melos run test` / `melos run test:coverage`
- `dart format` → must use `melos run format` / `melos run format:check`

Single-app operations (allowed as direct):

- `flutter run`, `flutter build apk`, `flutter build ios`, `flutter devices`, `flutter pub get` (when scoped to one package), single-test invocations like `flutter test path/to/foo_test.dart`.

**Severity:** error for composing operations; OK for single-app.

### coverage-variant-parity

**Check:** Any CI step using `--coverage` must call a script (Melos or npm) that exists locally. There MUST be a `:coverage` variant alongside the base script (e.g. both `melos run test` and `melos run test:coverage`).

**Severity:** error.

### action-sha-pinned

**Check:** Every `uses:` line in `.github/workflows/**` and `.github/actions/**` must reference a 40-char SHA, with a trailing comment `# vX.Y.Z` indicating the human-readable version.

Forbidden: `uses: actions/checkout@v6` (bare tag — Dependabot won't alert on vulnerabilities for these per GitHub docs).
Required: `uses: actions/checkout@1af3b93b6815bc44a9784bd300feb67ff0d1eeb3 # v6.0.0`.

Local `uses: ./.github/actions/<name>` (composite-action references in same repo) are exempt — no SHA needed.

**Severity:** error.

### action-version-comment-format

**Check:** The trailing comment after a SHA-pinned action must be in `# vX.Y.Z` form (or `# vX.Y` / `# vX` for major-only releases). Free-form comments like `# latest as of 2026-01` are flagged.

**Severity:** warn.

### dependency-duplication

**Check:** A devDependency declared in both root `package.json` and `apps/api/package.json` is flagged unless there's an explicit reason for workspace-local pinning.

Common offenders to check: `prettier`, `typescript`, `eslint`.

**Severity:** warn.

### path-filter-completeness

**Check:** Each `dorny/paths-filter` filter in `.github/workflows/ci.yml` must include every file that genuinely affects that domain.

Required for `api:`:

- `apps/api/**`, `package.json`, `package-lock.json`, `tsconfig.base.json`, `.nvmrc`
- `.github/actions/setup-api/**`, `.github/workflows/ci.yml`, `.github/workflows/_api.yml`

Required for `mobile:`:

- `apps/mobile/**`, `pubspec.yaml`, `pubspec.lock`
- `.github/actions/setup-mobile/**`, `.github/workflows/ci.yml`, `.github/workflows/_mobile.yml`

**Severity:** error if a required path is missing; warn if there's an extra path that doesn't belong.

### format-coverage

**Check:** Every file under version control (excluding `.gitignore`-d, `.prettierignore`-d, generated files, vendored code) should be covered by exactly one formatter — Prettier (TS/JS/JSON/MD) or `dart format` (Dart). Files with no coverage are flagged.

Configuration coverage to verify:

- Root `npm run format:check` glob covers all source extensions in apps/api, root configs, READMEs.
- `melos run format:check` covers all `.dart` under `apps/mobile/**`.
- Workflow YAMLs (`.github/workflows/*.yml`) — intentionally excluded; flag if INCLUDED (Prettier can break GitHub Actions YAML).
- Pubspec YAMLs — intentionally excluded.

**Severity:** warn for uncovered files; error for files Prettier shouldn't touch but is being asked to.

### melos-script-shape

**Check:** Melos scripts (in root `pubspec.yaml`'s `melos.scripts`) must follow these rules:

- A script with an `exec:` block providing options (e.g. `concurrency`, `orderDependents`) MUST NOT prefix its `run:` with `melos exec --` — Melos auto-wraps; doubling errors out.
- A script without an `exec:` block IS allowed to prefix `run:` with `melos exec --`.

**Severity:** error.

### workflow-permissions-default-deny

**Check:**

- Workflow-level `permissions: {}` is required at the top of every workflow file (default-deny).
- Every job in the workflow must explicitly declare `permissions:` for what it needs.
- A job calling a reusable workflow via `uses: ./.github/workflows/_X.yml` must declare `permissions:` granting at least what the callee requests (caller is the ceiling).

**Severity:** error if `permissions: {}` is missing at workflow level; error if a `uses:` job lacks the permissions its callee requires.

### node-version-pairing-validity

**Check:** `.nvmrc` major must satisfy `package.json` `engines.node` constraint AND every dependency's runtime requirement.

For Tribely specifically, Prisma 7 requires Node `>=20.19 / >=22.12 / >=24.0`. The pinned Node must satisfy this floor.

**Severity:** error.

### flutter-dart-pairing-validity

**Check:** The Flutter version pinned in `apps/mobile/pubspec.yaml` `environment.flutter` must ship a Dart SDK that satisfies:

- `environment.sdk` constraint in the same pubspec
- Every dev_dependency's SDK requirement (e.g. Melos 7.5+ requires Dart 3.9+)

Reference table (update when Flutter releases new versions):

- Flutter 3.27.x ships Dart 3.6.x
- Flutter 3.32.x ships Dart 3.8.x
- Flutter 3.35.x ships Dart 3.9.x
- Flutter 3.41.x ships Dart 3.11.x

**Severity:** error.

### prisma-config-env-discipline

**Check:** Anywhere `prisma generate` is invoked without a real database (CI codegen step), a placeholder `DATABASE_URL` must be set as an env var. Prisma 7's `prisma.config.ts` calls `env('DATABASE_URL')` and refuses to load otherwise.

**Severity:** error if invocation lacks env grant.

## Output format

Group violations by severity (error first, then warn), sort by file path within each group. Each entry:

```
[error] <rule-name>
  <file>:<line>  <one-line description>
  Fix:  <concrete suggestion>
  Why:  <citation or explanation>
```

End with: `✓ <N> files reviewed. <M> violations across <K> rules.`

If clean: `✓ No consistency violations found across <N> files.`

## Be honest about limits

The skill catches drift in declared config and scripts. It does NOT catch:

- Logic bugs in workflows (only structural / naming issues).
- Whether a Flutter version actually exists on subosito's mirror.
- Whether SHA-pinned actions are actually the latest stable (Dependabot does this).
- Code-level inconsistencies inside `apps/*/` source files.

Note in footer: `Note: this review checks tooling, scripts, and CI configs. Code structure and architecture need /api-review-architecture or /mobile-review-architecture.`

## Important

This skill **flags, never fixes**. Do not apply edits. Output the report and stop. The caller decides which violations to address and in what order.
