import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/event_repository.dart';

/// Remove the locally-persisted event draft. Idempotent — succeeds even if
/// no draft exists (e.g. after a successful create or explicit discard).
class ClearEventDraftUseCase implements UseCase<void, NoParams> {
  const ClearEventDraftUseCase(this._repository);
  final EventRepository _repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return _repository.clearDraft();
  }
}
