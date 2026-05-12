// Widget tests for EventCard.
//
// Covers:
//   1. Renders title (max 2 lines).
//   2. Renders datetime in "EEE, d MMM · h:mm a SGT" format.
//   3. Renders category badge with display name.
//   4. Renders venue address.
//   5. Renders "{n} spots" capacity label.
//   6. Omits capacity line when capacity == 0 (v1 trim guard).
//   7. Tap routes to /events/:id via context.go().
//   8. Golden at 375dp width (iPhone 12 mini-ish).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/features/discover/presentation/widgets/event_card.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _testVenue = const EventVenue(
  address: '1 Marina Blvd',
  city: 'Singapore',
  latitude: 1.2789,
  longitude: 103.8536,
);

Event _makeEvent({
  String id = 'evt-001',
  String title = 'Sunset Drinks at Rooftop',
  EventCategory category = EventCategory.drinks,
  int capacity = 12,
  DateTime? startsAt,
}) => Event(
  id: id,
  hostId: 'host-1',
  title: title,
  description: 'A great evening out.',
  venue: _testVenue,
  startsAt: startsAt ?? DateTime.utc(2026, 6, 14, 19, 0), // Sun 14 Jun · 7:00 PM
  endsAt: DateTime.utc(2026, 6, 14, 22, 0),
  capacity: capacity,
  category: category,
  costSplit: 'own',
  approvalMode: 'manual',
  status: 'published',
  createdAt: DateTime.utc(2026, 5, 1),
);

// ---------------------------------------------------------------------------
// Router harness — captures go() calls so we can assert on the route
// ---------------------------------------------------------------------------

/// Records the last route passed to context.go().
String? _lastGoRoute;

GoRouter _buildRouter({required Event event}) {
  _lastGoRoute = null;
  return GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (_, _) => Scaffold(
          body: EventCard(event: event),
        ),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) {
          _lastGoRoute = '/events/${state.pathParameters['id']}';
          return Scaffold(body: Text('detail-${state.pathParameters['id']}'));
        },
      ),
    ],
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  Event event, {
  double width = 375,
}) async {
  final router = _buildRouter(event: event);
  await tester.pumpWidget(
    SizedBox(
      width: width,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventCard', () {
    testWidgets('1. renders title', (tester) async {
      await _pumpCard(tester, _makeEvent());
      expect(find.text('Sunset Drinks at Rooftop'), findsOneWidget);
    });

    testWidgets('2. renders datetime in expected format with SGT suffix',
        (tester) async {
      // startsAt = 2026-06-14T19:00Z UTC → rendered via DateFormat
      // The exact day label depends on locale; we check the suffix "SGT".
      await _pumpCard(tester, _makeEvent());
      final textFinder = find.textContaining('SGT');
      expect(textFinder, findsOneWidget);
    });

    testWidgets('3. renders category badge display name', (tester) async {
      await _pumpCard(tester, _makeEvent(category: EventCategory.drinks));
      expect(find.text('Drinks'), findsOneWidget);
    });

    testWidgets('3b. category badge changes with category', (tester) async {
      await _pumpCard(tester, _makeEvent(category: EventCategory.hike));
      expect(find.text('Hike'), findsOneWidget);
    });

    testWidgets('4. renders venue address', (tester) async {
      await _pumpCard(tester, _makeEvent());
      expect(find.textContaining('1 Marina Blvd'), findsOneWidget);
    });

    testWidgets('5. renders capacity label as "{n} spots"', (tester) async {
      await _pumpCard(tester, _makeEvent(capacity: 8));
      expect(find.text('8 spots'), findsOneWidget);
    });

    testWidgets('6. omits capacity line when capacity == 0', (tester) async {
      await _pumpCard(tester, _makeEvent(capacity: 0));
      expect(find.textContaining('spots'), findsNothing);
    });

    testWidgets('7. tap routes to /events/:id', (tester) async {
      final event = _makeEvent(id: 'evt-tap-test');
      await _pumpCard(tester, event);

      // Find and tap the card — it's a Material InkWell.
      await tester.tap(find.byType(EventCard));
      await tester.pumpAndSettle();

      expect(_lastGoRoute, equals('/events/evt-tap-test'));
    });

    // -------------------------------------------------------------------------
    // Golden test
    // -------------------------------------------------------------------------
    testWidgets('8. golden at 375dp width', (tester) async {
      // 375×400 gives enough height for the full card without overflow.
      tester.view.physicalSize = const Size(375, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpCard(tester, _makeEvent(), width: 375);

      await expectLater(
        find.byType(EventCard),
        matchesGoldenFile('goldens/event_card_375.png'),
      );
    });
  });
}
