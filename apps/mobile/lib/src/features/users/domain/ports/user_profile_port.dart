import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_profile.dart';

/// Port for fetching a user's profile by ID.
///
/// Decouples consumers (e.g. user_blocks enrichment) from the concrete
/// [UserProfileRemoteDatasource] implementation, keeping cross-feature
/// data-layer coupling out of the data layer.
abstract class UserProfilePort {
  /// Returns the [UserProfile] for [userId], or a [Failure] on error.
  Future<Either<Failure, UserProfile>> getUserProfile(String userId);
}
