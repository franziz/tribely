import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/exceptions.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/events/data/datasources/event_remote_datasource.dart';
import 'package:tribely/src/features/events/data/models/cover_photo_upload_ticket_model.dart';
import 'package:tribely/src/features/events/data/repositories/cover_photo_repository_impl.dart';
import 'package:tribely/src/features/events/data/utils/cover_photo_compressor.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockEventRemoteDatasource extends Mock
    implements EventRemoteDatasource {}

class _MockCoverPhotoCompressor extends Mock implements CoverPhotoCompressor {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DioException _dioWith(Object inner) =>
    DioException(requestOptions: RequestOptions(), error: inner);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockEventRemoteDatasource mockRemote;
  late _MockCoverPhotoCompressor mockCompressor;
  late CoverPhotoRepositoryImpl repository;

  setUpAll(() {
    // any(named: 'bytes') matches a Uint8List param — mocktail requires a
    // registered fallback value for non-primitive types.
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockRemote = _MockEventRemoteDatasource();
    mockCompressor = _MockCoverPhotoCompressor();
    repository = CoverPhotoRepositoryImpl(
      remote: mockRemote,
      compressor: mockCompressor,
    );
  });

  tearDown(() {
    // Clear mocktail's matcher/interaction state between every test to prevent
    // named-matcher contamination across groups.
    reset(mockRemote);
    reset(mockCompressor);
  });

