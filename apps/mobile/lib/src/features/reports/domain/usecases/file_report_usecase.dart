import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/report.dart';
import '../entities/report_reason.dart';
import '../repositories/report_repository.dart';

class FileReportParams extends Equatable {
  const FileReportParams({
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.comment,
  });

  final String targetType;
  final String targetId;
  final ReportReason reason;
  final String? comment;

  @override
  List<Object?> get props => [targetType, targetId, reason, comment];
}

/// File a report against a content target.
///
/// POST /reports
/// Validation (comment length) lives in [ReportInputValidator];
/// this use case delegates to the repository without re-validating.
class FileReportUseCase implements UseCase<Report, FileReportParams> {
  const FileReportUseCase(this._repository);
  final ReportRepository _repository;

  @override
  Future<Either<Failure, Report>> call(FileReportParams params) =>
      _repository.fileReport(
        targetType: params.targetType,
        targetId: params.targetId,
        reason: params.reason,
        comment: params.comment,
      );
}
