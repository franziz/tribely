import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../events/domain/entities/event.dart';
import '../repositories/discover_repository.dart';

class ListMyHostedEventsParams extends Equatable {
  const ListMyHostedEventsParams();

  @override
  List<Object?> get props => const [];
}

/// List the current authenticated user's own hosted events.
/// Calls `GET /me/events` — requires the user to be signed in.
class ListMyHostedEventsUseCase
    implements UseCase<List<Event>, ListMyHostedEventsParams> {
  const ListMyHostedEventsUseCase(this._repository);
  final DiscoverRepository _repository;

  @override
  Future<Either<Failure, List<Event>>> call(ListMyHostedEventsParams params) =>
      _repository.listMyHostedEvents();
}
