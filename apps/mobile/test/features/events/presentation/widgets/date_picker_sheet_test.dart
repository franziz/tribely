// Widget tests for DatePickerSheet.
//
// Covers:
//   1. CupertinoDatePicker is present and pre-selected to the initial date.
//   2. Tapping "Confirm date" pops the sheet with the selected date.
//   3. Tapping "Cancel" pops the sheet with null.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/events/presentation/widgets/date_picker_sheet.dart';

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

/// Pumps [DatePickerSheet] inline (not as a modal) for simple render/action
/// assertions that don't require a full bottom-sheet route.
Future<void> _pumpSheet(
  WidgetTester tester, {
  required DateTime initial,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DatePickerSheet(initial: initial)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DatePickerSheet', () {
    // -------------------------------------------------------------------------
    // Structural / render tests
    // -------------------------------------------------------------------------
    testWidgets('renders "Pick a date" headline', (tester) async {
      await _pumpSheet(
        tester,
        initial: DateTime.now().add(const Duration(days: 1)),
      );
      expect(find.text('Pick a date'), findsOneWidget);
    });

    testWidgets('renders "Confirm date" button', (tester) async {
      await _pumpSheet(
        tester,
        initial: DateTime.now().add(const Duration(days: 1)),
      );
      expect(find.text('Confirm date'), findsOneWidget);
    });

    testWidgets('renders "Cancel" button', (tester) async {
      await _pumpSheet(
        tester,
        initial: DateTime.now().add(const Duration(days: 1)),
      );
      expect(find.text('Cancel'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 1. CupertinoDatePicker is present (pre-selected to initial)
    // -------------------------------------------------------------------------
    testWidgets('renders a CupertinoDatePicker', (tester) async {
      await _pumpSheet(
        tester,
        initial: DateTime.now().add(const Duration(days: 1)),
      );
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
    });

    testWidgets('CupertinoDatePicker is in date-only mode', (tester) async {
      await _pumpSheet(
        tester,
        initial: DateTime.now().add(const Duration(days: 1)),
      );

      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.mode, CupertinoDatePickerMode.date);
    });

    // -------------------------------------------------------------------------
    // 2. "Confirm date" pops with selected date
    // -------------------------------------------------------------------------
    testWidgets('tapping "Confirm date" pops the sheet with initial date', (
      tester,
    ) async {
      final initial = DateTime.now().add(const Duration(days: 1));
      DateTime? poppedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  poppedResult = await Navigator.push<DateTime?>(
                    context,
                    MaterialPageRoute<DateTime?>(
                      builder: (_) =>
                          Scaffold(body: DatePickerSheet(initial: initial)),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Confirm without changing the picker → should return the initial date.
      await tester.tap(find.text('Confirm date'));
      await tester.pumpAndSettle();

      // The result should be non-null and carry the initial date components.
      expect(poppedResult, isNotNull);
      expect(poppedResult!.year, initial.year);
      expect(poppedResult!.month, initial.month);
      expect(poppedResult!.day, initial.day);
    });

    // -------------------------------------------------------------------------
    // 3. "Cancel" pops the sheet with null
    // -------------------------------------------------------------------------
    testWidgets('tapping "Cancel" pops the sheet with null', (tester) async {
      DateTime? poppedResult;
      var hasPopped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  poppedResult = await Navigator.push<DateTime?>(
                    context,
                    MaterialPageRoute<DateTime?>(
                      builder: (_) => Scaffold(
                        body: DatePickerSheet(
                          initial: DateTime.now().add(const Duration(days: 1)),
                        ),
                      ),
                    ),
                  );
                  hasPopped = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(hasPopped, isTrue);
      expect(poppedResult, isNull);
    });

    // -------------------------------------------------------------------------
    // Semantics
    // -------------------------------------------------------------------------
    testWidgets('sheet root has Semantics label "Pick a date dialog"', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        initial: DateTime.now().add(const Duration(days: 1)),
      );

      expect(find.bySemanticsLabel('Pick a date dialog'), findsOneWidget);
    });
  });
}
