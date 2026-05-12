// Providers for the `events` feature.
// Use cases are resolved via the get_it service locator and exposed to the
// widget tree as Riverpod providers.
//
// Briefs 2–5 will add providers here as use cases are wired.
//
// Example pattern:
//
//   import 'package:flutter_riverpod/flutter_riverpod.dart';
//   import '../../../../core/di/service_locator.dart';
//   import '../../domain/usecases/create_event_usecase.dart';
//
//   final createEventUseCaseProvider = Provider<CreateEventUseCase>(
//     (_) => sl<CreateEventUseCase>(),
//   );
