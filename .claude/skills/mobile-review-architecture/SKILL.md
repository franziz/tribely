---
name: mobile-review-architecture
description: FLUTTER ONLY. Review WIP Dart code for Flutter Clean Architecture (3-layer Reso Coder style) + Riverpod discipline + Tribely mobile conventions. Run on demand via /mobile-review-architecture or after finishing a logical unit of source-file changes. Reports violations only — NEVER suggests fixes, NEVER edits code. Scope is strictly WIP files. Do NOT use for the API — use /api-review-architecture.
---

# /mobile-review-architecture

```
/mobile-review-architecture                    # default: WIP scope (modified + untracked)
/mobile-review-architecture <git-ref>          # changes vs. specific ref
/mobile-review-architecture --staged           # only staged changes
```

**Scope guard:** Reviews Flutter files only. Filters to `apps/mobile/lib/**/*.dart` and `apps/mobile/test/**/*.dart`. If the diff includes backend files, mention them in the footer but recommend `/api-review-architecture`.

## Strict constraints (read first)

These are **non-negotiable**:

- **NEVER suggest fixes**, propose alternatives, write code, recommend refactors, or describe the correct version. The Issue cell states only what is wrong and which rule it violates.
- **NEVER edit any file** — this skill is read-only.
- **NEVER review files outside the WIP set** returned by Step 1. Committed unchanged files are out of scope.
- **NEVER add "no violation, included for completeness" rows** — only flag actual violations.
- **NEVER flag stylistic preferences** that aren't an actual rule violation. If you can't cite a specific rule by name, drop the finding.
- **NEVER fabricate `file:line` citations**. Pin every finding to specific lines.
- **NEVER flag missing tests, missing docs, or commit-message style** — those are different review concerns.
- If multiple distinct violations on the same line, list them as separate rows.
- If no violations in a section, write `No violations found.` instead of an empty table.
- For **judgment rules (Section B)**, the output MUST include the cited Q&A trace. A bare verdict fails the skill's own contract.
- **Section A output is the final table only.** Do NOT narrate self-corrections, "considered then dropped" rows, intermediate reasoning, or duplicated empty tables. If a finding is considered and rejected during review, drop it silently — only the verdict (final table or `No violations found.`) appears in the report. Section B's mandatory Q&A traces are the *only* place reasoning narration belongs in the output.

## Procedure

### 1. Identify the WIP file set

```bash
{ git diff --name-only HEAD; git ls-files --others --exclude-standard; } \
  | grep -E '^apps/mobile/(lib|test)/.*\.dart$' \
  | sort -u
```

When `<git-ref>` is provided, replace `git diff --name-only HEAD` with `git diff --name-only <ref>...HEAD`. When `--staged` is provided, use `git diff --name-only --cached`.

If the resulting list is empty → exit with `✓ No mobile files changed.`

### 2. Classify each WIP file by layer

| Path pattern | Layer |
|---|---|
| `apps/mobile/lib/src/features/<f>/domain/entities/...` | domain (Equatable entities) |
| `apps/mobile/lib/src/features/<f>/domain/repositories/...` | domain (abstract repositories) |
| `apps/mobile/lib/src/features/<f>/domain/usecases/...` | domain (use cases) |
| `apps/mobile/lib/src/features/<f>/data/models/...` | data (JSON models) |
| `apps/mobile/lib/src/features/<f>/data/datasources/...` | data (REST/local sources) |
| `apps/mobile/lib/src/features/<f>/data/repositories/...` | data (concrete repositories) |
| `apps/mobile/lib/src/features/<f>/presentation/pages/...` | presentation (screens) |
| `apps/mobile/lib/src/features/<f>/presentation/widgets/...` | presentation (feature-scoped widgets) |
| `apps/mobile/lib/src/features/<f>/presentation/providers/...` | presentation (Riverpod providers) |
| `apps/mobile/lib/src/features/<f>/presentation/controllers/...` | presentation (Notifier controllers) |
| `apps/mobile/lib/src/features/<f>/presentation/state/...` | presentation (sealed state) |
| `apps/mobile/lib/src/core/...` | core (cross-cutting) |
| `apps/mobile/lib/src/core/router/...` | core (routing) |
| `apps/mobile/lib/src/core/di/service_locator.dart` | wiring |
| `apps/mobile/test/...` | tests |

### 3. Apply Section A — Structural rules

Walk each WIP file. Apply only the rules targeted to the file's layer.

### 4. Apply Section B — Judgment rules

