import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/check_ins/domain/repositories/check_ins_repository.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/flag_check_in_usecase.dart';

class MockCheckInsRepository extends Mock implements CheckInsRepository {}

void main() {
  late MockCheckInsRepository repository;
  late FlagCheckInUseCase useCase;

  setUp(() {
    repository = MockCheckInsRepository();
    useCase = FlagCheckInUseCase(repository);
  });

  const params = FlagCheckInParams(
    checkInId: 'ci-1',
    reportBody: 'Felt unsafe at venue',
    disclaimerAcknowledged: true,
  );

  test('delegates to repository.flag() and returns Right(unit)', () async {
    when(
      () => repository.flag('ci-1', 'Felt unsafe at venue', true),
    ).thenAnswer((_) async => const Right(unit));

    final result = await useCase(params);

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => repository.flag('ci-1', 'Felt unsafe at venue', true))
        .called(1);
  });

  test('propagates Left(failure) from repository unchanged', () async {
    const failure = NetworkFailure('offline');
    when(
      () => repository.flag(any(), any(), any()),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase(params);

    expect(result.isLeft(), isTrue);
    expect(
      result.swap().getOrElse((_) => const UnknownFailure('')),
      equals(failure),
    );
  });
}
