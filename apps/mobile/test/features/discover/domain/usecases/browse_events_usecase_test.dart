import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/discover/domain/entities/discover_filters.dart';
import 'package:tribely/src/features/discover/domain/entities/event_page.dart';
import 'package:tribely/src/features/discover/domain/repositories/discover_repository.dart';
import 'package:tribely/src/features/discover/domain/usecases/browse_events_usecase.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';

// ---------------------------------------------------------------------------
// Mocks + fakes
// ---------------------------------------------------------------------------

class _MockDiscoverRepository extends Mock implements DiscoverRepository {}

class _FakeDiscoverFilters extends Fake implements DiscoverFilters {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Event _makeEvent(String id) => Event(
      id: id,
      hostId: 'usr-1',
      title: 'Test Event',
      description: null,
      venue: const EventVenue(
        address: '1 Marina Blvd',
        city: 'Singapore',
        latitude: 1.28,
        longitude: 103.85,
      ),
      startsAt: DateTime(2030, 6, 15, 18),
      endsAt: DateTime(2030, 6, 15, 21),
      capacity: 8,
      category: EventCategory.drinks,
      costSplit: 'own',
      approvalMode: 'auto',
      status: 'published',
      createdAt: DateTime(2030, 6, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDiscoverFilters());
  });

  late _MockDiscoverRepository repo;
  late BrowseEventsUseCase useCase;

  setUp(() {
    repo = _MockDiscoverRepository();
    useCase = BrowseEventsUseCase(repo);
  });

  // ---------------------------------------------------------------------------
  // Delegation
  // ---------------------------------------------------------------------------
  group('BrowseEventsUseCase — delegation', () {
    test('delegates filters to repository.browseEvents and returns page',
        () async {
      const filters = DiscoverFilters(timeWindow: TimeWindow.tonight, limit: 10);
      final page = EventPage(events: [_makeEvent('evt-1')], nextCursor: 'c1');

      when(
        () => repo.browseEvents(filters),
      ).thenAnswer((_) async => Right(page));

      final result = await useCase(const BrowseEventsParams(filters: filters));

      expect(result.isRight(), isTrue);
      expect((result as Right<Failure, EventPage>).value, page);
      verify(() => repo.browseEvents(filters)).called(1);
    });

    test('propagates Failure from repository unchanged', () async {
      const failure = NetworkFailure('Offline');
      when(
        () => repo.browseEvents(any()),
      ).thenAnswer((_) async => const Left(failure));

      final result = await useCase(
        const BrowseEventsParams(filters: DiscoverFilters()),
      );

      expect(result, const Left<Failure, EventPage>(failure));
    });
  });

  // ---------------------------------------------------------------------------
  // Filter → query param serialisation
  // ---------------------------------------------------------------------------
  group('DiscoverFilters.toQueryParams — serialisation', () {
    test('anytime time window → timeWindow key omitted', () {
      const f = DiscoverFilters(timeWindow: TimeWindow.anytime);
      final params = f.toQueryParams();
      expect(params.containsKey('timeWindow'), isFalse);
    });

    test('tonight → timeWindow=tonight', () {
      const f = DiscoverFilters(timeWindow: TimeWindow.tonight);
      expect(f.toQueryParams()['timeWindow'], 'tonight');
    });

    test('thisWeek → timeWindow=thisWeek', () {
      const f = DiscoverFilters(timeWindow: TimeWindow.thisWeek);
      expect(f.toQueryParams()['timeWindow'], 'thisWeek');
    });

    test('empty categories → categories key omitted', () {
      const f = DiscoverFilters();
      expect(f.toQueryParams().containsKey('categories'), isFalse);
    });

    test('two categories → comma-joined wire values', () {
      const f = DiscoverFilters(
        categories: {EventCategory.drinks, EventCategory.hike},
      );
      final cats = f.toQueryParams()['categories']!.split(',');
      expect(cats, containsAll(['drinks', 'hike']));
    });

    test('maxDistanceKm null → maxDistanceKm/lat/lng omitted', () {
      const f = DiscoverFilters();
      final p = f.toQueryParams();
      expect(p.containsKey('maxDistanceKm'), isFalse);
      expect(p.containsKey('lat'), isFalse);
      expect(p.containsKey('lng'), isFalse);
    });

    test('maxDistanceKm set → maxDistanceKm + lat + lng present', () {
      const f = DiscoverFilters(
        maxDistanceKm: 5.0,
        lat: 1.3,
        lng: 103.8,
      );
      final p = f.toQueryParams();
      expect(p['maxDistanceKm'], '5.0');
      expect(p['lat'], '1.3');
      expect(p['lng'], '103.8');
    });

    test('cursor null → cursor key omitted', () {
      const f = DiscoverFilters();
      expect(f.toQueryParams().containsKey('cursor'), isFalse);
    });

    test('cursor non-null → cursor present as-is (opaque)', () {
      const f = DiscoverFilters(cursor: 'cursor-xyz');
      expect(f.toQueryParams()['cursor'], 'cursor-xyz');
    });

    test('limit is always present in query params', () {
      const f = DiscoverFilters(limit: 15);
      expect(f.toQueryParams()['limit'], '15');
    });

    test('default limit is 20', () {
      const f = DiscoverFilters();
      expect(f.toQueryParams()['limit'], '20');
    });
  });
}
