import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
// import use cases + controller as you create them

/// Providers for the `reports` feature.
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
