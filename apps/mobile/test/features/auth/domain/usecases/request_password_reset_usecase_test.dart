import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:tribely/src/features/auth/domain/usecases/request_password_reset_usecase.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;
  late RequestPasswordResetUseCase useCase;

  setUp(() {
    repo = _MockAuthRepository();
    useCase = RequestPasswordResetUseCase(repo);
  });

  group('RequestPasswordResetUseCase', () {
    test('delegates email to repository.requestPasswordReset', () async {
      when(
        () => repo.requestPasswordReset(email: any(named: 'email')),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(
        const RequestPasswordResetParams(email: 'alice@example.com'),
      );

      expect(result, const Right<Failure, void>(null));
      verify(
        () => repo.requestPasswordReset(email: 'alice@example.com'),
      ).called(1);
    });

    test('propagates a Failure from the repository unchanged', () async {
      const failure = NetworkFailure('offline');
      when(
        () => repo.requestPasswordReset(email: any(named: 'email')),
      ).thenAnswer((_) async => const Left(failure));

      final result = await useCase(
        const RequestPasswordResetParams(email: 'alice@example.com'),
      );

      expect(result, const Left<Failure, void>(failure));
    });
  });
}
