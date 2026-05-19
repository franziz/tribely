// Widget tests for SafetyCheckInIntroSheet.
//
// Covers:
//   1. Title and body copy rendered from check_in_copy.dart constants.
//   2. Tapping "Got it" invokes onDismiss callback.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/check_ins/presentation/string_assets/check_in_copy.dart';
import 'package:tribely/src/features/check_ins/presentation/widgets/safety_check_in_intro_sheet.dart';

Widget _wrap({required VoidCallback onDismiss}) => MaterialApp(
  home: Scaffold(body: SafetyCheckInIntroSheet(onDismiss: onDismiss)),
);

void main() {
  group('SafetyCheckInIntroSheet', () {
    testWidgets('renders title from check_in_copy constants', (tester) async {
      await tester.pumpWidget(_wrap(onDismiss: () {}));
      await tester.pump();

      expect(find.text(introSheetTitle), findsOneWidget);
    });

    testWidgets('renders body from check_in_copy constants', (tester) async {
      await tester.pumpWidget(_wrap(onDismiss: () {}));
      await tester.pump();

      expect(find.textContaining('voluntary'), findsOneWidget);
    });

    testWidgets('renders "Got it" CTA', (tester) async {
      await tester.pumpWidget(_wrap(onDismiss: () {}));
      await tester.pump();

      expect(find.text(introSheetCta), findsOneWidget);
    });

    testWidgets('tapping "Got it" calls onDismiss', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(onDismiss: () => called = true));
      await tester.pump();

      await tester.tap(find.text(introSheetCta));
      await tester.pump();

      expect(called, isTrue);
    });
  });
}
