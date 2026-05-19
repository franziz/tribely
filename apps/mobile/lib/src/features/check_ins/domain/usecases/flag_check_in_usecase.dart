import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/check_ins_repository.dart';

class FlagCheckInParams extends Equatable {
  const FlagCheckInParams({required this.checkInId, required this.reportBody});

  final String checkInId;
  final String reportBody;

  @override
  List<Object?> get props => [checkInId, reportBody];
}

/// Flag a check-in for safety review, attaching a free-text report.
class FlagCheckInUseCase implements UseCase<Unit, FlagCheckInParams> {
  const FlagCheckInUseCase(this._repository);

  final CheckInsRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(FlagCheckInParams params) =>
      _repository.flag(params.checkInId, params.reportBody);
}
