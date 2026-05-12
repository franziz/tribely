// Widget tests for EmptyState.
//
// Covers:
//   1. noEventsMatchFilters: renders "Nothing here yet" headline.
//   2. noEventsMatchFilters: renders "Reset filters" secondary button.
//   3. noEventsMatchFilters: body copy rendered.
//   4. noEventsInArea: renders "No events in Singapore yet" headline.
//   5. noEventsInArea: renders "Create an event" primary button.
//   6. noEventsInArea: body copy rendered.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/core/widgets/primary_button.dart';
import 'package:tribely/src/core/widgets/secondary_button.dart';
import 'package:tribely/src/features/discover/presentation/widgets/empty_state.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_state.dart';

Future<void> _pumpEmptyState(
  WidgetTester tester,
  DiscoverEmptyReason reason,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              builder: (_, _) => Scaffold(
                body: EmptyState(reason: reason),
              ),
            ),
            GoRoute(
              path: '/events/new',
              builder: (_, _) =>
                  const Scaffold(body: Text('create-event-stub')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('EmptyState', () {
    group('noEventsMatchFilters', () {
      testWidgets('1. renders headline "Nothing here yet"', (tester) async {
        await _pumpEmptyState(
          tester,
          DiscoverEmptyReason.noEventsMatchFilters,
        );
        expect(find.text('Nothing here yet'), findsOneWidget);
      });

      testWidgets('2. renders SecondaryButton "Reset filters"', (
        tester,
      ) async {
        await _pumpEmptyState(
          tester,
          DiscoverEmptyReason.noEventsMatchFilters,
        );
        expect(find.byType(SecondaryButton), findsOneWidget);
        expect(find.text('Reset filters'), findsOneWidget);
      });

      testWidgets('3. renders body copy', (tester) async {
        await _pumpEmptyState(
          tester,
          DiscoverEmptyReason.noEventsMatchFilters,
        );
        expect(
          find.text('Try a different time or category.'),
          findsOneWidget,
        );
      });
    });

    group('noEventsInArea', () {
      testWidgets('4. renders headline "No events in Singapore yet"', (
        tester,
      ) async {
        await _pumpEmptyState(tester, DiscoverEmptyReason.noEventsInArea);
        expect(find.text('No events in Singapore yet'), findsOneWidget);
      });

      testWidgets('5. renders PrimaryButton "Create an event"', (
        tester,
      ) async {
        await _pumpEmptyState(tester, DiscoverEmptyReason.noEventsInArea);
        expect(find.byType(PrimaryButton), findsOneWidget);
        expect(find.text('Create an event'), findsOneWidget);
      });

      testWidgets('6. renders body copy', (tester) async {
        await _pumpEmptyState(tester, DiscoverEmptyReason.noEventsInArea);
        expect(find.text('Be the first to host something.'), findsOneWidget);
      });
    });
  });
}
