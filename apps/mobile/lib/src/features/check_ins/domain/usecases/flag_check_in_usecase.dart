import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/check_ins_repository.dart';

class FlagCheckInParams extends Equatable {
  const FlagCheckInParams({
    required this.checkInId,
    required this.reportBody,
    required this.disclaimerAcknowledged,
  });

  final String checkInId;
  final String reportBody;

  /// Whether the user has explicitly ticked the pre-submit 999 disclaimer
  /// checkbox. Must be `true` for the submission to proceed — the UI gate
  /// enforces this; the field is propagated to the API for audit purposes.
  final bool disclaimerAcknowledged;

  @override
  List<Object?> get props => [checkInId, reportBody, disclaimerAcknowledged];
}

/// Flag a check-in for safety review, attaching a free-text report.
class FlagCheckInUseCase implements UseCase<Unit, FlagCheckInParams> {
  const FlagCheckInUseCase(this._repository);

  final CheckInsRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(FlagCheckInParams params) =>
      _repository.flag(
        params.checkInId,
        params.reportBody,
        params.disclaimerAcknowledged,
      );
}
