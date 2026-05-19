import 'package:equatable/equatable.dart';

import '../../domain/entities/review.dart';

/// State machine for the review composer (submit + edit flows).
///
/// Transitions:
///   Idle ────────── submit()/edit() ──────► Submitting
///   Submitting ──── success ──────────────► Success(review)
///   Submitting ──── failure ──────────────► Failure(message, code?)
///   Success/Failure ── reset() ───────────► Idle
sealed class ReviewComposerState extends Equatable {
  const ReviewComposerState();
}

/// Default state. The form is ready for input.
final class ReviewComposerIdle extends ReviewComposerState {
  const ReviewComposerIdle();

  @override
  List<Object?> get props => [];
}

/// A submit or edit call is in flight.
final class ReviewComposerSubmitting extends ReviewComposerState {
  const ReviewComposerSubmitting();

  @override
  List<Object?> get props => [];
}

/// Submission succeeded. [review] is the server-confirmed entity (submit path).
/// Edit path transitions here with the locally-known review updated with the
/// new rating/comment since the server returns 204.
final class ReviewComposerSuccess extends ReviewComposerState {
  const ReviewComposerSuccess({required this.review});

  final Review review;

  @override
  List<Object?> get props => [review];
}

/// Submission or edit failed. [message] is human-readable. [code] is the
/// machine-readable error code when available (e.g. `reviews.editWindowExpired`).
final class ReviewComposerFailure extends ReviewComposerState {
  const ReviewComposerFailure({required this.message, this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}
