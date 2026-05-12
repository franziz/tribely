import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/discover/domain/repositories/discover_repository.dart';
import 'package:tribely/src/features/discover/domain/usecases/get_event_detail_usecase.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockDiscoverRepository extends Mock implements DiscoverRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _stubEvent = Event(
  id: 'evt-42',
  hostId: 'usr-7',
  title: 'Marina Run',
  description: 'Morning jog',
  venue: const EventVenue(
    address: 'Marina Bay Waterfront',
    city: 'Singapore',
    latitude: 1.28,
    longitude: 103.86,
  ),
  startsAt: DateTime(2030, 8, 10, 7),
  endsAt: DateTime(2030, 8, 10, 9),
  capacity: 15,
  category: EventCategory.sports,
  costSplit: 'own',
  approvalMode: 'manual',
  status: 'published',
  createdAt: DateTime(2030, 7, 1),
);

void main() {
  late _MockDiscoverRepository repo;
  late GetEventDetailUseCase useCase;

  setUp(() {
    repo = _MockDiscoverRepository();
    useCase = GetEventDetailUseCase(repo);
  });

  group('GetEventDetailUseCase', () {
    test(
      'delegates eventId to repository.getEventDetail → Right(Event)',
      () async {
        when(
          () => repo.getEventDetail('evt-42'),
        ).thenAnswer((_) async => Right(_stubEvent));

        final result = await useCase(
          const GetEventDetailParams(eventId: 'evt-42'),
        );

        expect(result.isRight(), isTrue);
        final event = (result as Right<Failure, Event>).value;
        expect(event.id, 'evt-42');
        verify(() => repo.getEventDetail('evt-42')).called(1);
      },
    );

    test('404 → Left(NotFoundFailure)', () async {
      const failure = NotFoundFailure('Event not found');
      when(
        () => repo.getEventDetail(any()),
      ).thenAnswer((_) async => const Left(failure));

      final result = await useCase(
        const GetEventDetailParams(eventId: 'evt-missing'),
      );

      expect(result.isLeft(), isTrue);
      expect((result as Left).value, isA<NotFoundFailure>());
    });

    test('propagates any Failure from repository unchanged', () async {
      const failure = NetworkFailure('Offline');
      when(
        () => repo.getEventDetail(any()),
      ).thenAnswer((_) async => const Left(failure));

      final result = await useCase(
        const GetEventDetailParams(eventId: 'evt-1'),
      );

      expect(result, const Left<Failure, Event>(failure));
    });
  });
}
