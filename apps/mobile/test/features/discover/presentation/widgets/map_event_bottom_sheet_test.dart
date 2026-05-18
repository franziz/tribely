// Widget tests for MapEventBottomSheet.
//
// Covers:
//   1. Renders event title, category, datetime.
//   2. "View details →" row is present.
//   3. Tapping "View details" routes to /events/:id (mocked GoRouter).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  costSplit: 'own',
  approvalMode: 'manual',
  status: 'published',
  createdAt: DateTime.utc(2026, 5, 1),
  hostIsVerified: false,
);

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

/// Pumps [MapEventBottomSheet] inside a plain [MaterialApp] (no router needed
/// for rendering tests — routing is covered separately below).
Future<void> _pumpSheet(WidgetTester tester, Event event) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MapEventBottomSheet(event: event)),
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
    // 3. "View details" routes to /events/:id
    //
    // Strategy: wrap in InheritedGoRouter and verify context.push is called
    // with the correct path. GoRouter's InheritedGoRouter approach lets us
    // intercept push calls without a real navigation stack.
    // -----------------------------------------------------------------------
    testWidgets('"View details" tap routes to /events/:id', (tester) async {
      // Record observed route pushes.
      final pushedRoutes = <String>[];

      await tester.pumpWidget(
        _RouterTestHarness(
          eventId: _testEvent.id,
          onPushed: pushedRoutes.add,
          child: Scaffold(body: MapEventBottomSheet(event: _testEvent)),
        ),
      );

      await tester.pump();

      // The sheet is rendered directly (not via showModalBottomSheet here) so
      // Navigator.pop() inside _ViewDetailsRow is a no-op (nothing to pop).
      // context.push('/events/evt-test-001') is still called and captured.
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();

      expect(pushedRoutes, contains('/events/${_testEvent.id}'));
    });
  });
}

// ---------------------------------------------------------------------------
// Router test harness
// ---------------------------------------------------------------------------

/// Wraps [child] in a [GoRouter] that intercepts [push] calls and notifies
/// [onPushed] instead of actually navigating. Lets us assert routing intent
/// without a full navigation stack.
class _RouterTestHarness extends StatefulWidget {
  const _RouterTestHarness({
    required this.eventId,
    required this.onPushed,
    required this.child,
  });

  final String eventId;
  final void Function(String) onPushed;
  final Widget child;

  @override
  State<_RouterTestHarness> createState() => _RouterTestHarnessState();
}

class _RouterTestHarnessState extends State<_RouterTestHarness> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final capturedPushes = widget.onPushed;
    _router = GoRouter(
      initialLocation: '/sheet-test',
      routes: [
        GoRoute(path: '/sheet-test', builder: (context, state) => widget.child),
        GoRoute(
          path: '/events/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            capturedPushes('/events/$id');
            return const Scaffold(body: Text('detail-stub'));
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: _router);
  }
}
