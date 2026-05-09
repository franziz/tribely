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
}
