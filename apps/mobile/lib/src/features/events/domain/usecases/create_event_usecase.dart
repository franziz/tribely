import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/event.dart';
import '../repositories/event_repository.dart';

/// Create a new event on the server from a completed multi-step form.
class CreateEventUseCase implements UseCase<Event, CreateEventParams> {
  const CreateEventUseCase(this._repository);
  final EventRepository _repository;

  @override
  Future<Either<Failure, Event>> call(CreateEventParams params) {
    return _repository.createEvent(params);
  }
}
