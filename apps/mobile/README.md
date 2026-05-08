# tribely (mobile)

Flutter app — Riverpod + go_router + Dio + Clean Architecture.

## First-time setup

This folder ships only the `lib/`, `pubspec.yaml`, and analysis config. To generate the iOS/Android platform code:

```bash
cd apps/mobile
flutter create --org com.tribely --platforms=ios,android .
flutter pub get
```

(`flutter create` is non-destructive — it only fills in missing platform folders.)

## Run

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

For Android emulator, use `http://10.0.2.2:3000` instead of localhost.

## Codegen

```bash
dart run build_runner build --delete-conflicting-outputs
```

(Currently no codegen is required — but we added build_runner + freezed + json_serializable for future features.)

## Architecture

See repo root `README.md`. Quick reference for `lib/src/features/<name>/`:

- `domain/` — entities, repositories (interfaces), use cases. Pure Dart, no Flutter or Dio imports.
- `data/` — models (DTOs), datasources (interfaces + impls), repository impls. Catches `DioException` and returns `Either<Failure, T>`.
- `presentation/` — pages, widgets, providers (Riverpod), controllers (StateNotifier), state (sealed classes).
