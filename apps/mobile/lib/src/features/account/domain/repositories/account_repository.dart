import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';

abstract class AccountRepository {
  /// Deletes the authenticated user's account.
  ///
  /// Identity is established server-side from the bearer token — no userId
  /// parameter is required. Returns [Right(null)] on success.
  Future<Either<Failure, void>> deleteAccount();
}