  final tCroppedBytes = Uint8List.fromList(List.generate(100, (i) => i));
  final tCompressedBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]); // JPEG magic
  const tUploadUrl = 'https://storage.example.com/covers/abc-123';
  const tStorageKey = 'covers/abc-123.jpeg';
  const tTicket = CoverPhotoUploadTicketModel(
    uploadUrl: tUploadUrl,
    storageKey: tStorageKey,
  );

  group('CoverPhotoRepositoryImpl.uploadCoverPhoto', () {
    group('happy path', () {
      setUp(() {
        when(
          () => mockCompressor.compress(tCroppedBytes),
        ).thenAnswer((_) async => tCompressedBytes);
        when(
          () => mockRemote.requestCoverPhotoUpload(
            CoverPhotoCompressor.outputMimeType,
          ),
        ).thenAnswer((_) async => tTicket);
        when(
          () => mockRemote.putCoverBytes(
            uploadUrl: any(named: 'uploadUrl'),
            bytes: any(named: 'bytes'),
            contentType: any(named: 'contentType'),
          ),
        ).thenAnswer((_) async {});
      });

      test('returns storageKey on success', () async {
        final result = await repository.uploadCoverPhoto(tCroppedBytes);
        expect(result, const Right<Failure, String>(tStorageKey));
      });

      test('calls compressor with cropped bytes', () async {
        await repository.uploadCoverPhoto(tCroppedBytes);
        verify(() => mockCompressor.compress(tCroppedBytes)).called(1);
      });

      test('presigns with image/jpeg — not the original picked type', () async {
        await repository.uploadCoverPhoto(tCroppedBytes);
        verify(
          () => mockRemote.requestCoverPhotoUpload(
            CoverPhotoCompressor.outputMimeType,
          ),
        ).called(1);
      });

      test('PUTs compressed bytes to the presigned URL', () async {
        await repository.uploadCoverPhoto(tCroppedBytes);
        verify(
          () => mockRemote.putCoverBytes(
            uploadUrl: tUploadUrl,
            bytes: tCompressedBytes,
            contentType: CoverPhotoCompressor.outputMimeType,
          ),
        ).called(1);
      });

      test('pipeline order: compress → presign → PUT', () async {
        final callLog = <String>[];
        when(() => mockCompressor.compress(any())).thenAnswer((_) async {
          callLog.add('compress');
          return tCompressedBytes;
        });
        when(() => mockRemote.requestCoverPhotoUpload(any())).thenAnswer((
          _,
        ) async {
          callLog.add('presign');
          return tTicket;
        });
        when(
          () => mockRemote.putCoverBytes(
            uploadUrl: any(named: 'uploadUrl'),
            bytes: any(named: 'bytes'),
            contentType: any(named: 'contentType'),
          ),
        ).thenAnswer((_) async {
          callLog.add('put');
        });

        await repository.uploadCoverPhoto(tCroppedBytes);
        expect(callLog, ['compress', 'presign', 'put']);
      });
    });

    group('size cap guard', () {
      test('returns ValidationFailure when input exceeds 15 MB', () async {
        // 15 MB + 1 byte
        final oversized = Uint8List(15 * 1024 * 1024 + 1);
        final result = await repository.uploadCoverPhoto(oversized);

        expect(result.isLeft(), isTrue);
        final failure = result.fold((l) => l, (_) => null);
        expect(failure, isA<ValidationFailure>());
        expect((failure as ValidationFailure).code, 'COVER_PHOTO_TOO_LARGE');

        // Neither compress nor presign should be called.
        verifyNever(() => mockCompressor.compress(any()));
        verifyNever(() => mockRemote.requestCoverPhotoUpload(any()));
      });
    });

    group('compress failure', () {
      test('returns UnknownFailure when compressor throws', () async {
        when(
          () => mockCompressor.compress(tCroppedBytes),
        ).thenThrow(Exception('Codec error'));

        final result = await repository.uploadCoverPhoto(tCroppedBytes);
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (_) => null), isA<UnknownFailure>());
      });
    });

    group('presign failure', () {
      setUp(() {
        when(
          () => mockCompressor.compress(tCroppedBytes),
        ).thenAnswer((_) async => tCompressedBytes);
      });

      test('returns AuthFailure on 401', () async {
        when(() => mockRemote.requestCoverPhotoUpload(any())).thenThrow(
          _dioWith(const ServerException('Unauthorized', statusCode: 401)),
        );

        final result = await repository.uploadCoverPhoto(tCroppedBytes);
        expect(result.fold((l) => l, (_) => null), isA<AuthFailure>());
      });

      test(
        'returns ValidationFailure on 413 (entity too large from server)',
        () async {
          when(() => mockRemote.requestCoverPhotoUpload(any())).thenThrow(
            _dioWith(const ServerException('Too large', statusCode: 413)),
          );

          final result = await repository.uploadCoverPhoto(tCroppedBytes);
          final failure = result.fold((l) => l, (_) => null);
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).code, 'COVER_PHOTO_TOO_LARGE');
        },
      );

      test('returns NetworkFailure when presign has network error', () async {
        when(
          () => mockRemote.requestCoverPhotoUpload(any()),
        ).thenThrow(_dioWith(const NetworkException('No connection')));

        final result = await repository.uploadCoverPhoto(tCroppedBytes);
        expect(result.fold((l) => l, (_) => null), isA<NetworkFailure>());
      });
    });

    group('PUT failure', () {
      setUp(() {
        when(
          () => mockCompressor.compress(tCroppedBytes),
        ).thenAnswer((_) async => tCompressedBytes);
        when(
          () => mockRemote.requestCoverPhotoUpload(any()),
        ).thenAnswer((_) async => tTicket);
      });

      test('returns NetworkFailure when PUT has network error', () async {
        when(
          () => mockRemote.putCoverBytes(
            uploadUrl: any(named: 'uploadUrl'),
            bytes: any(named: 'bytes'),
            contentType: any(named: 'contentType'),
          ),
        ).thenThrow(_dioWith(const NetworkException('PUT failed')));

        final result = await repository.uploadCoverPhoto(tCroppedBytes);
        expect(result.fold((l) => l, (_) => null), isA<NetworkFailure>());
      });

      test(
        'returns ServerFailure with COVER_PHOTO_PUT_FAILED on storage error',
        () async {
          when(
            () => mockRemote.putCoverBytes(
              uploadUrl: any(named: 'uploadUrl'),
              bytes: any(named: 'bytes'),
              contentType: any(named: 'contentType'),
            ),
          ).thenThrow(
            DioException(
              requestOptions: RequestOptions(),
              message: 'Storage rejected',
            ),
          );

          final result = await repository.uploadCoverPhoto(tCroppedBytes);
          final failure = result.fold((l) => l, (_) => null);
          expect(failure, isA<ServerFailure>());
          expect(failure!.code, 'COVER_PHOTO_PUT_FAILED');
        },
      );
    });
  });
}
