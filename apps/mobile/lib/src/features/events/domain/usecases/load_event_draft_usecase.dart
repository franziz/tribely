import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/event_draft.dart';
import '../repositories/event_repository.dart';

/// Load the locally-persisted event draft. Returns [null] when no draft
/// exists, so the form starts fresh.
class LoadEventDraftUseCase implements UseCase<EventDraft?, NoParams> {
  const LoadEventDraftUseCase(this._repository);
  final EventRepository _repository;

  @override
  Future<Either<Failure, EventDraft?>> call(NoParams params) {
    return _repository.loadDraft();
  }
}
