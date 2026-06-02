import 'package:equatable/equatable.dart';

import '../../domain/entities/place_details.dart';
import '../../domain/entities/place_suggestion.dart';

/// State machine for the venue-picker UI on Step 2 of the create-event wizard.
///
/// State machine:
///   VenuePickerInitial
///     ─── onQueryChanged (non-empty) ──► VenuePickerSearching
///   VenuePickerSearching
///     ─── debounce fires + success (non-empty) ──► VenuePickerResults
///     ─── debounce fires + success (empty) ─────► VenuePickerEmpty
///     ─── debounce fires + QuotaExhaustedFailure ► VenuePickerDegradedQuota
///     ─── debounce fires + NetworkFailure ────────► VenuePickerDegradedNetwork
///     ─── debounce fires + ProviderFailure ───────► VenuePickerDegradedNetwork
///   VenuePickerResults
///     ─── selectSuggestion (coords present) ─────► VenuePickerSelected
///     ─── selectSuggestion (coords absent) ──────► VenuePickerNoCoords
///   VenuePickerSelected
///     ─── clearSelection() ───────────────────────► VenuePickerInitial
///   VenuePickerDegradedQuota
///     (terminal within session — free-text always-visible)
///   VenuePickerDegradedNetwork
///     ─── retry (onQueryChanged) ─────────────────► VenuePickerSearching
///   VenuePickerNoCoords
///     (rare; host must search again or use free-text)
sealed class VenuePickerState extends Equatable {
  const VenuePickerState();
}

/// No query entered; search field is empty and idle.
final class VenuePickerInitial extends VenuePickerState {
  const VenuePickerInitial();

  @override
  List<Object?> get props => const [];
}

/// Query text has changed; the debounce window is still open.
/// The UI can render a spinner or loading shimmer on the suggestion list.
final class VenuePickerSearching extends VenuePickerState {
  const VenuePickerSearching(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// The provider returned a non-empty list of autocomplete suggestions.
final class VenuePickerResults extends VenuePickerState {
  const VenuePickerResults(this.suggestions);

  final List<PlaceSuggestion> suggestions;

  @override
  List<Object?> get props => [suggestions];
}

/// The provider returned zero results for [query].
/// The UI should render an empty-state message (e.g. "No places found").
final class VenuePickerEmpty extends VenuePickerState {
  const VenuePickerEmpty(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// The user tapped a suggestion row and [PlaceSearchPort.retrieve] succeeded.
/// The UI should render a confirmation view (venue name, address, static map).
final class VenuePickerSelected extends VenuePickerState {
  const VenuePickerSelected(this.details);

  final PlaceDetails details;

  @override
  List<Object?> get props => [details];
}

/// The provider's quota is exhausted (HTTP 429 / 403-quota-body).
///
/// Search is disabled for the remainder of the session. The UI must keep
/// the free-text venue entry field permanently visible so the user can still
/// complete the wizard.
final class VenuePickerDegradedQuota extends VenuePickerState {
  const VenuePickerDegradedQuota();

  @override
  List<Object?> get props => const [];
}

/// A transient failure: network unreachable or provider 5xx/malformed response.
///
/// The UI renders an inline error banner with a retry CTA. The user can retry
/// by typing again, which transitions back to [VenuePickerSearching].
final class VenuePickerDegradedNetwork extends VenuePickerState {
  const VenuePickerDegradedNetwork(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The selected place came back without coordinates.
///
/// This is a rare defensive state for Mapbox /retrieve responses that are
/// structurally valid but lack lat/lng (e.g. a partial result). The UI should
/// prompt the user to search again or fall back to manual entry.
final class VenuePickerNoCoords extends VenuePickerState {
  const VenuePickerNoCoords(this.providerName);

  /// Human-readable provider name for the error message, e.g. "Mapbox".
  final String providerName;

  @override
  List<Object?> get props => [providerName];
}
