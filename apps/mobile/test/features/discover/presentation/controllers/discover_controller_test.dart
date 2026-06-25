import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/services/location_service.dart';
import 'package:tribely/src/core/services/location_service_providers.dart';
import 'package:tribely/src/features/discover/domain/entities/discover_filters.dart';
import 'package:tribely/src/features/discover/domain/entities/event_page.dart';
import 'package:tribely/src/features/discover/domain/usecases/browse_events_usecase.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_filter_controller.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_filter_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_providers.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_filter_state.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_state.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockBrowseEventsUseCase extends Mock implements BrowseEventsUseCase {}

class MockLocationService extends Mock implements LocationService {}

// ---------------------------------------------------------------------------
// Fake registrations for mocktail
// ---------------------------------------------------------------------------

class FakeBrowseEventsParams extends Fake implements BrowseEventsParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps the microtask queue until it is drained, allowing async operations
/// that chain multiple awaits (e.g. _resolveFilters + useCase) to complete.
///
/// [Future<void>.delayed(Duration.zero)] only advances one macrotask; for
/// chains of async calls we need to flush multiple turns.
Future<void> _pump() async {
  // 20 turns covers the macrotask that schedules _fetchFirstPage plus the
  // chained awaits inside: (1) Future() callback, (2-3) _resolveFilters async
  // calls, (4) useCase await, (5) state assignment, (6+) Riverpod notification
  // propagation.  Duration.zero each turn drains one macrotask queue turn.
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Minimal [Event] stub for test assertions — only id matters for list checks.
Event _makeEvent(String id) => Event(
  id: id,
  hostId: 'host-1',
  title: 'Event $id',
  description: null,
  venue: const EventVenue(
    address: '1 Marina Blvd',
    city: 'Singapore',
    latitude: 1.2843,
    longitude: 103.8511,
    category: 'restaurant',
  ),
  startsAt: DateTime(2026, 6, 1, 18),
  endsAt: DateTime(2026, 6, 1, 21),
  capacity: 10,
  category: EventCategory.drinks,
  costNotes: null,
  approvalMode: 'auto',
  status: 'published',
  createdAt: DateTime(2026, 5, 1),
  hostIsVerified: false,
);

/// Builds a [ProviderContainer] with [DiscoverController] wired up, using
/// the provided mocks as overrides. Calls [addTearDown] automatically.
///
/// The [discoverControllerProvider] is read eagerly so that [DiscoverController.build]
/// runs synchronously and schedules the initial [_fetchFirstPage] microtask.
/// Callers must still `await _pump()` to let the async fetch complete.
ProviderContainer _makeContainer({
  required MockBrowseEventsUseCase useCase,
  required MockLocationService locationService,

  /// Supply a pre-seeded [DiscoverFiltersActive] to simulate active filters.
  DiscoverFiltersActive? initialFilters,
}) {
  final container = ProviderContainer(
    overrides: [
      browseEventsUseCaseProvider.overrideWithValue(useCase),
      locationServiceProvider.overrideWithValue(locationService),
      // Override debouncedFiltersProvider with a stream that never emits —
      // tests exercise the initial fetch path via build(); filter-change tests
      // drive the controller directly by calling _fetchFirstPage indirectly
      // through refresh().
      debouncedFiltersProvider.overrideWith((ref) => const Stream.empty()),
      if (initialFilters != null)
        discoverFilterControllerProvider.overrideWith(
          () => _FixedFilterController(initialFilters),
        ),
    ],
  );
  addTearDown(container.dispose);

  // Eagerly read the provider so that DiscoverController.build() runs and
  // schedules the initial _fetchFirstPage. Without this read, the provider is
  // lazy and the scheduled microtask never fires before the first _pump() call.
  container.read(discoverControllerProvider);

  return container;
}

/// A [DiscoverFilterController] subclass that returns a fixed [DiscoverFiltersActive].
/// Used to simulate non-default filter state without touching D1 internals.
class _FixedFilterController extends DiscoverFilterController {
  _FixedFilterController(this._fixed);
  final DiscoverFiltersActive _fixed;

  @override
  DiscoverFilterState build() {
    ref.onDispose(() {});
    return _fixed;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBrowseEventsParams());
  });

  late MockBrowseEventsUseCase useCase;
  late MockLocationService locationService;

  setUp(() {
    useCase = MockBrowseEventsUseCase();
    locationService = MockLocationService();

    // Default: location unavailable — most tests don't use the distance filter.
    when(() => locationService.currentPosition()).thenAnswer((_) async => null);
    when(
      () => locationService.currentPermissionStatus(),
    ).thenAnswer((_) async => LocationPermissionStatus.denied);
  });

  // ---------------------------------------------------------------------------
  // Initial load
  // ---------------------------------------------------------------------------

  group('initial load', () {
    test(
      'build() emits DiscoverLoading then DiscoverLoaded on success',
      () async {
        final page = EventPage(
          events: [_makeEvent('e1'), _makeEvent('e2')],
          nextCursor: 'cursor-1',
        );
        when(() => useCase(any())).thenAnswer((_) async => Right(page));

        final container = _makeContainer(
          useCase: useCase,
          locationService: locationService,
        );

        // Immediately after construction the controller starts in DiscoverLoading.
        expect(
          container.read(discoverControllerProvider),
          isA<DiscoverLoading>(),
        );

        // Allow the async fetch to complete.
        await _pump();

        final state = container.read(discoverControllerProvider);
        expect(state, isA<DiscoverLoaded>());
        final loaded = state as DiscoverLoaded;
        expect(loaded.events, hasLength(2));
        expect(loaded.events.first.id, 'e1');
        expect(loaded.nextCursor, 'cursor-1');
        expect(loaded.isLoadingMore, isFalse);
        expect(loaded.distanceFilterDropped, isFalse);
      },
    );

    test('use case failure transitions to DiscoverError', () async {
      when(
        () => useCase(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('no network')));

      final container = _makeContainer(
        useCase: useCase,
        locationService: locationService,
      );

      await _pump();

      final state = container.read(discoverControllerProvider);
      expect(state, isA<DiscoverError>());
      final error = state as DiscoverError;
      expect(error.failure, isA<NetworkFailure>());
    });

    test(
      'empty result + default filters → DiscoverEmpty(noEventsInArea)',
      () async {
        final page = const EventPage(events: [], nextCursor: null);
        when(() => useCase(any())).thenAnswer((_) async => Right(page));

        final container = _makeContainer(
          useCase: useCase,
          locationService: locationService,
          // No initialFilters override → uses default DiscoverFiltersActive().
        );

        await _pump();

        final state = container.read(discoverControllerProvider);
        expect(state, isA<DiscoverEmpty>());
        expect(
          (state as DiscoverEmpty).reason,
          DiscoverEmptyReason.noEventsInArea,
        );
      },
    );

    test(
      'empty result + non-default filters → DiscoverEmpty(noEventsMatchFilters)',
      () async {
        final page = const EventPage(events: [], nextCursor: null);
        when(() => useCase(any())).thenAnswer((_) async => Right(page));

        final container = _makeContainer(
          useCase: useCase,
          locationService: locationService,
          initialFilters: const DiscoverFiltersActive(
            timeWindow: TimeWindow.tonight,
          ),
        );

        await _pump();

        final state = container.read(discoverControllerProvider);
        expect(state, isA<DiscoverEmpty>());
        expect(
          (state as DiscoverEmpty).reason,
          DiscoverEmptyReason.noEventsMatchFilters,
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // refresh() — acts as the full-refetch path (also used by filter changes)
  // ---------------------------------------------------------------------------

  group('refresh()', () {
    test('refresh() resets cursor and re-fetches from first page', () async {
      final firstPage = EventPage(
        events: [_makeEvent('e1')],
        nextCursor: 'cursor-1',
      );
      final refreshPage = EventPage(
        events: [_makeEvent('e2')],
        nextCursor: null,
      );
      // First call returns firstPage, subsequent calls return refreshPage.
      var callCount = 0;
      when(() => useCase(any())).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? Right(firstPage) : Right(refreshPage);
      });

      final container = _makeContainer(
        useCase: useCase,
        locationService: locationService,
      );
      await _pump();

      // Verify loaded state before refresh.
      expect(container.read(discoverControllerProvider), isA<DiscoverLoaded>());

      await container.read(discoverControllerProvider.notifier).refresh();

      final state = container.read(discoverControllerProvider);
      expect(state, isA<DiscoverLoaded>());
      final loaded = state as DiscoverLoaded;
      // Must contain only the refresh result, not the accumulated first page.
      expect(loaded.events, hasLength(1));
      expect(loaded.events.first.id, 'e2');
      expect(loaded.nextCursor, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // loadMore()
  // ---------------------------------------------------------------------------

  group('loadMore()', () {
    test('loadMore() appends events and updates nextCursor', () async {
      final firstPage = EventPage(
        events: [_makeEvent('e1'), _makeEvent('e2')],
        nextCursor: 'cursor-1',
      );
      final secondPage = EventPage(
        events: [_makeEvent('e3')],
        nextCursor: 'cursor-2',
      );
      var callCount = 0;
      when(() => useCase(any())).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? Right(firstPage) : Right(secondPage);
      });

      final container = _makeContainer(
        useCase: useCase,
        locationService: locationService,
      );
      await _pump();

      // First page loaded.
      expect(
        (container.read(discoverControllerProvider) as DiscoverLoaded).events,
        hasLength(2),
      );

      await container.read(discoverControllerProvider.notifier).loadMore();

      final state =
          container.read(discoverControllerProvider) as DiscoverLoaded;
      expect(state.events, hasLength(3));
      expect(
        state.events.map((e) => e.id),
        containsAllInOrder(['e1', 'e2', 'e3']),
      );
      expect(state.nextCursor, 'cursor-2');
      expect(state.isLoadingMore, isFalse);
    });

    test('loadMore() is a no-op when nextCursor is null', () async {
      final page = EventPage(
        events: [_makeEvent('e1')],
        nextCursor: null, // end of stream
      );
      when(() => useCase(any())).thenAnswer((_) async => Right(page));

      final container = _makeContainer(
        useCase: useCase,
        locationService: locationService,
      );
      await _pump();

      // loadMore should not call the use case again.
      await container.read(discoverControllerProvider.notifier).loadMore();

      // Use case called exactly once (the initial fetch).
      verify(() => useCase(any())).called(1);
    });

    test('loadMore() is a no-op when state is not DiscoverLoaded', () async {
      // Use case never returns — keeps the controller in DiscoverLoading.
      when(
        () => useCase(any()),
      ).thenAnswer((_) => Completer<Either<Failure, EventPage>>().future);

      final container = _makeContainer(
        useCase: useCase,
        locationService: locationService,
      );

      // Trigger the controller to initialise and call the use case.
      // The use case will hang (Completer never resolves), leaving the
      // state as DiscoverLoading.
      container.read(discoverControllerProvider);
      // Pump enough to let the Future(() => _fetchFirstPage) callback run
      // and call the use case (but NOT complete it).
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(discoverControllerProvider),
        isA<DiscoverLoading>(),
      );

      // loadMore() must be a no-op — state is DiscoverLoading.
      await container.read(discoverControllerProvider.notifier).loadMore();

      // Use case called exactly once (the initial build fetch only).
      verify(() => useCase(any())).called(1);
    });

    test(
      'loadMore() failure preserves existing events and sets paginationError',
      () async {
        final firstPage = EventPage(
          events: [_makeEvent('e1'), _makeEvent('e2')],
          nextCursor: 'cursor-1',
        );
        var callCount = 0;
        when(() => useCase(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return Right(firstPage);
          // Second call (loadMore) returns a failure.
          return const Left(NetworkFailure('no network'));
        });

        final container = _makeContainer(
          useCase: useCase,
          locationService: locationService,
        );
        await _pump();

        // Verify first page loaded successfully.
        final loaded =
            container.read(discoverControllerProvider) as DiscoverLoaded;
        expect(loaded.events, hasLength(2));

        await container.read(discoverControllerProvider.notifier).loadMore();

        final state = container.read(discoverControllerProvider);
        // State must remain DiscoverLoaded — not DiscoverError.
        expect(state, isA<DiscoverLoaded>());
        final postFailure = state as DiscoverLoaded;
        // Original events must be intact.
        expect(
          postFailure.events.map((e) => e.id),
          containsAllInOrder(['e1', 'e2']),
        );
        // isLoadingMore must be reset.
        expect(postFailure.isLoadingMore, isFalse);
        // paginationError must carry the failure.
        expect(postFailure.paginationError, isA<NetworkFailure>());
      },
    );

    test('loadMore() is a no-op when isLoadingMore is already true', () async {
      final firstPage = EventPage(
        events: [_makeEvent('e1')],
        nextCursor: 'cursor-1',
      );

      // The second use-case call (for loadMore) hangs indefinitely, simulating
      // an in-flight request.
      var callCount = 0;
      when(() => useCase(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return Right(firstPage);
        // Never completes — simulates in-flight loadMore.
        return Completer<Either<Failure, EventPage>>().future;
      });

      final container = _makeContainer(
        useCase: useCase,
        locationService: locationService,
      );
      // Wait for the initial fetch to complete (callCount == 1).
      await _pump();

      expect(callCount, 1);
      expect(container.read(discoverControllerProvider), isA<DiscoverLoaded>());

      // Fire the first loadMore without awaiting — it will call the use case
      // (callCount becomes 2) and set isLoadingMore=true, then hang.
      unawaited(container.read(discoverControllerProvider.notifier).loadMore());

      // Pump to let the first loadMore reach the use case call + set
      // isLoadingMore=true on the state.
      await _pump();

      final loadingMoreState =
          container.read(discoverControllerProvider) as DiscoverLoaded;
      expect(loadingMoreState.isLoadingMore, isTrue);

      // Second loadMore call — must be a no-op because isLoadingMore is true.
      await container.read(discoverControllerProvider.notifier).loadMore();

      // Use case called exactly twice: initial + first loadMore only.
      expect(callCount, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Distance filter + location coordination
  // ---------------------------------------------------------------------------

  group('distance filter + location', () {
    test(
      'distance filter active + location returns null → '
      'distance filter dropped, distanceFilterDropped=true on state',
      () async {
        // Location unavailable.
        when(
          () => locationService.currentPosition(),
        ).thenAnswer((_) async => null);

        final page = EventPage(events: [_makeEvent('e1')], nextCursor: null);

        DiscoverFilters? capturedFilters;
        when(() => useCase(any())).thenAnswer((invocation) async {
          capturedFilters =
              (invocation.positionalArguments.first as BrowseEventsParams)
                  .filters;
          return Right(page);
        });

        final container = _makeContainer(
          useCase: useCase,
          locationService: locationService,
          initialFilters: const DiscoverFiltersActive(maxDistanceKm: 5.0),
        );

        await _pump();

        final state = container.read(discoverControllerProvider);
        expect(state, isA<DiscoverLoaded>());

        final loaded = state as DiscoverLoaded;
        expect(loaded.distanceFilterDropped, isTrue);

        // The use case must have been called WITHOUT the distance filter.
        expect(capturedFilters, isNotNull);
        expect(capturedFilters!.maxDistanceKm, isNull);
        expect(capturedFilters!.lat, isNull);
        expect(capturedFilters!.lng, isNull);
      },
    );

    test('distance filter active + location returns position → '
        'use case called with lat/lng set', () async {
      when(
        () => locationService.currentPosition(),
      ).thenAnswer((_) async => const LatLng(1.3, 103.8));

      final page = EventPage(events: [_makeEvent('e1')], nextCursor: null);

      DiscoverFilters? capturedFilters;
      when(() => useCase(any())).thenAnswer((invocation) async {
        capturedFilters =
            (invocation.positionalArguments.first as BrowseEventsParams)
                .filters;
        return Right(page);
      });

      final container = _makeContainer(
        useCase: useCase,
        locationService: locationService,
        initialFilters: const DiscoverFiltersActive(maxDistanceKm: 5.0),
      );

      await _pump();

      final state =
          container.read(discoverControllerProvider) as DiscoverLoaded;
      expect(state.distanceFilterDropped, isFalse);

      expect(capturedFilters!.maxDistanceKm, 5.0);
      expect(capturedFilters!.lat, closeTo(1.3, 0.0001));
      expect(capturedFilters!.lng, closeTo(103.8, 0.0001));
    });
  });

  // ---------------------------------------------------------------------------
  // Filter change (simulated via refresh())
  // ---------------------------------------------------------------------------

  group('filter change resets cursor', () {
    test('refresh() after loadMore re-fetches from cursor=null '
        'and replaces accumulated events', () async {
      final firstPage = EventPage(
        events: [_makeEvent('e1'), _makeEvent('e2')],
        nextCursor: 'cursor-1',
      );
      final secondPage = EventPage(
        events: [_makeEvent('e3')],
        nextCursor: 'cursor-2',
      );
      final refreshPage = EventPage(
        events: [_makeEvent('e4')],
        nextCursor: null,
      );

      var callCount = 0;
      when(() => useCase(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return Right(firstPage);
        if (callCount == 2) return Right(secondPage);
        return Right(refreshPage);
      });

      final container = _makeContainer(
        useCase: useCase,
        locationService: locationService,
      );
      await _pump();

      await container.read(discoverControllerProvider.notifier).loadMore();

      // Should have 3 events accumulated.
      expect(
        (container.read(discoverControllerProvider) as DiscoverLoaded).events,
        hasLength(3),
      );

      // Simulate a filter change triggering a full refresh.
      await container.read(discoverControllerProvider.notifier).refresh();

      final state =
          container.read(discoverControllerProvider) as DiscoverLoaded;
      // refresh() MUST reset to only the new first page (not accumulated).
      expect(state.events, hasLength(1));
      expect(state.events.first.id, 'e4');
      expect(state.nextCursor, isNull);
    });
  });
}
