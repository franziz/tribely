// Widget tests for ErrorState.
//
// Covers:
//   1. Renders "Couldn't load events" body text.
//   2. Renders "Retry" text link.
//   3. Tapping "Retry" calls onRetry callback.
//   4. Warning icon is rendered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/discover/presentation/widgets/error_state.dart';

Future<void> _pumpErrorState(
  WidgetTester tester, {
  required VoidCallback onRetry,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ErrorState(onRetry: onRetry),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ErrorState', () {
    testWidgets('1. renders "Couldn\'t load events"', (tester) async {
      await _pumpErrorState(tester, onRetry: () {});
      expect(find.text("Couldn't load events"), findsOneWidget);
    });

    testWidgets('2. renders "Retry" text link', (tester) async {
      await _pumpErrorState(tester, onRetry: () {});
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('3. tapping Retry calls onRetry', (tester) async {
      var retried = false;
      await _pumpErrorState(tester, onRetry: () => retried = true);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('4. renders warning icon', (tester) async {
      await _pumpErrorState(tester, onRetry: () {});
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });
  });
}
