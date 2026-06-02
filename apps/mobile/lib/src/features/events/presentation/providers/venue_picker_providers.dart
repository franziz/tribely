import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/ports/place_search_port.dart';
import '../controllers/venue_picker_controller.dart';
import '../state/venue_picker_state.dart';

// ---------------------------------------------------------------------------
// Port provider — wraps the GetIt service-locator lookup.
//
// Mirrors the use-case provider pattern in events_providers.dart: the provider
// resolves from GetIt so the controller never imports the concrete datasource
// (Brief B registers the port implementation in GetIt at startup).
// ---------------------------------------------------------------------------

/// Resolves [PlaceSearchPort] from the GetIt service locator.
///
/// Brief B registers the concrete implementation (MapboxPlaceSearchDatasource)
/// at service-locator initialisation. This provider is non-autoDispose because
/// the port is a stateless long-lived adapter — there is no value in
/// recreating it per picker lifecycle.
final placeSearchPortProvider = Provider<PlaceSearchPort>(
  (_) => sl<PlaceSearchPort>(),
);

// ---------------------------------------------------------------------------
// Controller provider
// ---------------------------------------------------------------------------

/// Venue-picker state machine provider.
///
/// AutoDispose is configured HERE (on the provider), not on the
/// [VenuePickerController] class — Riverpod 3.x convention for this repo.
/// See `mobile-architecture.md`: "Mobile controllers use `Notifier<T>`,
/// auto-dispose lives on the provider."
///
/// The provider is autoDispose so the picker state is reclaimed when the
/// Step 2 page is popped; a fresh search session starts on re-entry.
final venuePickerControllerProvider =
    NotifierProvider.autoDispose<VenuePickerController, VenuePickerState>(
      VenuePickerController.new,
    );
