import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_capabilities.dart';

/// Abstract repository for fetching the current user's capability flags.
///
/// The concrete implementation lives in
/// `data/repositories/user_capabilities_repository_impl.dart`.
abstract class UserCapabilitiesRepository {
  /// Fetch capability flags for the authenticated user from the server.
  ///
  /// Calls `GET /users/me/capabilities`. Returns a [Right] with the flags
  /// on success, or a [Left] with a [ServerFailure] / [NetworkFailure] on error.
  Future<Either<Failure, UserCapabilities>> getMyCapabilities();
}
