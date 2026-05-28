import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';

/// State machine for [SupportContactController].
///
/// Transitions:
///   Idle        → Submitting  (on submit())
///   Submitting  → Idle        (on success — controller drives navigation)
///   Submitting  → Error(msg)  (on failure)
///   Error(msg)  → Idle        (on dismissBanner())
///   Error(msg)  → Submitting  (on retry via submit())
sealed class SupportContactState extends Equatable {
  const SupportContactState();
}

/// Default state. Form is editable.
final class SupportContactIdle extends SupportContactState {
  const SupportContactIdle();

  @override
  List<Object?> get props => [];
}

/// A submit call is in flight. Fields are locked at 50% opacity.
final class SupportContactSubmitting extends SupportContactState {
  const SupportContactSubmitting();

  @override
  List<Object?> get props => [];
}

/// The submit call failed. Banner is visible; form remains populated.
final class SupportContactError extends SupportContactState {
  const SupportContactError({
    required this.failure,
    required this.bannerMessage,
  });

  final Failure failure;
  final String bannerMessage;

  @override
  List<Object?> get props => [failure, bannerMessage];
}

/// The submit call succeeded. Controller emits this once, then the page
/// navigates away — this state is ephemeral and typically never rendered.
final class SupportContactSuccess extends SupportContactState {
  const SupportContactSuccess({required this.ticketId});

  final String ticketId;

  @override
  List<Object?> get props => [ticketId];
}
