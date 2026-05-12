import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../features/events/domain/entities/event.dart';
import '../repositories/discover_repository.dart';

class GetEventDetailParams extends Equatable {
  const GetEventDetailParams({required this.eventId});

  final String eventId;

  @override
  List<Object?> get props => [eventId];
}

/// Fetch the full detail of a single event by its ID.
/// Returns [NotFoundFailure] when the server responds with 404.
class GetEventDetailUseCase
    implements UseCase<Event, GetEventDetailParams> {
  const GetEventDetailUseCase(this._repository);
  final DiscoverRepository _repository;

  @override
  Future<Either<Failure, Event>> call(GetEventDetailParams params) {
    return _repository.getEventDetail(params.eventId);
  }
}
