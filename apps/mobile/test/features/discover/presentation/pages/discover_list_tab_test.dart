// Widget tests for DiscoverListTab.
//
// Covers:
//   1. Loading state renders SkeletonEventCard instances (≥5).
//   2. Loaded state renders EventCard for each event.
//   3. Empty noEventsInArea renders "No events in Singapore yet".
//   4. Empty noEventsMatchFilters renders "Nothing here yet".
//   5. Error state renders "Couldn't load events" + Retry.
//   6. Error Retry button calls discoverController.refresh().
//   7. Loaded state with isLoadingMore=true shows pagination skeletons below
//      the last real card.
//   8. FilterChipRow is always rendered (regardless of DiscoverState).
//
// Mocking strategy:
//   Both discoverControllerProvider and discoverFilterControllerProvider are
//   overridden per-test via ProviderScope.overrides. No GetIt, no network.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/widgets/skeleton_loader.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_controller.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_filter_controller.dart';
import 'package:tribely/src/features/discover/presentation/pages/discover_list_tab.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_filter_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_providers.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_filter_state.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_state.dart';
import 'package:tribely/src/features/discover/presentation/widgets/event_card.dart';
import 'package:tribely/src/features/discover/presentation/widgets/filter_chip_row.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Event _makeEvent(String id) => Event(
  id: id,
  hostId: 'host-1',
  title: 'Event $id',
  description: null,
  venue: const EventVenue(
    address: '1 Marina Blvd',
    city: 'Singapore',
    latitude: 1.2789,
    longitude: 103.8536,
  ),
  startsAt: DateTime.utc(2026, 6, 14, 19, 0),
  endsAt: DateTime.utc(2026, 6, 14, 22, 0),
  capacity: 10,
  category: EventCategory.drinks,
  costSplit: 'own',
  approvalMode: 'manual',
  status: 'published',
  createdAt: DateTime.utc(2026, 5, 1),
);

final _twoEvents = [_makeEvent('e1'), _makeEvent('e2')];

// ---------------------------------------------------------------------------
// Fixed-state controllers
// ---------------------------------------------------------------------------

/// DiscoverController that immediately returns a fixed state.
class _FixedDiscoverController extends DiscoverController {
  _FixedDiscoverController(this._fixed);
  final DiscoverState _fixed;

  bool refreshCalled = false;

  @override
  DiscoverState build() => _fixed;

  @override
  Future<void> refresh() async {
    refreshCalled = true;
  }

  @override
  Future<void> loadMore() async {}
}

/// DiscoverFilterController that returns a fixed filter state without
/// starting any debounce timer.
class _FixedFilterController extends DiscoverFilterController {
  _FixedFilterController(this._fixed);
  final DiscoverFilterState _fixed;

  @override
  DiscoverFilterState build() => _fixed;
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<_FixedDiscoverController> _pumpTab(
  WidgetTester tester,
  DiscoverState discoverState, {
  DiscoverFiltersActive filterState = const DiscoverFiltersActive(),
}) async {
  // Use a large viewport so lazy ListView renders multiple items.
  tester.view.physicalSize = const Size(375, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = _FixedDiscoverController(discoverState);
  final filterController = _FixedFilterController(filterState);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        discoverControllerProvider.overrideWith(() => controller),
        discoverFilterControllerProvider.overrideWith(
          () => filterController,
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: DiscoverListTab()),
      ),
    ),
  );
  await tester.pump();

  return controller;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DiscoverListTab', () {
    // -----------------------------------------------------------------------
    // 1. Loading state
    // -----------------------------------------------------------------------
    testWidgets('1. loading state renders ≥5 SkeletonEventCard instances', (
      tester,
    ) async {
      await _pumpTab(tester, const DiscoverLoading());

      // SkeletonEventCard uses Shimmer internally — verify at least 5 are
      // present by counting SkeletonEventCard widgets.
      expect(find.byType(SkeletonEventCard), findsAtLeast(5));
    });

    testWidgets('1b. initial state also renders skeletons', (tester) async {
      await _pumpTab(tester, const DiscoverInitial());
      expect(find.byType(SkeletonEventCard), findsAtLeast(5));
    });

    // -----------------------------------------------------------------------
    // 2. Loaded state
    // -----------------------------------------------------------------------
    testWidgets('2. loaded state renders an EventCard per event', (
      tester,
    ) async {
      await _pumpTab(
        tester,
        DiscoverLoaded(events: _twoEvents, nextCursor: null),
      );

      expect(find.byType(EventCard), findsNWidgets(2));
      expect(find.text('Event e1'), findsOneWidget);
      expect(find.text('Event e2'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 3 & 4. Empty states
    // -----------------------------------------------------------------------
    testWidgets('3. noEventsInArea renders "No events in Singapore yet"', (
      tester,
    ) async {
      await _pumpTab(
        tester,
        const DiscoverEmpty(DiscoverEmptyReason.noEventsInArea),
      );
      expect(find.text('No events in Singapore yet'), findsOneWidget);
    });

    testWidgets('4. noEventsMatchFilters renders "Nothing here yet"', (
      tester,
    ) async {
      await _pumpTab(
        tester,
        const DiscoverEmpty(DiscoverEmptyReason.noEventsMatchFilters),
      );
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 5 & 6. Error state
    // -----------------------------------------------------------------------
    testWidgets('5. error state renders "Couldn\'t load events"', (
      tester,
    ) async {
      await _pumpTab(
        tester,
        const DiscoverError(ServerFailure('Network error', statusCode: 500)),
      );
      expect(find.text("Couldn't load events"), findsOneWidget);
    });

    testWidgets('6. Retry button calls controller.refresh()', (tester) async {
      final ctrl = await _pumpTab(
        tester,
        const DiscoverError(ServerFailure('Oops', statusCode: 503)),
      );

      await tester.tap(find.text('Retry'));
      expect(ctrl.refreshCalled, isTrue);
    });

    // -----------------------------------------------------------------------
    // 7. Loaded + isLoadingMore = true
    // -----------------------------------------------------------------------
    testWidgets(
        '7. isLoadingMore renders EventCards + pagination skeleton below', (
      tester,
    ) async {
      await _pumpTab(
        tester,
        DiscoverLoaded(
          events: _twoEvents,
          nextCursor: 'cursor-next',
          isLoadingMore: true,
        ),
      );

      // Real cards present.
      expect(find.byType(EventCard), findsNWidgets(2));

      // Pagination skeleton visible — SkeletonLoader (used by _PaginationSkeleton).
      expect(find.byType(SkeletonLoader), findsWidgets);
    });

    // -----------------------------------------------------------------------
    // 8. FilterChipRow always present
    // -----------------------------------------------------------------------
    testWidgets('8a. FilterChipRow rendered in loading state', (tester) async {
      await _pumpTab(tester, const DiscoverLoading());
      expect(find.byType(FilterChipRow), findsOneWidget);
    });

    testWidgets('8b. FilterChipRow rendered in loaded state', (tester) async {
      await _pumpTab(
        tester,
        DiscoverLoaded(events: _twoEvents, nextCursor: null),
      );
      expect(find.byType(FilterChipRow), findsOneWidget);
    });

    testWidgets('8c. FilterChipRow rendered in error state', (tester) async {
      await _pumpTab(
        tester,
        const DiscoverError(ServerFailure('err', statusCode: 500)),
      );
      expect(find.byType(FilterChipRow), findsOneWidget);
    });
  });
}
