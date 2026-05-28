import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/support_ticket_draft.dart';

/// The result of a successful ticket submission.
class SubmitResult extends Equatable {
  const SubmitResult({required this.id, required this.createdAt});

  /// Server-assigned ticket ID.
  final String id;

  /// UTC timestamp of ticket creation.
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, createdAt];
}

/// Outbound port for the support feature.
///
/// Implementations live in data/repositories/. All methods return
/// `Either<Failure, T>` — DioExceptions are mapped at the repository boundary.
abstract class SupportRepository {
  /// POST /support/tickets — submit a support ticket.
  ///
  /// Returns [SubmitResult] on success.
  /// Failures: `NetworkFailure`, `AuthFailure`, `RateLimitedFailure`,
  /// `ValidationFailure`, `ServerFailure`.
  Future<Either<Failure, SubmitResult>> submitTicket(SupportTicketDraft draft);
}
