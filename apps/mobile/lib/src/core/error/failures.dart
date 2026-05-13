import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code, this.statusCode});
  final int? statusCode;

  @override
  List<Object?> get props => [...super.props, statusCode];
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code, this.fieldErrors});
  final Map<String, List<String>>? fieldErrors;

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

/// 403 with code EMAIL_NOT_VERIFIED. Distinct from AuthFailure (401) so the
/// UI can route the user to the verify-email screen instead of treating it
/// as a hard sign-out.
class EmailNotVerifiedFailure extends Failure {
  const EmailNotVerifiedFailure(super.message, {super.code});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.code});
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.code});
}

/// 409 with details.subcode === 'CAPACITY_FULL'. The event has no more room.
class CapacityFullFailure extends Failure {
  const CapacityFullFailure(super.message, {super.code});
}

/// 409 with a subcode indicating a state-transition conflict (e.g.
/// ALREADY_APPROVED, ALREADY_REJECTED, ALREADY_CANCELLED). [subcode] carries
/// the machine-readable value so the UI can render context-specific copy.
class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {required this.subcode, super.code});

  final String subcode;

  @override
  List<Object?> get props => [...super.props, subcode];
}
