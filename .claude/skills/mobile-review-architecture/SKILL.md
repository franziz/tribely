---
name: mobile-review-architecture
description: FLUTTER ONLY. Review changed apps/mobile/** Dart files against the Flutter Clean Arch 3-layer rules in CLAUDE.md. Outputs file:line violations with severity and fix suggestions. Do NOT use for the API — use /api-review-architecture.
---

# /mobile-review-architecture

```
/mobile-review-architecture                   # default: changes vs. main
/mobile-review-architecture <git-ref>         # changes vs. specific ref
/mobile-review-architecture --staged          # only staged changes
```

**Scope guard:** Reviews Flutter files only. Filters to `apps/mobile/lib/**/*.dart`. If the diff includes backend files, mention them in the report's footer but recommend `/api-review-architecture`.

## What this skill does

1. Determines diff scope (same as the API review skill).
2. Filters to `apps/mobile/lib/**/*.dart`.
3. Runs the rule checks below; outputs a grouped report with file:line, severity, rule, fix suggestion, and citation.
4. If no violations: `✓ No architecture violations found.`

## The rules

### domain-purity-mobile

**Check:** Files under `apps/mobile/lib/src/features/*/domain/**/*.dart` must NOT import:

- `package:flutter/*`
- `package:dio/*`, `package:shared_preferences/*`, `package:flutter_secure_storage/*`
- `package:flutter_riverpod/*`, `package:get_it/*`, `package:go_router/*`
- The feature's own `data/` or `presentation/` directories.
- Other features' `data/` or `presentation/` directories.

Allowed: `package:equatable`, `package:fpdart`, `package:meta`, and core helpers (`../../../../core/error/failures.dart`, `../../../../core/usecase/usecase.dart`).

**Severity:** error.

### usecase-shape

**Check:** Classes in `apps/mobile/lib/src/features/*/domain/usecases/*.dart` MUST `implements UseCase<T, Params>` and return `Future<Either<Failure, T>>` from `call`.

**Severity:** error.

### repository-returns-either

**Check:** Abstract methods in `apps/mobile/lib/src/features/*/domain/repositories/*_repository.dart` MUST return `Future<Either<Failure, T>>`. Methods returning raw `T` or throwing are flagged.

**Severity:** error.

### model-extends-or-converts-to-entity

**Check:** Files in `apps/mobile/lib/src/features/*/data/models/*_model.dart` should either:

- Extend the corresponding entity, OR
- Provide a `toEntity()` method that returns the entity type.

**Severity:** warn.

### repository-impl-catches-dio-exception

**Check:** Files in `apps/mobile/lib/src/features/*/data/repositories/*_repository_impl.dart` should catch `DioException` and map to a typed `Failure`. Methods that propagate `DioException` are flagged.

**Severity:** warn.

### page-is-consumer-widget

**Check:** Classes in `apps/mobile/lib/src/features/*/presentation/pages/*_page.dart` should `extends ConsumerWidget` or `extends ConsumerStatefulWidget`. Plain `StatelessWidget`/`StatefulWidget` is flagged (means the page can't read providers ergonomically).

**Severity:** warn.

### no-business-logic-in-page

**Check:** Pages should not contain business calls — those go through controllers / use cases. Flag pages that import datasources or repositories directly.

**Severity:** error.

### state-is-sealed

**Check:** Files in `apps/mobile/lib/src/features/*/presentation/state/*_state.dart` should declare a `sealed class` parent. Non-sealed state hierarchies are flagged (loses pattern-match exhaustiveness).

**Severity:** warn.

### no-print

**Check:** No `print(...)` calls in any Dart file. Flag and recommend `logger` (from the `logger` package configured in `core/`).

**Severity:** warn.

## Output format

Same shape as the API review: grouped by severity, sorted by file path, each entry has file:line, [rule], description, Fix:, Why: (citation from CLAUDE.md). End with file count.

## Be honest about limits

The skill catches structural issues. It does NOT catch:

- Missing error handling in widgets (showing raw failure messages, etc.)
- Riverpod misuse (rebuild storms, leaked controllers)
- Performance issues (unnecessary `setState`, expensive `build` methods)

Note in footer: `Note: this review checks structure only. UI/UX correctness needs human review or device testing.`
