import 'package:equatable/equatable.dart';

/// Sealed value type describing WHY the sign-in gate was triggered.
///
/// The [SignInGateSheet] uses this only to drive context-aware headline copy —
/// it does NOT act on the intent itself. The CALLER (Briefs B/C) is responsible
/// for reading [showSignInGateSheet]'s `Future<bool>` result and resuming the
/// intended action.
///
/// Implements [Equatable] so that Riverpod's autoDispose.family key comparison
/// works correctly across reconstructed intent objects with the same values.
///
/// Variants:
/// - [SignInIntentRequestJoin] — user tapped "Request to join" on an event.
/// - [SignInIntentCreateEvent] — user tapped "Create event".
/// - [SignInIntentGeneral] — generic gate not tied to a specific verb
///   (e.g. signed-out tab empty states, TRI-71); drives a neutral headline.
///
/// A review variant is reserved as a future case but NOT wired here.
sealed class SignInIntent extends Equatable {
  const SignInIntent();

  const factory SignInIntent.requestJoin({
    required String eventId,
    required String eventTitle,
    required String hostName,
    required DateTime startsAt,
    required DateTime endsAt,
  }) = SignInIntentRequestJoin;

  const factory SignInIntent.createEvent() = SignInIntentCreateEvent;

  const factory SignInIntent.general() = SignInIntentGeneral;
}

class SignInIntentRequestJoin extends SignInIntent {
  const SignInIntentRequestJoin({
    required this.eventId,
    required this.eventTitle,
    required this.hostName,
    required this.startsAt,
    required this.endsAt,
  });

  final String eventId;
  final String eventTitle;
  final String hostName;
  final DateTime startsAt;
  final DateTime endsAt;

  @override
  List<Object?> get props => [eventId, eventTitle, hostName, startsAt, endsAt];
}

class SignInIntentCreateEvent extends SignInIntent {
  const SignInIntentCreateEvent();

  @override
  List<Object?> get props => [];
}

class SignInIntentGeneral extends SignInIntent {
  const SignInIntentGeneral();

  @override
  List<Object?> get props => [];
}

// RESERVED — a "review" variant is planned but not yet wired.
// When the review feature is scoped in, add:
//   const factory SignInIntent.postReview({required String eventId}) = SignInIntentPostReview;
// and add the corresponding class + exhaustive switch cases at all call sites.
