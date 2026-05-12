// Widget tests for DiscoverPage scaffold (D5).
//
// Covers:
//   1. IndexedStack has both DiscoverListTab and DiscoverMapTab mounted at start.
//   2. Switching selectedTab to map updates the IndexedStack index (tab switcher
//      is wired through the scaffold state).
//   3. Sticky CTA "Create event" button is visible regardless of selected tab.
//   4. Tapping the CTA navigates to '/events/new' (mocked GoRouter).
//   5. FilterChipRow is rendered above the tab content on both tabs.
//
// Mocking strategy:
//   - [discoverControllerProvider] overridden with a fixed DiscoverLoading stub.
//   - [discoverFilterControllerProvider] overridden with a fixed filter stub.
//   - [locationServiceProvider] overridden with a MockLocationService that
//     returns null position (avoids real OS dialog; camera init is manual-smoke
//     territory per §Step 8.5).
//   - GoRouter wired via [MaterialApp.router] with [GoRouter] pointing to
//     '/' → DiscoverPage, so context.push('/events/new') can be asserted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/services/location_service.dart';
import 'package:tribely/src/core/services/location_service_providers.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_controller.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_filter_controller.dart';
import 'package:tribely/src/features/discover/presentation/pages/discover_list_tab.dart';
import 'package:tribely/src/features/discover/presentation/pages/discover_map_tab.dart';
import 'package:tribely/src/features/discover/presentation/pages/discover_page.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_filter_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_map_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_providers.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_filter_state.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_state.dart';
import 'package:tribely/src/features/discover/presentation/widgets/discover_tab_switcher.dart';
import 'package:tribely/src/features/discover/presentation/widgets/filter_chip_row.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockLocationService extends Mock implements LocationService {}

// ---------------------------------------------------------------------------
// Fixed-state controllers
// ---------------------------------------------------------------------------

class _FixedDiscoverController extends DiscoverController {
  @override
  DiscoverState build() => const DiscoverLoading();

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}
}

class _FixedFilterController extends DiscoverFilterController {
  @override
  DiscoverFilterState build() => const DiscoverFiltersActive();
}

/// Fixed-state [LocationPromptShownNotifier] that always reports prompt shown
/// so widget tests skip the location rationale bottom sheet inside
/// [DiscoverMapTab].
class _PromptAlreadyShownNotifier extends LocationPromptShownNotifier {
  @override
  bool build() => true;
}

// ---------------------------------------------------------------------------
// Router + pump helper
// ---------------------------------------------------------------------------

/// Destination recorded when the CTA is tapped.
String? _lastPushedRoute;

