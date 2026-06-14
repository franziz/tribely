// Widget tests for KeyboardDismissBar.
//
// Covers:
//   1. Renders "Done" text.
//   2. Tapping the bar invokes onDismiss exactly once.
//
// No pumpAndSettle — this widget has no animations or async behaviour.
// No providers — this widget is stateless and owns no Riverpod state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/events/presentation/widgets/keyboard_dismiss_bar.dart';

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpBar(
  WidgetTester tester, {
  required VoidCallback onDismiss,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: KeyboardDismissBar(onDismiss: onDismiss),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('KeyboardDismissBar', () {
    // -----------------------------------------------------------------------
    // 1. Renders "Done" text
    // -----------------------------------------------------------------------
    testWidgets('renders "Done" label', (tester) async {
      await _pumpBar(tester, onDismiss: () {});

      expect(find.text('Done'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. Tapping invokes onDismiss exactly once
    // -----------------------------------------------------------------------
    testWidgets('tapping the bar invokes onDismiss exactly once', (
      tester,
    ) async {
      var callCount = 0;

      await _pumpBar(tester, onDismiss: () => callCount++);

      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(callCount, equals(1));
    });
  });
}
