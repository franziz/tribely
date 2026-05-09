---
name: mobile-new-page
description: FLUTTER ONLY. Scaffold a Flutter page (screen) as a ConsumerWidget in apps/mobile/lib/src/features/<feature>/presentation/pages/<page_name>_page.dart, with optional StateNotifier controller + sealed state. Do NOT use for the API.
---

# /mobile-new-page

```
/mobile-new-page <feature> <page-name>           # stateless page (just renders)
/mobile-new-page <feature> <page-name> --stateful   # page + StateNotifier controller + sealed state
```

**Scope guard:** Flutter only. Pages are a UI concept — there's no equivalent on the backend.

Examples:

- `/mobile-new-page events list` → `events/presentation/pages/list_page.dart`
- `/mobile-new-page events create --stateful` → adds `controllers/create_controller.dart` + `state/create_state.dart`

## Validate

REFUSE if:

- `<feature>` doesn't exist under `apps/mobile/lib/src/features/`.
- `<page-name>` is not snake_case kebab-able.
- File would overwrite an existing one.

## Scaffold the page

Path: `apps/mobile/lib/src/features/<feature>/presentation/pages/<page_name>_page.dart`.

Class name: PascalCase of `<page-name>` + `Page`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class <PascalName>Page extends ConsumerWidget {
  const <PascalName>Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('<PascalName>')),
      body: const Center(child: Text('<PascalName>Page')),
    );
  }
}
```

## --stateful: also scaffold controller + state

If `--stateful` is passed:

### Sealed state at `presentation/state/<page_name>_state.dart`

```dart
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';

sealed class <PascalName>State extends Equatable {
  const <PascalName>State();

  @override
  List<Object?> get props => [];
}

class <PascalName>Initial extends <PascalName>State {
  const <PascalName>Initial();
}

class <PascalName>Loading extends <PascalName>State {
  const <PascalName>Loading();
}

class <PascalName>Loaded extends <PascalName>State {
  const <PascalName>Loaded(this.data);
  final dynamic data; // TODO: replace with actual type
  @override
  List<Object?> get props => [data];
}

class <PascalName>Error extends <PascalName>State {
  const <PascalName>Error(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}
```

### Controller at `presentation/controllers/<page_name>_controller.dart`

Riverpod 3.x `Notifier` (NOT the deprecated `StateNotifier`):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/<feature>_providers.dart';
import '../state/<page_name>_state.dart';

class <PascalName>Controller extends Notifier<<PascalName>State> {
  @override
  <PascalName>State build() => const <PascalName>Initial();

  // Resolve dependencies via `ref.read(...)` inside methods rather than
  // constructor-injecting them — standard Riverpod 3.x convention.
  //
  // Example:
  //
  // Future<void> load() async {
  //   state = const <PascalName>Loading();
  //   final useCase = ref.read(<someUseCaseProvider>);
  //   final result = await useCase(NoParams());
  //   state = result.match(
  //     (failure) => <PascalName>Error(failure),
  //     (data) => <PascalName>Loaded(data),
  //   );
  // }
}
```

### Wire the controller in the feature's providers file

The skill should ADD a provider entry to `apps/mobile/lib/src/features/<feature>/presentation/providers/<feature>_providers.dart` (or print the snippet for the user to paste if the file doesn't exist):

```dart
final <camelName>ControllerProvider =
    NotifierProvider<<PascalName>Controller, <PascalName>State>(<PascalName>Controller.new);
```

### Update the page to consume the controller

The page becomes:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/<feature>_providers.dart';
import '../state/<page_name>_state.dart';

class <PascalName>Page extends ConsumerWidget {
  const <PascalName>Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(<camelName>ControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('<PascalName>')),
      body: switch (state) {
        <PascalName>Initial() => const SizedBox.shrink(),
        <PascalName>Loading() => const Center(child: CircularProgressIndicator()),
        <PascalName>Loaded(data: final data) => Center(child: Text('$data')),
        <PascalName>Error(failure: final f) => Center(child: Text(f.message)),
      },
    );
  }
}
```

## Print after scaffolding

```
Page scaffolded at <path>
[--stateful] Controller and state scaffolded too.

NEXT STEPS:
  1. Add a route in apps/mobile/lib/src/core/router/app_router.dart:
       GoRoute(
         path: '/<feature>/<page-name>',
         name: '<camelName>',
         builder: (context, state) => const <PascalName>Page(),
       ),
  2. [--stateful] Replace TODOs with real use case wiring + result types.
  3. [--stateful] Trigger initial load if needed (ref.read on first build).
```

DO NOT auto-edit `app_router.dart` — manual.
