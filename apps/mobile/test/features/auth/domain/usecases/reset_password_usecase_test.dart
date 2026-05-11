import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:tribely/src/features/auth/domain/usecases/reset_password_usecase.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;
  late ResetPasswordUseCase useCase;

  setUp(() {
    repo = _MockAuthRepository();
    useCase = ResetPasswordUseCase(repo);
  });

  group('ResetPasswordUseCase', () {
    test('delegates all params to repository.resetPassword', () async {
      when(
        () => repo.resetPassword(
          email: any(named: 'email'),
          code: any(named: 'code'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(
        const ResetPasswordParams(
          email: 'alice@example.com',
          code: '482917',
          newPassword: 'newPassw0rd!',
        ),
      );

      expect(result, const Right<Failure, void>(null));
      verify(
        () => repo.resetPassword(
          email: 'alice@example.com',
          code: '482917',
          newPassword: 'newPassw0rd!',
        ),
      ).called(1);
    });

    test(
      'propagates a ValidationFailure from the repository unchanged',
      () async {
        const failure = ValidationFailure('Invalid or expired reset code.');
        when(
          () => repo.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenAnswer((_) async => const Left(failure));

        final result = await useCase(
          const ResetPasswordParams(
            email: 'alice@example.com',
            code: '000000',
            newPassword: 'newPassw0rd!',
          ),
        );

        expect(result, const Left<Failure, void>(failure));
      },
    );
  });
}
