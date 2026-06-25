import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/event.dart';
import '../repositories/cover_photo_repository.dart';

class ReplaceCoverPhotoParams extends Equatable {
  const ReplaceCoverPhotoParams({
    required this.eventId,
    required this.storageKey,
  });

  final String eventId;
  final String storageKey;

  @override
  List<Object?> get props => [eventId, storageKey];
}

/// Commits a previously uploaded cover photo key to an existing event.
///
/// Step 2 of the edit-cover-photo flow: after [UploadCoverPhotoUseCase]
/// returns the storageKey, this use case calls PUT /events/:id/cover-photo
/// to persist the association. Returns the updated [Event] (post-mutation
/// server state) on success.
///
/// Failure paths:
///   - [AuthFailure]: 401 — session expired.
///   - [NotFoundFailure]: 404 — event not found or not owned by the user.
///   - [ConflictFailure]: 409 — event state conflict (e.g. cancelled).
///   - [ServerFailure]: other 4xx/5xx Tribely API errors.
///   - [NetworkFailure]: device offline.
class ReplaceCoverPhotoUseCase
    implements UseCase<Event, ReplaceCoverPhotoParams> {
  const ReplaceCoverPhotoUseCase(this._repository);
  final CoverPhotoRepository _repository;

  @override
  Future<Either<Failure, Event>> call(ReplaceCoverPhotoParams params) {
    return _repository.replaceCoverPhoto(
      eventId: params.eventId,
      storageKey: params.storageKey,
    );
  }
}
