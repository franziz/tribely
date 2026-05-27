import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/support_ticket_draft.dart';
import '../repositories/support_repository.dart';

/// Submit a support ticket on behalf of the authenticated user.
///
/// POST /support/tickets
/// Delegates directly to [SupportRepository.submitTicket] without
/// re-validating — input validation lives in the form controller.
class SubmitSupportTicketUseCase
    implements UseCase<SubmitResult, SupportTicketDraft> {
  const SubmitSupportTicketUseCase(this._repository);
  final SupportRepository _repository;

  @override
  Future<Either<Failure, SubmitResult>> call(SupportTicketDraft params) =>
      _repository.submitTicket(params);
}
