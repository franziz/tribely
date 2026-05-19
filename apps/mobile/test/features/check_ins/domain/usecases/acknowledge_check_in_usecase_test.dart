import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/check_ins/domain/repositories/check_ins_repository.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/acknowledge_check_in_usecase.dart';

class MockCheckInsRepository extends Mock implements CheckInsRepository {}

void main() {
  late MockCheckInsRepository repository;
  late AcknowledgeCheckInUseCase useCase;

  setUp(() {
    repository = MockCheckInsRepository();
    useCase = AcknowledgeCheckInUseCase(repository);
  });

  const params = AcknowledgeCheckInParams(checkInId: 'ci-1');

  test(
    'delegates to repository.acknowledge() and returns Right(unit)',
    () async {
      when(
        () => repository.acknowledge('ci-1'),
      ).thenAnswer((_) async => const Right(unit));

      final result = await useCase(params);

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => repository.acknowledge('ci-1')).called(1);
    },
  );

  test('propagates Left(failure) from repository unchanged', () async {
    const failure = ServerFailure('Not found', statusCode: 404);
    when(
      () => repository.acknowledge(any()),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase(params);

    expect(result.isLeft(), isTrue);
    expect(
      result.swap().getOrElse((_) => const UnknownFailure('')),
      equals(failure),
    );
  });
}
