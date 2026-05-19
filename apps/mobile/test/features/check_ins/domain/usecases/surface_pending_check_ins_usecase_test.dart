import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/usecase/usecase.dart';
import 'package:tribely/src/features/check_ins/domain/entities/pending_check_in.dart';
import 'package:tribely/src/features/check_ins/domain/repositories/check_ins_repository.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/surface_pending_check_ins_usecase.dart';

class MockCheckInsRepository extends Mock implements CheckInsRepository {}

PendingCheckIn _makeCheckIn(String id) => PendingCheckIn(
  id: id,
  eventId: 'event-1',
  eventTitle: 'Test Event',
  hostDisplayName: 'Host Alice',
  endedAt: DateTime(2026, 6, 1, 21),
  createdAt: DateTime(2026, 6, 1, 22),
);

void main() {
  late MockCheckInsRepository repository;
  late SurfacePendingCheckInsUseCase useCase;

  setUp(() {
    repository = MockCheckInsRepository();
    useCase = SurfacePendingCheckInsUseCase(repository);
  });

  test('delegates to repository.surfacePending() and returns result', () async {
    final items = [_makeCheckIn('ci-1'), _makeCheckIn('ci-2')];
    when(
      () => repository.surfacePending(),
    ).thenAnswer((_) async => Right(items));

    final result = await useCase(const NoParams());

    expect(result.isRight(), isTrue);
    expect(result.getOrElse((_) => []), hasLength(2));
    verify(() => repository.surfacePending()).called(1);
  });

  test('propagates Left(failure) from repository unchanged', () async {
    const failure = NetworkFailure('offline');
    when(
      () => repository.surfacePending(),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase(const NoParams());

    expect(result.isLeft(), isTrue);
    expect(
      result.swap().getOrElse((_) => const UnknownFailure('')),
      equals(failure),
    );
  });
}
