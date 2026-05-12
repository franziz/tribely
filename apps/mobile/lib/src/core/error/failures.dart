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
