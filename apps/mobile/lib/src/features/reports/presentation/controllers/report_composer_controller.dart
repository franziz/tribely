import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/report_reason.dart';
import '../../domain/usecases/file_report_usecase.dart';
import '../providers/reports_providers.dart';
import '../state/report_composer_state.dart';

/// Owns the state for the report composer sheet.
///
/// Disposes when the sheet is dismissed (autoDispose on the provider).
///
/// Responsibilities:
///   - [submit]: POST /reports — Idle → Submitting → Success|Failure
///   - [reset]: returns to Idle after the caller acknowledges an error
class ReportComposerController extends Notifier<ReportComposerState> {
  @override
  ReportComposerState build() => const ReportComposerIdle();

  /// File a report against [targetId] of [targetType].
  ///
  /// Guards against double-submit by checking [ReportComposerSubmitting].
  Future<void> submit({
    required String targetType,
    required String targetId,
    required ReportReason reason,
    String? comment,
  }) async {
    if (state is ReportComposerSubmitting) return;
    state = const ReportComposerSubmitting();

    final useCase = ref.read(fileReportUseCaseProvider);
    final params = FileReportParams(
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      comment: comment,
    );
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) =>
          ReportComposerFailure(message: _messageFor(failure), reason: reason),
      (report) => ReportComposerSuccess(report: report),
    );
  }

  /// Returns to [ReportComposerIdle].
  void reset() {
    state = const ReportComposerIdle();
  }
}

// ---------------------------------------------------------------------------
// Failure → user-visible message
// ---------------------------------------------------------------------------

String _messageFor(Failure failure) {
  return switch (failure) {
    TargetNotFoundFailure() =>
      'This review no longer exists and cannot be reported.',
    TargetTypeNotImplementedFailure() =>
      'Reporting this type of content is not yet supported.',
    AuthFailure() => 'Please sign in to file a report.',
    EmailNotVerifiedFailure() =>
      'Please verify your email before filing a report.',
    NetworkFailure() => "Couldn't reach Tribely. Check your connection.",
    ValidationFailure() => failure.message,
    _ => 'Something went wrong. Please try again.',
  };
}
