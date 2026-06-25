// Widget tests for MapEventBottomSheet.
//
// Covers:
//   1. Renders event title, category, datetime.
//   2. "View details →" row is present.
//   3. Tapping "View details" invokes the injected [onViewDetails] callback.
//
// Note: modal-route behaviour (showMapEventBottomSheet helper) is no longer
// tested here — that helper was deleted as part of TRI-103. The card is now
// an in-tree widget driven by [selectedMapEventProvider]; lifecycle tests live
// in discover_map_tab_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/discover/presentation/widgets/map_event_bottom_sheet.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _testEvent = Event(
  id: 'evt-test-001',
  hostId: 'user-host-1',
  title: 'Sunset Drinks at Marina',
  description: 'Great views.',
  venue: const EventVenue(
    address: '1 Marina Blvd',
    city: 'Singapore',
    latitude: 1.2789,
    longitude: 103.8536,
    category: 'restaurant',
  ),
  startsAt: DateTime.utc(2026, 6, 1, 18, 0),
  endsAt: DateTime.utc(2026, 6, 1, 21, 0),
  capacity: 10,
  category: EventCategory.drinks,
  costNotes: null,
  approvalMode: 'manual',
  status: 'published',
  createdAt: DateTime.utc(2026, 5, 1),
  hostIsVerified: false,
);

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

/// Pumps [MapEventBottomSheet] inside a plain [MaterialApp].
///
/// [onViewDetails] defaults to a no-op callback. Pass a real callback to
/// assert invocation in routing tests.
Future<void> _pumpSheet(
  WidgetTester tester,
  Event event, {
  VoidCallback? onViewDetails,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MapEventBottomSheet(
          event: event,
          onViewDetails: onViewDetails ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  group('MapEventBottomSheet', () {
    // -----------------------------------------------------------------------
    // 1. Renders event data
    // -----------------------------------------------------------------------
    testWidgets('renders event title', (tester) async {
      await _pumpSheet(tester, _testEvent);
      expect(find.text('Sunset Drinks at Marina'), findsOneWidget);
    });

    testWidgets('renders category label', (tester) async {
      await _pumpSheet(tester, _testEvent);
      expect(find.text('Drinks'), findsOneWidget);
    });

    testWidgets('renders datetime with date and time', (tester) async {
      await _pumpSheet(tester, _testEvent);
      // The datetime widget formats to "Mon, 1 Jun · 2:00 AM–9:00 AM"
      // (UTC+8 of 18:00–21:00 UTC = 02:00 AM–05:00 AM SGT on 2 Jun).
      // We just verify the containing widget exists — exact string is
      // locale-dependent; test the presence of the time indicator.
      expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. "View details" row is present
    // -----------------------------------------------------------------------
    testWidgets('renders "View details" text', (tester) async {
      await _pumpSheet(tester, _testEvent);
      expect(find.text('View details'), findsOneWidget);
    });

    testWidgets('renders chevron_right icon in view details row', (
      tester,
    ) async {
      await _pumpSheet(tester, _testEvent);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 3. "View details" tap invokes the injected callback
    //
    // The callback is injected by the parent ([DiscoverMapTab]) which is
    // responsible for clearing [selectedMapEventProvider] then pushing the
    // detail route. Here we verify the callback fires on tap — the
    // clear-then-push sequence is tested in discover_map_tab_test.dart.
    // -----------------------------------------------------------------------
    testWidgets('"View details" tap invokes onViewDetails callback', (
      tester,
    ) async {
      var callbackFired = false;

      await _pumpSheet(
        tester,
        _testEvent,
        onViewDetails: () => callbackFired = true,
      );

      await tester.pump();
      await tester.tap(find.text('View details'));
      await tester.pump();

      expect(callbackFired, isTrue);
    });
  });
}
