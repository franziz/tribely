// Providers for the `discover` feature.
// Use cases are resolved via the get_it service locator and exposed to the
// widget tree as Riverpod providers.
//
// Uncomment imports and add providers as use cases are created:
//
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../../../core/di/service_locator.dart';
//
// final <UsecaseName>Provider = Provider<<UsecaseName>>(
//   (_) => sl<<UsecaseName>>(),
// );
//
// final discoverControllerProvider =
//     StateNotifierProvider<DiscoverController, DiscoverState>((ref) {
//   return DiscoverController(useCase: ref.watch(<UsecaseName>Provider));
// });
