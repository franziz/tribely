import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/report.dart';
import '../entities/report_reason.dart';

/// Outbound port for the reports feature.
///
/// Implementations live in data/repositories/. All methods return
/// Either<Failure, T> — DioExceptions are mapped at the repository boundary.
abstract class ReportRepository {
  /// POST /reports — file a report against a content target.
  ///
  /// Returns the created [Report] on success.
  /// Failures: [NetworkFailure], [AuthFailure], [TargetNotFoundFailure],
  /// [TargetTypeNotImplementedFailure], [ValidationFailure], [ServerFailure].
  Future<Either<Failure, Report>> fileReport({
    required String targetType,
    required String targetId,
    required ReportReason reason,
    String? comment,
  });
}
