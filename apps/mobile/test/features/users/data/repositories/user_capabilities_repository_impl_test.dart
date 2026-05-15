// Unit tests for UserCapabilitiesRepositoryImpl.
//
// Key safety invariant pinned by these tests:
//   Network-failure safer-default — when the server is unreachable, the
//   myCapabilitiesProvider folds the Left(NetworkFailure) to
//   UserCapabilities.restricted() (canPostPrivateVenue=false). This test
//   verifies the repository correctly returns Left(NetworkFailure) on a
//   network error so the provider can apply the safer default.
//
// Coverage:
//   1. Success → Right(UserCapabilities) with canPostPrivateVenue from server.
//   2. Server returns false → Right(UserCapabilities(canPostPrivateVenue: false)).
//   3. NetworkException → Left(NetworkFailure).
//   4. ServerException(401) → Left(AuthFailure).
//   5. ServerException(500) → Left(ServerFailure).
//   6. Arbitrary exception → Left(UnknownFailure).
//   7. canPostPrivateVenue absent from response → Right(false) defensive default.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/exceptions.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/users/data/datasources/user_capabilities_remote_datasource.dart';
import 'package:tribely/src/features/users/data/repositories/user_capabilities_repository_impl.dart';
import 'package:tribely/src/features/users/domain/entities/user_capabilities.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockUserCapabilitiesRemoteDatasource extends Mock
    implements UserCapabilitiesRemoteDatasource {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a [DioException] whose [DioException.error] is [inner].
DioException _dioWith(Object inner) {
  return DioException(requestOptions: RequestOptions(), error: inner);
}

void main() {
  late _MockUserCapabilitiesRemoteDatasource remote;
  late UserCapabilitiesRepositoryImpl repo;

  setUp(() {
    remote = _MockUserCapabilitiesRemoteDatasource();
    repo = UserCapabilitiesRepositoryImpl(remote: remote);
  });

  // ---------------------------------------------------------------------------
  // getMyCapabilities — success paths
  // ---------------------------------------------------------------------------
  group('getMyCapabilities — success', () {
    test(
      'server returns canPostPrivateVenue=true → Right(canPostPrivateVenue=true)',
      () async {
        when(
          () => remote.getMyCapabilities(),
        ).thenAnswer((_) async => {'canPostPrivateVenue': true});

        final result = await repo.getMyCapabilities();

        expect(result.isRight(), isTrue);
        final caps = (result as Right<Failure, UserCapabilities>).value;
        expect(caps.canPostPrivateVenue, isTrue);
      },
    );

    test(
      'server returns canPostPrivateVenue=false → Right(canPostPrivateVenue=false)',
      () async {
        when(
          () => remote.getMyCapabilities(),
        ).thenAnswer((_) async => {'canPostPrivateVenue': false});

        final result = await repo.getMyCapabilities();

        expect(result.isRight(), isTrue);
        final caps = (result as Right<Failure, UserCapabilities>).value;
        expect(caps.canPostPrivateVenue, isFalse);
      },
    );

    test('canPostPrivateVenue absent from response body → Right(false) '
        '(defensive default — safer than throwing)', () async {
      // Server omits the field (forward-compat scenario for future flags).
      when(
        () => remote.getMyCapabilities(),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repo.getMyCapabilities();

      expect(result.isRight(), isTrue);
      final caps = (result as Right<Failure, UserCapabilities>).value;
      expect(
        caps.canPostPrivateVenue,
        isFalse,
        reason:
            'absent field must default to false (safer: show restriction '
            'warnings rather than silently grant private-venue access)',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getMyCapabilities — error paths
  // ---------------------------------------------------------------------------
  group('getMyCapabilities — error mapping', () {
    test('NetworkException → Left(NetworkFailure) — '
        'provider must fold this to UserCapabilities.restricted()', () async {
      final ex = const NetworkException('No connection');
      when(() => remote.getMyCapabilities()).thenThrow(_dioWith(ex));

      final result = await repo.getMyCapabilities();

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<NetworkFailure>());
    });

    test('ServerException(401) → Left(AuthFailure)', () async {
      final ex = const ServerException('Unauthorized', statusCode: 401);
      when(() => remote.getMyCapabilities()).thenThrow(_dioWith(ex));

      final result = await repo.getMyCapabilities();

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<AuthFailure>());
    });

    test(
      'ServerException(500) → Left(ServerFailure) with status 500',
      () async {
        final ex = const ServerException('Server error', statusCode: 500);
        when(() => remote.getMyCapabilities()).thenThrow(_dioWith(ex));

        final result = await repo.getMyCapabilities();

        expect(result.isLeft(), isTrue);
        final failure = (result as Left).value;
        expect(failure, isA<ServerFailure>());
        expect((failure as ServerFailure).statusCode, 500);
      },
    );

    test('arbitrary Exception → Left(UnknownFailure)', () async {
      when(
        () => remote.getMyCapabilities(),
      ).thenThrow(Exception('Something unexpected'));

      final result = await repo.getMyCapabilities();

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<UnknownFailure>());
    });
  });
}
