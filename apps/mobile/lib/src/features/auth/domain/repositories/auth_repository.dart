import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/auth_session.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthSession>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthSession>> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Exchange the stored refresh token for a fresh access + refresh pair.
  /// Used at cold start (silent refresh) and when an access token expires
  /// mid-flight.
  Future<Either<Failure, AuthSession>> refresh();

  /// Sign out a single session (the local one). Idempotent — succeeds even
  /// if the token is already revoked or never existed.
  Future<Either<Failure, void>> signOut();

  /// Sign out every session for the current user. Auth required.
  Future<Either<Failure, void>> signOutAll();

  /// Fetch the currently-authenticated user.
  Future<Either<Failure, User>> me();

  /// Submit the 6-digit code from the verification email. Returns the
  /// freshly-verified user on success so the UI can update state without
  /// a follow-up `me` call.
  Future<Either<Failure, User>> verifyEmail({required String code});

  /// Re-issue a verification code for the current user.
  Future<Either<Failure, void>> resendVerification();

  /// Issue a password-reset code to the given email. Always returns success
  /// regardless of whether the email is on file (server enforces enumeration
  /// safety) — the UI shows a neutral confirmation message either way.
  Future<Either<Failure, void>> requestPasswordReset({required String email});

  /// Submit the 6-digit code + new password to complete a reset. On success
  /// the server has invalidated all of the user's sessions; the UI returns
  /// to /sign-in.
  Future<Either<Failure, void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Start the SMS OTP flow by sending a 6-digit code to [phone] (E.164 format,
  /// e.g. "+6591234567"). The server applies a rate cap; the caller should
  /// surface [SmsRateLimitedFailure] with a user-friendly message.
  Future<Either<Failure, void>> startPhoneVerification({required String phone});

  /// Verify the 6-digit code that arrived via SMS. On success returns the
  /// updated [User] with [User.phoneVerifiedAt] populated so the UI can
  /// optimistically update session state without a follow-up /auth/me call.
  Future<Either<Failure, User>> verifyPhone({
    required String phone,
    required String code,
  });
}