Run the numbered cross-examination for each judgment rule that applies. Cite `file:line` per answer. Show the trace; never assert a verdict bare.

### 5. Output the report

Use the exact format under [Output format](#output-format).

---

## Section A — Structural rules

### A1. domain-purity-mobile

**Targets:** `lib/src/features/<f>/domain/**/*.dart`.

**Check:** No imports from:

- `package:flutter/*`
- `package:dio/*`, `package:shared_preferences/*`, `package:flutter_secure_storage/*`
- `package:flutter_riverpod/*`, `package:get_it/*`, `package:go_router/*`
- The feature's own `data/` or `presentation/`
- Other features' `data/` or `presentation/`

**Allowed:** `package:equatable`, `package:fpdart`, `package:meta`, and core helpers under `core/error/`, `core/usecase/`, `core/util/`.

**Severity:** error.

### A2. usecase-shape

**Targets:** `lib/src/features/<f>/domain/usecases/*.dart`.

**Check:** Class `implements UseCase<T, Params>` (or `UseCase<T, NoParams>`). The `call(Params)` method returns `Future<Either<Failure, T>>`.

**Severity:** error.

### A3. repository-returns-either

**Targets:** abstract methods in `lib/src/features/<f>/domain/repositories/*_repository.dart`.

**Check:** Every method returns `Future<Either<Failure, T>>`. Methods returning raw `T` or that can throw are flagged.

**Severity:** error.

### A4. model-extends-or-converts-to-entity

**Targets:** `lib/src/features/<f>/data/models/*_model.dart`.

**Check:** Model class either extends the corresponding entity OR exposes a `toEntity()` method returning the entity type.

**Severity:** warn.

### A5. repository-impl-catches-dio-exception

**Targets:** `lib/src/features/<f>/data/repositories/*_repository_impl.dart`.

**Check:** Methods catch `DioException` and map to a typed `Failure` (via `_mapDioError` or equivalent). A method that lets `DioException` propagate is flagged.

**Severity:** error.

### A6. page-is-consumer-widget

**Targets:** files under `lib/src/features/<f>/presentation/pages/` (any `*.dart`, but `*_page.dart` is the canonical case). Also `*_sheet.dart` files anywhere that read providers or own controller-coupled behavior.

**Check:** Pages/sheets that hold their own state, dispatch to controllers, or read providers must extend `ConsumerWidget` or `ConsumerStatefulWidget`. Plain `StatelessWidget` / `StatefulWidget` is flagged when the file has provider-reading or controller-dispatching intent (means the file can't read providers ergonomically and the next contributor will refactor it anyway).

**Exception:** purely presentational sub-widgets that don't read providers MAY be plain `StatelessWidget`. The exception is location + intent based, NOT suffix based: a `*_sheet.dart` file that lives under `presentation/widgets/` AND pops its result via `Navigator.pop` (rather than calling a controller or reading a provider) satisfies the exception cleanly — the `_sheet` suffix alone does NOT trigger the primary rule. Location-under-`widgets/` + no-provider intent overrides the suffix.

**Examples that satisfy the exception:**

- `features/events/presentation/widgets/category_sheet.dart` — a single-select picker that pops the chosen value via `Navigator.pop(context, value)`. No provider reads, no controller dispatch. `StatelessWidget` is correct.
- `features/<f>/presentation/widgets/<name>_sheet.dart` — generally, any sheet under `widgets/` whose only effect is "return a value to the caller" can be `StatelessWidget`.

**Examples that trigger the rule (must extend `ConsumerWidget`):**

- `features/<f>/presentation/pages/*_page.dart` — pages are provider-coupled by definition.
- `features/<f>/presentation/pages/*_sheet.dart` — sheets that live alongside pages are page-grade flow surfaces.
- A sheet under `widgets/` that calls `ref.read(controllerProvider).doX()` directly — provider-reading intent forces `ConsumerWidget`.

**Severity:** warn.

### A7. no-business-logic-in-page

**Targets:** `lib/src/features/<f>/presentation/pages/*.dart`, `presentation/widgets/*.dart`.

**Check:** Pages/widgets must not import `data/datasources/`, `data/repositories/`, or call use cases directly without going through a provider. The flow MUST be page → controller (notifier) → use case (via provider) → repository.

**Severity:** error.

### A8. state-is-sealed

**Targets:** `lib/src/features/<f>/presentation/state/*_state.dart`.

**Check:** State hierarchies declare a `sealed class` parent so `switch` statements on state are exhaustively checked.

**Severity:** warn.

### A9. no-print

**Targets:** all Dart files.

**Check:** No `print(...)` calls. Use `logger` (or `debugPrint` if explicitly framework-debug).

**Severity:** warn.

### A10. no-direct-flutter-import-in-domain

**Targets:** `lib/src/features/<f>/domain/**/*.dart`.

**Check:** Subset of A1, called out separately because it's the most common drift. Domain files must not import `package:flutter/*` (including `material.dart`, `widgets.dart`, `cupertino.dart`, `services.dart`).

**Severity:** error.

### A11. no-cross-feature-data-or-presentation

**Targets:** all files under `lib/src/features/<X>/...`.

**Check:** No imports of `lib/src/features/<Y>/data/...` or `lib/src/features/<Y>/presentation/...` for `X ≠ Y`. Cross-feature use is restricted to the other feature's `domain/`.

**Severity:** error.

### A12. no-inline-class-instantiation-in-call

**Targets:** all files.

**Check:** Forbid inline `someFn(MyParams(...))` and `useCase(Params(...))` patterns. Construct first, name the variable, then pass.

```dart
// ❌
await useCase(VerifyEmailParams(code: code));

// ✓
final params = VerifyEmailParams(code: code);
await useCase(params);
```

**Exceptions:**
- Single-token literals: `const SizedBox(height: 8)`, `const Text('...')`, `Padding(padding: ..., child: ...)` — Flutter widget construction is the language idiom; out of scope.
- `EdgeInsets.all(8)`, `Duration(seconds: 1)` — value-type sugar; out of scope.
- Factory methods: `Pagination.fromQuery(...)`, `Email.create(...)` — preferred pattern.

**Severity:** warn (lower than backend because Flutter idioms blur the line; many widget-tree call sites are unavoidable).

### A13. no-rule-workaround (meta-rule)

**Targets:** all files.

**Check:** Flag patterns that *technically* satisfy A1–A12 while preserving the spirit-of-the-rule problem.

Examples:

- Re-exporting a `dio` type from a domain helper to dodge A1's import check.
- Defining a `Failure` subclass that wraps a `DioException` as `failure.cause` to dodge A5 (the impl still throws underneath).
- Wrapping a use case call directly inside `onPressed: () async { ... }` on a page (instead of going through a controller) to dodge A7.
- Casting a non-sealed state base class as `Object` to dodge A8's exhaustiveness check.
- `// ignore: ...` lints to silence a warning that exposes a violation.

**Severity:** error. Cite which named rule is being dodged.

---

## Section B — Judgment rules

Verdicts:

- **pass** — every question answered cleanly.
- **smell-with-note** — concern surfaced; might be acceptable; flagged for human dispatch.
- **fail** — concrete violation of the rule's intent.

### B1. controller-grain

**Targets:** new or modified `lib/src/features/<f>/presentation/controllers/*_controller.dart`.

For each controller, answer:

1. **What single user-facing flow does this controller drive?** Name it in one sentence using user-facing verbs ("drives the verify-email page submit + resend"). If the sentence needs "and" twice, the controller is doing too many things.
2. **List every state transition the controller produces.** Are they all consequences of the single flow, or is one of them an independent screen-level concern?
3. **Does the controller perform navigation?** Pages should usually navigate via `ref.listen` on the state; controllers should not call `context.go(...)` (no `BuildContext` available, and it couples the controller to routing).
4. **Does the controller hold widget references** (`TextEditingController`, `FocusNode`, `ScaffoldMessengerState`)? If yes, that state belongs in the page's `State`, not the Riverpod notifier.
5. **Is there a `try/catch` swallowing errors silently** instead of mapping to a state branch?

**Verdict:**
- All clean → pass.
- (1) two-AND intent → fail (split into two controllers).
- (3) controller calls `context.go(...)` → fail.
- (4) controller holds widget refs → fail.
- (5) silent swallow → fail.
- (2) reveals an independent concern → smell-with-note.

### B2. state-shape-coherence

**Targets:** new or modified `lib/src/features/<f>/presentation/state/*_state.dart`.

For each state hierarchy, answer:

1. **List every state subclass.** Is there a clear progression Idle → Submitting → (Success | Error)? Or are there leftover states from a prior iteration?
2. **Does every state subclass have the fields it needs to drive the UI** (e.g. `Submitting` needs whatever `Idle` had to render the form in disabled-mode)? Or does the page have to fall back to "if state is Submitting, look at *previous* state" hacks?
3. **Are error states typed** (`failure: Failure` + `bannerMessage: String`) or stringly-typed (`message: String`)?
4. **Is `Equatable` implemented?** Riverpod uses `==` to skip rebuilds; missing `Equatable` causes spurious rebuilds.
5. **Are sub-states like `resendCooldownSeconds` modeled as fields on a base state**, or are they leaked into the page (e.g. the page itself owns a `Timer`)? Sub-state on the base state is centralized; page-owned timers drift.

**Verdict:**
- All clean → pass.
- (4) missing `Equatable` → fail.
- (3) stringly-typed errors → smell-with-note.
- (5) page-owned cross-state timers → smell-with-note.

### B3. usecase-grain-mobile

**Targets:** new or modified `lib/src/features/<f>/domain/usecases/*.dart`.

For each use case, answer:

1. **What does the use case do?** State in one sentence. Mobile use cases are usually thin delegates to the repository — that's expected and not a smell.
2. **Does the use case do *more* than delegate to the repository?** If yes, what additional logic? Common smells: ad-hoc validation that should be in the page or controller, manual retry logic, multi-repository orchestration that should be backend's job.
3. **Does the `Params` class contain only data the user/page provides**, not derived data (e.g. timestamps, ids)? Derived data should be computed in the repository or backend.
4. **Is the use case actually used?** A use case wired into DI but never called is dead code. (This is a structural smell, not a Section A rule because it requires call-graph analysis.)

**Verdict:**
- All clean → pass.
- (2) reveals retry/orchestration logic → smell-with-note (likely belongs server-side; flag).
- (3) Params holds derived data → fail.
- (4) wired but never called → smell-with-note (recently scaffolded? mark as in-progress).

### B4. provider-graph-coherence

**Targets:** new or modified `lib/src/features/<f>/presentation/providers/*.dart`.

For each provider added:

1. **What does this provider expose?** A use case, a controller, or a derived value?
2. **Is the provider's lifetime correct?** `Provider` for stateless wires, `NotifierProvider` for state, `FutureProvider` for one-shot async, `StreamProvider` for streams. Is the choice right for the dependency?
3. **Does the provider depend on `sl<T>()` (`get_it`)?** Use-case + datasource providers MUST go through the service locator (Tribely convention). Controllers DO NOT — they're constructed by Riverpod itself (`ControllerName.new`).
4. **Are providers `final`-declared at top level, not inside a function?** Inline providers are anti-pattern (re-created every build).
5. **Is the provider scoped right?** Family providers when keyed by a parameter (e.g. user id); plain providers otherwise.

**Verdict:**
- All clean → pass.
- (3) controller routed through `get_it` → smell-with-note (controllers should be Riverpod-native).
- (3) use case constructed inline (not via `sl<>`) → fail.
- (4) inline provider → fail.

### B5. routing-coherence

**Targets:** WIP changes to `lib/src/core/router/app_router.dart` and any new `presentation/pages/*.dart` page that needs a route.

For each new route or redirect change, answer:

1. **Is the route's path-name consistent with the page's identity?** `/sign-in` for the SignInPage, etc. (Naming → discoverable URLs.)
2. **What session states allow this route?** Is the `redirect` logic in `app_router.dart` updated to include the new route in the right `isAuthFlow` / `isVerify` / etc. sets?
3. **Does the page take query parameters?** If yes, are they validated / fall back gracefully on missing values?
4. **Does the page itself perform navigation post-success?** Is the navigation in `ref.listen` on a state transition (correct), or fired from inside `onPressed` directly (hides flow)?
5. **Are deep-link / universal-link expectations matched?** If TRI-2 (universal links) hasn't shipped, the page should not assume the URL is reachable from outside the app.

**Verdict:**
- All clean → pass.
- (2) redirect not updated → fail (page is unreachable or wrongly redirected).
- (4) navigation inline in `onPressed` (not in `ref.listen`) → smell-with-note.
- (5) page assumes deep-link reachability without TRI-2 → fail.

---

## Output format

````markdown
## Mobile Architecture Review Report

**Scope:** `<diff-spec>`.

### Files Reviewed
- `apps/mobile/lib/src/features/auth/presentation/pages/reset_password_page.dart`
- `apps/mobile/lib/src/features/auth/presentation/controllers/reset_password_controller.dart`
- ...

### Section A — Structural violations

| # | File | Location | Issue |
|---|------|----------|-------|
| 1 | `apps/mobile/lib/src/features/auth/presentation/controllers/foo_controller.dart` | line 47 (submit) | [A9] print(failure.toString()) — use logger. |
| 2 | `apps/mobile/lib/src/features/widgets/bar.dart` | line 18 (build) | [A7] Direct datasource import — pages must go through controllers. |

### Section B — Judgment findings

#### B1. controller-grain — `reset_password_controller.dart`

1. **Single flow:** drives the reset-password page submit. ✓ single intent.
2. **State transitions:** Idle → Submitting → Success | Error. All consequences of submit. ✓
3. **Navigation:** controller does not call `context.go(...)`. Navigation is in the page via `ref.listen`. ✓
4. **Widget refs:** none. ✓
5. **Try/catch:** error handling via `result.match` → state branch. ✓

**Verdict: pass.**

#### B5. routing-coherence — `app_router.dart`

1. **Route name:** `/reset-password` ↔ `ResetPasswordPage`. ✓
2. **Session states:** `isAuthFlow` updated to include `/reset-password` (`app_router.dart:31`). ✓
3. **Query params:** `email` query parameter, falls through to `null` cleanly. ✓
4. **Post-success navigation:** in `ref.listen` on `ResetPasswordSuccess` (`reset_password_page.dart:86-98`). ✓
5. **Deep-link expectation:** page is reachable only from in-app sheet flow; does not assume universal-link entry. ✓ (TRI-2 unblocked.)

**Verdict: pass.**

### Summary
- Total WIP files reviewed: 14
- Section A violations: 2
- Section B findings: 0 fail / 0 smell-with-note / 5 pass
- Overall: ⚠️ Minor issues
````

### Issue cell rules

- Start with the rule code: `[A7]`, `[B1]`.
- No prescription — describe the violation, not the fix.
- Cite location precisely. `line N (functionName)` is the standard form.

### Verdict legend

| Verdict | Meaning |
|---|---|
| pass | Section A: no violations. Section B: every Q&A clean. |
| smell-with-note | Section B only. Concern surfaced but not necessarily wrong. Caller dispatches. |
| fail | Concrete violation. |
| ✅ Clean | 0 fail across both sections. 0 smells (or smells acknowledged in PR description). |
| ⚠️ Minor issues | Section A warnings only, OR Section B smells only, OR ≤3 Section A errors that are mechanical to fix. |
| ❌ Major issues | Any Section B fail, OR ≥4 Section A errors, OR any A13 (workaround) flag. |

---

## What this skill does NOT check

- **UI/UX correctness.** Whether the page looks right, behaves accessibly, handles dark mode, etc.
- **Performance.** Rebuild storms, expensive `build` methods, unnecessary `setState`, leaked `Timer`s — out of scope (some hints surface in B2, but full perf review needs profiler).
- **Riverpod misuse beyond B4.** Family-vs-plain decisions, `keepAlive`, `autoDispose` patterns — out of scope.
- **i18n coverage.** Hardcoded strings vs. translation keys — out of scope.
- **Test coverage / test quality.** Out of scope.
- **Generated code under `*.freezed.dart`, `*.g.dart`** — never flag (always skip).

If a finding is suspected but doesn't fit a named rule, add a footer note: `Out-of-rule observation: ...` — clearly separated from formal violations.

---

## Coexistence with other skills

- Run **before** any test-quality review skill: structural issues in controllers/state often produce cascading widget-test failures.
- Run **after** scaffolding skills (`/mobile-new-feature`, `/mobile-new-page`, `/mobile-new-usecase`): the scaffolding sets up valid structure; this skill catches drift.
- Backend is a separate review surface — never apply mobile rules to `apps/api/**`.

---

## Why these constraints

Same rationale as the API review skill, mirrored for Flutter:

- **No-fix policy** — keeps authorial control with the user.
- **WIP-only scope** — committed unchanged files are noise the user has already accepted.
- **Sectioned A vs. B** — structural is deterministic, judgment is LLM-bound; the section split makes the variance auditable.
- **Mandatory Q&A traces in Section B** — a verdict without reasoning is indistinguishable from hallucination.
- **A12 is `warn` not `error`** — Flutter widget construction is idiomatically inline (`Padding(padding: ..., child: Text(...))`); applying the backend's strict rule would create endless noise.

---

## Honest about limits

- The skill cannot tell you whether the page *looks* right or *feels* right.
- Section B traces can hallucinate cited lines under load — verify if a verdict feels off.
- Riverpod/Flutter idioms evolve; some rules will need updating as TRI-X issues land. Keep CLAUDE.md as the source of truth; update this skill when the convention changes.
