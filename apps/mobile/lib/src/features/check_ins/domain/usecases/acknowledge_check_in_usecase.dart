import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/check_ins_repository.dart';

class AcknowledgeCheckInParams extends Equatable {
  const AcknowledgeCheckInParams({required this.checkInId});

  final String checkInId;

  @override
  List<Object?> get props => [checkInId];
}

/// Acknowledge a pending post-event check-in, marking the attendee as safe.
class AcknowledgeCheckInUseCase
    implements UseCase<Unit, AcknowledgeCheckInParams> {
  const AcknowledgeCheckInUseCase(this._repository);

  final CheckInsRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(AcknowledgeCheckInParams params) =>
      _repository.acknowledge(params.checkInId);
}
