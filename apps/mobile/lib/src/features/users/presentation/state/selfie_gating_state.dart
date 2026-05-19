import 'package:equatable/equatable.dart';

import '../../domain/value_objects/selfie_failure_category.dart';

/// Represents the current selfie verification gate state for the authenticated
/// user. Derived purely from [User.selfieStatus] + [User.selfieAppealLockedAt].
///
/// All variants are immutable value types (Equatable) so Riverpod's equality
/// check can skip rebuilds when the derived state hasn't actually changed.
sealed class SelfieGatingState extends Equatable {
  const SelfieGatingState();

  @override
  List<Object?> get props => [];
}

/// User has not yet started the selfie verification flow.
class SelfieGatingNotStarted extends SelfieGatingState {
  const SelfieGatingNotStarted();
}

/// Selfie has been submitted and is awaiting review.
class SelfieGatingPending extends SelfieGatingState {
  const SelfieGatingPending();
}

/// Selfie was rejected and the user may re-submit.
///
/// [category] is the reason for rejection (nullable — the backend may not
/// always surface one, e.g. for legacy records).
/// [attemptCount] is how many total attempts have been made so the UI can
/// show graduated guidance copy.
class SelfieGatingFailed extends SelfieGatingState {
  const SelfieGatingFailed({
    required this.category,
    required this.attemptCount,
  });

  final SelfieFailureCategory? category;
  final int attemptCount;

  @override
  List<Object?> get props => [category, attemptCount];
}

/// Selfie was rejected and the appeal window is locked — the user must wait
/// until [SelfieGatingState.locked] is no longer returned before re-submitting.
///
/// [category] is the reason for the most recent rejection.
class SelfieGatingLocked extends SelfieGatingState {
  const SelfieGatingLocked({required this.category});

  final SelfieFailureCategory? category;

  @override
  List<Object?> get props => [category];
}

/// Selfie verification is complete — user is approved.
class SelfieGatingApproved extends SelfieGatingState {
  const SelfieGatingApproved();
}
