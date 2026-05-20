import 'package:equatable/equatable.dart';

import '../../domain/entities/report.dart';
import '../../domain/entities/report_reason.dart';

/// State machine for the report composer sheet.
///
/// Transitions:
///   Idle ──────── submit() ─────────────► Submitting
///   Submitting ── success ───────────────► Success(report)
///   Submitting ── failure ───────────────► Failure(message)
///   Success/Failure ── reset() ──────────► Idle
sealed class ReportComposerState extends Equatable {
  const ReportComposerState();
}

/// Default state. The form is ready for input.
final class ReportComposerIdle extends ReportComposerState {
  const ReportComposerIdle();

  @override
  List<Object?> get props => [];
}

/// A submit call is in flight.
final class ReportComposerSubmitting extends ReportComposerState {
  const ReportComposerSubmitting();

  @override
  List<Object?> get props => [];
}

/// Submission succeeded. [report] is the server-confirmed entity.
final class ReportComposerSuccess extends ReportComposerState {
  const ReportComposerSuccess({required this.report});

  final Report report;

  @override
  List<Object?> get props => [report];
}

/// Submission failed. [message] is human-readable.
final class ReportComposerFailure extends ReportComposerState {
  const ReportComposerFailure({required this.message, this.reason});

  final String message;

  /// The reason that was selected when the failure occurred. Preserved so the
  /// sheet can re-display the user's selection without resetting.
  final ReportReason? reason;

  @override
  List<Object?> get props => [message, reason];
}
