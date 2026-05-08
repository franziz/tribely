---
name: mobile-new-usecase
description: FLUTTER ONLY. Scaffold a Flutter use case in apps/mobile/lib/src/features/<feature>/domain/usecases/<verb>_<noun>_usecase.dart. Implements UseCase<T, Params>, returns Future<Either<Failure, T>>. Do NOT use for the API — use /api-new-usecase instead.
---

# /mobile-new-usecase

```
/mobile-new-usecase <feature> <verb-noun>
```

**Scope guard:** Flutter only. Flutter use cases are thin wrappers around a single repository call returning `Either<Failure, T>` (Reso Coder convention). Backend use cases orchestrate transactions and events — completely different shape. Use `/api-new-usecase` for the API.

Examples:
- `/mobile-new-usecase events create-event` → `events/domain/usecases/create_event_usecase.dart` → class `CreateEventUseCase`
- `/mobile-new-usecase users get-profile` → class `GetProfileUseCase`

## Validate

REFUSE if:
- `<feature>` doesn't exist under `apps/mobile/lib/src/features/`.
- Verb is past tense (use cases are intents — present tense).
- File would overwrite an existing one.

## Scaffold

Path: `apps/mobile/lib/src/features/<feature>/domain/usecases/<verb>_<noun>_usecase.dart`. Note Dart files use `snake_case`.

Class name: PascalCase + `UseCase` (e.g. `CreateEventUseCase`).

```dart
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
// import the entity and repository this use case calls

class <PascalName>Params extends Equatable {
  const <PascalName>Params({
    // TODO: required this.<field>,
  });

  // TODO: final <Type> <field>;

  @override
  List<Object?> get props => [/* TODO: fields */];
}

/// <one-line description of the user intent>
class <PascalName>UseCase implements UseCase<<ResultType>, <PascalName>Params> {
  const <PascalName>UseCase(this._repository);
  final <FeatureRepository> _repository;

  @override
  Future<Either<Failure, <ResultType>>> call(<PascalName>Params params) {
    // TODO: return _repository.<method>(...);
    throw UnimplementedError();
  }
}
```

If the use case takes no parameters, replace `<PascalName>Params` with `NoParams` from `core/usecase/usecase.dart`.

## Print after scaffolding

```
Use case scaffolded at <path>

NEXT STEPS:
  1. Replace <ResultType> and the repository method call.
  2. Register in apps/mobile/lib/src/core/di/service_locator.dart:
       sl.registerLazySingleton(() => <PascalName>UseCase(sl<<FeatureRepository>>()));
  3. Expose to UI via a Riverpod provider in
     features/<feature>/presentation/providers/<feature>_providers.dart:
       final <camelName>UseCaseProvider = Provider((_) => sl<<PascalName>UseCase>());
```

DO NOT auto-edit `service_locator.dart` — manual.
