import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/auth_session.dart';

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

  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, AuthSession?>> currentSession();
}
