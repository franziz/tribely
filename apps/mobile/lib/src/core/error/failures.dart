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

/// 403 with code PHONE_NOT_VERIFIED. Distinct from AuthFailure (401) so the
/// UI can route the user to the verify-phone screen instead of treating it
/// as a hard sign-out.
class PhoneNotVerifiedFailure extends Failure {
  const PhoneNotVerifiedFailure(super.message, {super.code});
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

/// 422 UNPROCESSABLE with subcode `sms_rate_limited`. The user has exceeded
/// the SMS send-rate cap (5/hr per number). Distinct from the generic 429
/// [ServerFailure] so the UI can show the hourly-cap copy.
class SmsRateLimitedFailure extends Failure {
  const SmsRateLimitedFailure(super.message, {super.code});
}

/// 409 with code `reviews.editWindowExpired`. The 24-hour edit window for the
/// review has passed; the review is now locked.
class EditWindowExpiredFailure extends Failure {
  const EditWindowExpiredFailure(super.message, {super.code});
}

/// 404 when the report target (e.g. a review) does not exist or is not visible
/// to the reporting user. Distinct from the generic [NotFoundFailure] so the
/// reports UI can show context-specific copy ("This review no longer exists").
class TargetNotFoundFailure extends Failure {
  const TargetNotFoundFailure(super.message, {super.code});
}

/// 422 when the report target type is not yet supported by the backend
/// (e.g. reporting a message — only 'review' is implemented in MVP).
/// The UI uses this to show a graceful "not supported yet" message.
class TargetTypeNotImplementedFailure extends Failure {
  const TargetTypeNotImplementedFailure(super.message, {super.code});
}

/// 422 UNPROCESSABLE when the user attempts to block themselves.
///
/// The backend returns 422 with an error code indicating self-block is not
/// allowed. The UI renders a short inline error message.
class SelfBlockFailure extends Failure {
  const SelfBlockFailure(super.message, {super.code});
}

/// 422 UNPROCESSABLE with subcode `support.rateLimited`. The user has
/// exceeded the support-ticket submission rate cap. Distinct from the generic
/// [ServerFailure] so the UI can show rate-limit–specific copy.
class RateLimitedFailure extends Failure {
  const RateLimitedFailure(super.message, {super.code});
}

/// Provider quota or rate-limit exhausted (HTTP 429, or 403 with a
/// quota-exceeded body from Mapbox).
///
/// Distinct from [ServerFailure] so the presentation layer can switch to a
/// degraded mode (e.g. manual address entry) WITHOUT inspecting message
/// strings.
class QuotaExhaustedFailure extends Failure {
  const QuotaExhaustedFailure(super.message, {super.code});
}

/// External provider returned an unrecoverable error: 5xx response, malformed
/// JSON, or an unexpected schema that cannot be mapped to a domain entity.
///
/// Distinct from [ServerFailure] (which is reserved for Tribely's own API) so
/// the presentation layer can distinguish provider outages from backend errors.
class ProviderFailure extends Failure {
  const ProviderFailure(super.message, {super.code});
}

/// 503 SELFIE_INTAKE_DISABLED — selfie intake is temporarily paused by ops.
///
/// The consent screen renders the maintenance-mode variant and never opens
/// the camera.
class SelfieIntakeDisabledFailure extends Failure {
  const SelfieIntakeDisabledFailure([
    super.message = 'Selfie intake is temporarily unavailable',
  ]) : super(code: 'SELFIE_INTAKE_DISABLED');
}

/// 403 SELFIE_NOT_VERIFIED — an action requires a verified selfie.
///
/// Distinct from generic [ServerFailure] so the presentation layer can route
/// the user to the selfie consent flow rather than showing a generic error.
class SelfieNotVerifiedFailure extends Failure {
  const SelfieNotVerifiedFailure([
    super.message = 'Selfie verification required',
  ]) : super(code: 'SELFIE_NOT_VERIFIED');
}

/// 422 UNPROCESSABLE with subcode FIRST_EVENT_MUST_BE_PUBLIC.
///
/// The server rejects the create/update call because the user's first event
/// must use a public venue category. [reason] carries the machine-readable
/// explanation:
///   - 'category_not_public' — the selected venue category is not in the
///     public allowlist (e.g. 'apartment', 'condo').
///   - 'keyword_match' — the venue name contains a private-venue keyword
///     (e.g. 'my place', 'airbnb') even though no category was set.
///
/// The UI uses [reason] to render context-specific recovery copy (Brief 11).
class FirstEventMustBePublicFailure extends Failure {
  const FirstEventMustBePublicFailure({required this.reason, String? message})
    : super(message ?? 'Your first event must be held at a public venue.');

  /// 'category_not_public' | 'keyword_match'
  final String reason;

  @override
  List<Object?> get props => [reason, message];
}