/// Builds a [GoRouter] rooted at '/' → [DiscoverPage], with a capture route
/// for '/events/new' so the test can assert the navigation target without
/// needing a real CreateEventPage.
GoRouter _buildRouter() {
  _lastPushedRoute = null;
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const DiscoverPage()),
      GoRoute(
        path: '/events/new',
        builder: (context, state) {
          _lastPushedRoute = '/events/new';
          return const Scaffold(body: Text('Create event page'));
        },
      ),
    ],
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  MockLocationService? locationService,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final mockLocation = locationService ?? MockLocationService();
  // Default: permission denied, no position — avoids real OS dialog.
  when(
    () => mockLocation.currentPermissionStatus(),
  ).thenAnswer((_) async => LocationPermissionStatus.denied);
  when(() => mockLocation.currentPosition()).thenAnswer((_) async => null);
  when(
    () => mockLocation.requestPermission(),
  ).thenAnswer((_) async => LocationPermissionStatus.denied);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        discoverControllerProvider.overrideWith(_FixedDiscoverController.new),
        discoverFilterControllerProvider.overrideWith(
          _FixedFilterController.new,
        ),
        locationServiceProvider.overrideWithValue(mockLocation),
        // Suppress the location-rationale bottom sheet — DiscoverMapTab is
        // mounted inside the IndexedStack even when the List tab is active.
        // Without this override, _initCamera() tries to show a non-dismissable
        // modal sheet (isDismissible=false) that blocks all subsequent pump()s.
        locationPromptShownProvider.overrideWith(
          _PromptAlreadyShownNotifier.new,
        ),
      ],
      child: MaterialApp.router(routerConfig: _buildRouter()),
    ),
  );
  // Settle initial frame + any post-frame callbacks.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DiscoverPage scaffold', () {
    // -----------------------------------------------------------------------
    // 1. Both tabs are mounted inside the IndexedStack from the start.
    // -----------------------------------------------------------------------
    testWidgets(
      '1. IndexedStack has both DiscoverListTab and DiscoverMapTab mounted',
      (tester) async {
        await _pumpPage(tester);

        // Both children should be in the widget tree (IndexedStack keeps all
        // children mounted regardless of which is visible).
        // DiscoverMapTab is at index 1 (offstage when list tab is active), so
        // skipOffstage: false is required to find it.
        expect(find.byType(DiscoverListTab), findsOneWidget);
        expect(
          find.byType(DiscoverMapTab, skipOffstage: false),
          findsOneWidget,
        );

        // Verify via IndexedStack that it owns two children.
        final stack = tester.widget<IndexedStack>(
          find.byType(IndexedStack, skipOffstage: false),
        );
        expect(stack.children.length, 2);
      },
    );

    // -----------------------------------------------------------------------
    // 2. Switching tab updates IndexedStack index.
    // -----------------------------------------------------------------------
    testWidgets('2. Tapping Map segment changes IndexedStack index to 1', (
      tester,
    ) async {
      await _pumpPage(tester);

      // Initial state: List tab active → index 0.
      IndexedStack stack = tester.widget<IndexedStack>(
        find.byType(IndexedStack),
      );
      expect(stack.index, 0);

      // Tap the "Map" segment in the DiscoverTabSwitcher.
      await tester.tap(find.text('Map'));
      await tester.pump();

      stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 1);
    });

    testWidgets(
      '2b. Tapping List segment after Map changes IndexedStack index back to 0',
      (tester) async {
        await _pumpPage(tester);

        // Switch to map first.
        await tester.tap(find.text('Map'));
        await tester.pump();

        // Switch back to list.
        await tester.tap(find.text('List'));
        await tester.pump();

        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 0);
      },
    );

    // -----------------------------------------------------------------------
    // 3. Sticky CTA visible on both tabs.
    // -----------------------------------------------------------------------
    testWidgets('3a. "Create event" CTA visible on List tab', (tester) async {
      await _pumpPage(tester);

      // Default is List tab.
      expect(find.text('Create event'), findsOneWidget);
    });

    testWidgets('3b. "Create event" CTA visible on Map tab', (tester) async {
      await _pumpPage(tester);

      await tester.tap(find.text('Map'));
      await tester.pump();

      expect(find.text('Create event'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 4. Tapping the CTA routes to /events/new.
    // -----------------------------------------------------------------------
    testWidgets('4. Tapping "Create event" navigates to /events/new', (
      tester,
    ) async {
      await _pumpPage(tester);

      await tester.tap(find.text('Create event'));
      await tester.pumpAndSettle();

      expect(_lastPushedRoute, '/events/new');
      expect(find.text('Create event page'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 5. FilterChipRow visible on both tabs.
    // -----------------------------------------------------------------------
    testWidgets('5a. FilterChipRow rendered on List tab', (tester) async {
      await _pumpPage(tester);

      expect(find.byType(FilterChipRow), findsOneWidget);
    });

    testWidgets('5b. FilterChipRow rendered on Map tab', (tester) async {
      await _pumpPage(tester);

      await tester.tap(find.text('Map'));
      await tester.pump();

      expect(find.byType(FilterChipRow), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Bonus: Screen title and tab switcher are present.
    // -----------------------------------------------------------------------
    testWidgets('Screen title "Discover" is rendered', (tester) async {
      await _pumpPage(tester);

      expect(find.text('Discover'), findsOneWidget);
    });

    testWidgets('DiscoverTabSwitcher is rendered', (tester) async {
      await _pumpPage(tester);

      expect(find.byType(DiscoverTabSwitcher), findsOneWidget);
    });
  });
}
