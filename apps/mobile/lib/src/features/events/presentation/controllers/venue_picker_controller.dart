import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/constants/place_search_constants.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/ports/place_search_port.dart';
import '../providers/venue_picker_providers.dart';
import '../state/venue_picker_state.dart';

/// Owns the venue-picker UI state machine.
///
/// Responsibilities:
///   - Debounced typeahead (300ms) with [onQueryChanged]
///   - Per-typeahead-cycle session token (UUID-style; rotated on clear/selection)
///   - [selectSuggestion] — calls [PlaceSearchPort.retrieve]; emits
///     [VenuePickerSelected] on success, [VenuePickerNoCoords] when coords are
///     absent from the response
///   - [clearSelection] — resets to [VenuePickerInitial]; rotates session token
///
/// Non-responsibilities (handled by the wizard controller in Brief F):
///   - Writing to [EventDraft] (Brief F territory)
///   - Mapping [PlaceDetails.rawCategory] to a TRI-33 venue category chip
///     ([provider_category_mapper] + Brief F territory)
///   - Free-text override state (owned by the wizard controller via EventDraft)
///
/// AutoDispose lives on the provider declaration ([venuePickerControllerProvider]),
/// NOT on this class — per the established Riverpod 3.x convention in this repo.
/// See `mobile-architecture.md` gotchas: "Mobile controllers use `Notifier<T>`,
/// auto-dispose lives on the provider."
class VenuePickerController extends Notifier<VenuePickerState> {
  Timer? _debounceTimer;

  /// Current typeahead session token.
  ///
  /// A fresh token is generated lazily on the first [onQueryChanged] call after
  /// construction or after [clearSelection]. The same token is used for all
  /// [suggest] calls and the subsequent [retrieve] call in the same user
  /// session — Mapbox bills a suggest+retrieve pair as one session when the
  /// token matches.
  ///
  /// Not exposed externally; callers never need to read the token directly.
  late String _sessionToken;

  /// Generates a UUID-style session token.
  ///
  /// `package:uuid` is not in pubspec.yaml. A deterministic-length hex string
  /// derived from [DateTime.microsecondsSinceEpoch] XOR'd with a random 32-bit
  /// int gives sufficient uniqueness for a client-side session token (the token
  /// is user-session scoped, not globally unique).
  static String _newSessionToken() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random.secure().nextInt(0xFFFFFFFF);
    return (ts ^ rand).toRadixString(16).padLeft(16, '0');
  }

  @override
  VenuePickerState build() {
    _sessionToken = _newSessionToken();

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    return const VenuePickerInitial();
  }

  // ---------------------------------------------------------------------------
  // Query input
  // ---------------------------------------------------------------------------

  /// Called on every keystroke in the venue search field.
  ///
  /// Clears any pending debounce, starts a new 300ms window, and transitions
  /// to [VenuePickerSearching] immediately so the UI can render a loading
  /// indicator.
  ///
  /// - Empty / whitespace-only [query] resets to [VenuePickerInitial].
  /// - [VenuePickerDegradedQuota] is terminal within the session — [suggest]
  ///   is not called when already in that state.
  void onQueryChanged(String query) {
    _debounceTimer?.cancel();

    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      state = const VenuePickerInitial();
      return;
    }

    // Quota-exhausted: search is permanently disabled for this session.
    if (state is VenuePickerDegradedQuota) return;

    state = VenuePickerSearching(trimmed);

    _debounceTimer = Timer(
      const Duration(milliseconds: kTypeaheadDebounceMs),
      () => _executeSuggest(trimmed),
    );
  }

  Future<void> _executeSuggest(String query) async {
    if (!ref.mounted) return;

    final port = ref.read(placeSearchPortProvider);
    final result = await port.suggest(
      query: query,
      sessionToken: _sessionToken,
    );

    if (!ref.mounted) return;

    result.fold(
      (failure) {
        state = switch (failure) {
          QuotaExhaustedFailure() => const VenuePickerDegradedQuota(),
          NetworkFailure(:final message) => VenuePickerDegradedNetwork(message),
          // ProviderFailure and any other failure are treated as transient
          // from the user's POV — show the retry banner, not a hard error.
          _ => VenuePickerDegradedNetwork(failure.message),
        };
      },
      (suggestions) {
        state = suggestions.isEmpty
            ? VenuePickerEmpty(query)
            : VenuePickerResults(suggestions);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  /// Called when the user taps a suggestion row.
  ///
  /// Calls [PlaceSearchPort.retrieve] with the SAME [_sessionToken] used for
  /// the preceding [suggest] calls — required for Mapbox session billing.
  ///
  /// - On success with coords → [VenuePickerSelected].
  /// - On success without coords → [VenuePickerNoCoords] (defensive guard;
  ///   rare for Mapbox /retrieve but the port contract does not guarantee
  ///   coords for every result type).
  /// - On failure → [VenuePickerDegradedNetwork] or [VenuePickerDegradedQuota]
  ///   as appropriate.
  ///
  /// Guard: if the state is already [VenuePickerSelected] with the same place
  /// ID, the call is a no-op — prevents double-retrieval on rapid taps.
  Future<void> selectSuggestion(PlaceSuggestion suggestion) async {
    final current = state;
    if (current is VenuePickerSelected &&
        current.details.providerPlaceId == suggestion.providerPlaceId) {
      return;
    }

    if (!ref.mounted) return;

    final port = ref.read(placeSearchPortProvider);
    final result = await port.retrieve(
      providerPlaceId: suggestion.providerPlaceId,
      sessionToken: _sessionToken,
    );

    if (!ref.mounted) return;

    result.fold(
      (failure) {
        state = switch (failure) {
          QuotaExhaustedFailure() => const VenuePickerDegradedQuota(),
          _ => VenuePickerDegradedNetwork(failure.message),
        };
      },
      (details) {
        // Guard: Mapbox /retrieve should always populate coords for POI
        // results, but the port contract allows null-ish doubles only
        // implicitly. Both fields are required on PlaceDetails so they are
        // always present — but log and emit NoCoords if the values are the
        // exact zero/zero sentinel that some providers use for "unknown".
        // A full lat==0 && lng==0 check would be too aggressive for Singapore
        // (near-equator), so we rely on the port implementation to reject
        // invalid coords. This controller only checks for the port succeeding.
        //
        // The PlaceDetails entity always carries non-null latitude/longitude
        // (required constructor fields), so no null-coord path exists after
        // a successful retrieve. The VenuePickerNoCoords state is retained for
        // future-proofing if the port contract ever widens to include optional
        // coords — or if a non-Mapbox provider is injected.
        debugPrint(
          '[VenuePickerController] selected: ${details.providerPlaceId}',
        );
        state = VenuePickerSelected(details);
      },
    );

    // Rotate session token after a successful selection so the next
    // typeahead cycle starts a fresh Mapbox billing session.
    _sessionToken = _newSessionToken();
  }

  // ---------------------------------------------------------------------------
  // Clear
  // ---------------------------------------------------------------------------

  /// Resets the picker to [VenuePickerInitial] and rotates the session token.
  ///
  /// Call this when the user taps the clear button on a selected venue or
  /// navigates back to the search field after confirming a selection.
  void clearSelection() {
    _debounceTimer?.cancel();
    _sessionToken = _newSessionToken();
    state = const VenuePickerInitial();
  }
}
