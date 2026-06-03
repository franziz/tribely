import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/event_repository.dart';

class CancelEventParams extends Equatable {
  const CancelEventParams({
    required this.eventId,
  });

  final String eventId;

  @override
  List<Object?> get props => [eventId];
}

/// Cancel a published event on behalf of the host.
class CancelEventUseCase implements UseCase<void, CancelEventParams> {
  const CancelEventUseCase(this._repository);
  final EventRepository _repository;

  @override
  Future<Either<Failure, void>> call(CancelEventParams params) {
    return _repository.cancelEvent(params.eventId);
  }
}
