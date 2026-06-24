import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/events/domain/repositories/cover_photo_repository.dart';
import 'package:tribely/src/features/events/domain/usecases/upload_cover_photo_usecase.dart';

// ---------------------------------------------------------------------------
// Fakes & mocks
// ---------------------------------------------------------------------------

class _MockCoverPhotoRepository extends Mock implements CoverPhotoRepository {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockCoverPhotoRepository mockRepository;
  late UploadCoverPhotoUseCase useCase;

  setUp(() {
    mockRepository = _MockCoverPhotoRepository();
    useCase = UploadCoverPhotoUseCase(mockRepository);
  });

  final tBytes = Uint8List.fromList([1, 2, 3]);
  const tStorageKey = 'covers/abc-123.jpeg';

  group('UploadCoverPhotoUseCase', () {
    test('delegates to repository and returns storageKey on success', () async {
      when(
        () => mockRepository.uploadCoverPhoto(tBytes),
      ).thenAnswer((_) async => const Right(tStorageKey));

      final result = await useCase(tBytes);

      expect(result, const Right<Failure, String>(tStorageKey));
      verify(() => mockRepository.uploadCoverPhoto(tBytes)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test(
      'returns ValidationFailure when repository returns size cap failure',
      () async {
        const failure = ValidationFailure(
          'Cover photo must be under 15 MB.',
          code: 'COVER_PHOTO_TOO_LARGE',
        );
        when(
          () => mockRepository.uploadCoverPhoto(tBytes),
        ).thenAnswer((_) async => const Left(failure));

        final result = await useCase(tBytes);

        expect(result, const Left<Failure, String>(failure));
      },
    );

    test(
      'returns NetworkFailure when repository surfaces network error',
      () async {
        const failure = NetworkFailure('No internet');
        when(
          () => mockRepository.uploadCoverPhoto(tBytes),
        ).thenAnswer((_) async => const Left(failure));

        final result = await useCase(tBytes);

        expect(result, const Left<Failure, String>(failure));
      },
    );

    test(
      'returns ServerFailure when presign API returns server error',
      () async {
        const failure = ServerFailure('Internal server error', statusCode: 500);
        when(
          () => mockRepository.uploadCoverPhoto(tBytes),
        ).thenAnswer((_) async => const Left(failure));

        final result = await useCase(tBytes);

        expect(result, const Left<Failure, String>(failure));
      },
    );

    test('returns AuthFailure when presign API returns 401', () async {
      const failure = AuthFailure('Unauthorized');
      when(
        () => mockRepository.uploadCoverPhoto(tBytes),
      ).thenAnswer((_) async => const Left(failure));

      final result = await useCase(tBytes);

      expect(result, const Left<Failure, String>(failure));
    });
  });
}
