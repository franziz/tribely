---
name: mobile-new-feature
description: FLUTTER ONLY. Scaffold a new feature in apps/mobile/lib/src/features/<name>/ following the Flutter Clean Architecture 3-layer convention (domain/data/presentation), Reso Coder style, with Riverpod + fpdart. Do NOT use for the API — use /api-new-feature instead.
---

# /mobile-new-feature

```
/mobile-new-feature <plural-kebab-name>
```

**Scope guard:** Flutter mobile app only (`apps/mobile/`). If asked to scaffold something in `apps/api/`, refuse and direct to `/api-new-feature`. The two stacks have deliberately different layering (3-layer for Flutter, 4-layer for backend — see CLAUDE.md).

Creates `apps/mobile/lib/src/features/<name>/` matching the canonical layout (`auth` is the reference template).

## Why Flutter is 3-layer (not 4-layer like the API)

Flutter use cases are thin wrappers: `Future<Either<Failure, T>> call(Params) => repository.method()`. They don't orchestrate transactions, multiple aggregates, or events. Adding an `application/` layer for thin wrappers is over-engineering on the client. Flutter community standard (Reso Coder, Riverpod examples) keeps use cases in `domain/usecases/`. We follow the convention.

## Validate

REFUSE and explain if:
- Name is singular (`event` instead of `events`).
- Name suggests infrastructure (`logging`, `cache`, `network`) — those belong in `apps/mobile/lib/src/core/`.
- Name is too vague (`common`, `shared`, `utils`, `data`).
- A folder with that name already exists under `apps/mobile/lib/src/features/`.

## Scaffold

Compute `<snake_name>` (kebab → snake_case for Dart files: `join-requests` → `join_requests`).

Create:

```
apps/mobile/lib/src/features/<snake_name>/
  domain/
    entities/.gitkeep
    repositories/.gitkeep                 # Abstract interfaces returning Either<Failure, T>
    usecases/.gitkeep                     # implements UseCase<T, Params>
  data/
    datasources/.gitkeep                  # Remote + local datasources (interface + impl colocated)
    models/.gitkeep                       # fromJson + toEntity DTOs
    repositories/.gitkeep                 # Concrete impls — catch DioException, return Failure
  presentation/
    pages/.gitkeep                        # ConsumerWidget screens
    widgets/.gitkeep                      # Feature-scoped widgets
    providers/<snake_name>_providers.dart # Riverpod providers wiring use cases
    controllers/.gitkeep                  # StateNotifier — owns state transitions
    state/.gitkeep                        # Sealed state classes
```

`presentation/providers/<snake_name>_providers.dart` body:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
// import use cases + controller as you create them

/// Providers for the `<snake_name>` feature.
/// Use cases are resolved via the get_it service locator and exposed to the
/// widget tree as Riverpod providers.

// Example pattern (uncomment as use cases are added):
//
// final <UsecaseName>Provider = Provider<<UsecaseName>>(
//   (_) => sl<<UsecaseName>>(),
// );
//
// final <Name>ControllerProvider =
//     StateNotifierProvider<<Name>Controller, <Name>State>((ref) {
//   return <Name>Controller(useCase: ref.watch(<UsecaseName>Provider));
// });
```

## After scaffolding — print this checklist

```
Mobile feature scaffolded at apps/mobile/lib/src/features/<snake_name>/

NEXT STEPS (manual — these require judgement):

  1. Define your domain entity:
     - lib/src/features/<snake_name>/domain/entities/<entity>.dart
     - Use Equatable for value equality
     - Pure Dart — no Flutter, no Dio, no Riverpod imports

  2. Define repository interface:
     - lib/src/features/<snake_name>/domain/repositories/<feature>_repository.dart
     - Methods return Future<Either<Failure, T>>

  3. Define use case(s):
     /mobile-new-usecase <snake_name> <verb-noun>

  4. Implement data layer:
     - data/models/<entity>_model.dart — JSON serialization + toEntity()
     - data/datasources/<feature>_remote_datasource.dart — Dio calls
     - data/repositories/<feature>_repository_impl.dart — catches DioException → Failure

  5. Build presentation:
     /mobile-new-page <snake_name> <page_name>

  6. Wire dependencies in apps/mobile/lib/src/core/di/service_locator.dart:
       sl.registerLazySingleton<<Name>RemoteDatasource>(
         () => <Name>RemoteDatasourceImpl(sl<ApiClient>().dio),
       );
       sl.registerLazySingleton<<Name>Repository>(
         () => <Name>RepositoryImpl(remote: sl<<Name>RemoteDatasource>()),
       );
       sl.registerLazySingleton(() => <Verb><Noun>UseCase(sl<<Name>Repository>()));

  7. Add routes in apps/mobile/lib/src/core/router/app_router.dart.
```

DO NOT auto-edit `service_locator.dart`, `app_router.dart`, or other wiring files.
