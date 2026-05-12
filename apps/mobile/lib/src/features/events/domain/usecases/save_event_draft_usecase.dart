import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/event_draft.dart';
import '../repositories/event_repository.dart';

/// Persist the current in-progress event draft locally so the user can
/// resume the multi-step form after leaving the flow.
class SaveEventDraftUseCase implements UseCase<void, EventDraft> {
  const SaveEventDraftUseCase(this._repository);
  final EventRepository _repository;

  @override
  Future<Either<Failure, void>> call(EventDraft params) {
    return _repository.saveDraft(params);
  }
}
