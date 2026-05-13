import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/discover_filters.dart';
import '../entities/event_page.dart';
import '../repositories/discover_repository.dart';

class BrowseEventsParams extends Equatable {
  const BrowseEventsParams({required this.filters});

  final DiscoverFilters filters;

  @override
  List<Object?> get props => [filters];
}

/// Browse publicly-visible events using cursor-based pagination and optional
/// filters (time window, category, distance). Returns an [EventPage] that
/// carries the next cursor for subsequent pages.
class BrowseEventsUseCase implements UseCase<EventPage, BrowseEventsParams> {
  const BrowseEventsUseCase(this._repository);
  final DiscoverRepository _repository;

  @override
  Future<Either<Failure, EventPage>> call(BrowseEventsParams params) {
    return _repository.browseEvents(params.filters);
  }
}
