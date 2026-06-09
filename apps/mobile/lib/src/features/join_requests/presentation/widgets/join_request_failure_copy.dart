import '../../../../core/error/failures.dart';

/// Returns a user-facing error string for a join-request [Failure].
///
/// Shared by [ConfirmJoinSheet] and [SafetyReminderSheet] — extracted to avoid
/// duplicating the switch in both widgets (Brief G, Q2 ruling).
String joinRequestFailureMessage(Failure failure) {
  return switch (failure) {
    EmailNotVerifiedFailure() =>
      'Please verify your email before requesting to join.',
    CapacityFullFailure() => 'This event is full.',
    ConflictFailure(:final subcode) when subcode == 'ALREADY_APPROVED' =>
      'You have already been approved for this event.',
    ConflictFailure() => 'You already have a pending request for this event.',
    NetworkFailure() => 'No connection. Check your network and try again.',
    _ => failure.message,
  };
}
