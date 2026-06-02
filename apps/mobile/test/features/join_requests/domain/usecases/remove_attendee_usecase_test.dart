import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/join_requests/domain/repositories/join_request_repository.dart';
import 'package:tribely/src/features/join_requests/domain/usecases/remove_attendee_usecase.dart';

class MockJoinRequestRepository extends Mock implements JoinRequestRepository {}

void main() {
  late MockJoinRequestRepository repository;
  late RemoveAttendeeUseCase useCase;

  setUp(() {
    repository = MockJoinRequestRepository();
    useCase = RemoveAttendeeUseCase(repository);
  });

  const params = RemoveAttendeeParams(
    eventId: 'evt-1',
    joinRequestId: 'jr-1',
    reason: 'No-show at the venue',
  );

  test(
    'delegates to repository.removeAttendee() and returns Right(unit)',
    () async {
      when(
        () => repository.removeAttendee(
          eventId: 'evt-1',
          joinRequestId: 'jr-1',
          reason: 'No-show at the venue',
        ),
      ).thenAnswer((_) async => const Right(unit));

      final result = await useCase(params);

      expect(result, const Right<Failure, Unit>(unit));
      verify(
        () => repository.removeAttendee(
          eventId: 'evt-1',
          joinRequestId: 'jr-1',
          reason: 'No-show at the venue',
        ),
      ).called(1);
    },
  );

  test('propagates Left(failure) from repository unchanged', () async {
    const failure = NetworkFailure('offline');
    when(
      () => repository.removeAttendee(
        eventId: any(named: 'eventId'),
        joinRequestId: any(named: 'joinRequestId'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase(params);

    expect(result.isLeft(), isTrue);
    expect(
      result.swap().getOrElse((_) => const UnknownFailure('')),
      equals(failure),
    );
  });
}
