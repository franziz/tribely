// Widget tests for DateTimePickerField.
//
// Covers:
//   1. Trigger-row placeholder rendering when value is null.
//   2. Formatted value rendering (EEE d MMM y, h:mm a) when value is set.
//   3. Error-text rendering below the trigger row.
//   4. FocusManager.primaryFocus?.unfocus() is called on tap (verified by
//      checking the sibling TextField loses focus).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/events/presentation/widgets/date_time_picker_field.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps [DateTimePickerField] in isolation — no navigator route, so any
/// [showModalBottomSheet] call from the tap handler will be a no-op (the sheet
/// needs a navigator overlay that a basic MaterialApp doesn't set up unless we
/// navigate). This is fine because we don't test the sheet-open behaviour here
/// (those tests live in date_picker_sheet_test and time_picker_sheet_test).
Future<void> _pumpField(
  WidgetTester tester, {
  DateTime? value,
  String? errorText,
  ValueChanged<DateTime>? onPicked,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: DateTimePickerField(
            label: 'Starts at',
            value: value,
            errorText: errorText,
            onPicked: onPicked ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DateTimePickerField', () {
    // -------------------------------------------------------------------------
    // 1. Placeholder rendering when value is null
    // -------------------------------------------------------------------------
    testWidgets('renders field label "Starts at"', (tester) async {
      await _pumpField(tester);
      expect(find.text('Starts at'), findsOneWidget);
    });

    testWidgets('renders "Tap to select" placeholder when value is null', (
      tester,
    ) async {
      await _pumpField(tester);
      expect(find.text('Tap to select'), findsOneWidget);
    });

    testWidgets('renders calendar icon and chevron icon', (tester) async {
      await _pumpField(tester);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. Formatted value rendering
    // -------------------------------------------------------------------------
    testWidgets('renders formatted date-time string when value is set', (
      tester,
    ) async {
      // Thursday 14 May 2026, 7:30 PM
      final dt = DateTime(2026, 5, 14, 19, 30);
      await _pumpField(tester, value: dt);

      // Exact format: 'EEE d MMM y, h:mm a' → "Thu 14 May 2026, 7:30 PM"
      expect(find.text('Thu 14 May 2026, 7:30 PM'), findsOneWidget);
    });

    testWidgets('does not render "Tap to select" when value is set', (
      tester,
    ) async {
      final dt = DateTime(2026, 5, 14, 19, 30);
      await _pumpField(tester, value: dt);

      expect(find.text('Tap to select'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 3. Error-text rendering
    // -------------------------------------------------------------------------
    testWidgets('renders errorText below trigger row when provided', (
      tester,
    ) async {
      await _pumpField(tester, errorText: 'End time must be after start time');
      expect(find.text('End time must be after start time'), findsOneWidget);
    });

    testWidgets('does not render error text when errorText is null', (
      tester,
    ) async {
      await _pumpField(tester);
      expect(find.text('End time must be after start time'), findsNothing);
    });

    testWidgets('does not render error text when errorText is empty string', (
      tester,
    ) async {
      await _pumpField(tester, errorText: '');
      // Only the field label and placeholder should appear — no extra text.
      expect(find.text('Starts at'), findsOneWidget);
      expect(find.text('Tap to select'), findsOneWidget);
      // Empty string errorText should render nothing extra.
      expect(find.text(''), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 4. FocusManager.primaryFocus?.unfocus() is called on tap
    //
    // We verify this by: placing a TextField that takes focus, tapping the
    // DateTimePickerField trigger, and asserting the TextField is no longer
    // focused after the tap.
    // -------------------------------------------------------------------------
    testWidgets(
      'tapping trigger row clears keyboard focus from a sibling TextField',
      (tester) async {
        final focusNode = FocusNode();
        DateTime? picked;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      focusNode: focusNode,
                      decoration: const InputDecoration(hintText: 'type here'),
                    ),
                    DateTimePickerField(
                      label: 'Starts at',
                      onPicked: (dt) => picked = dt,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Give the TextField focus.
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);

        // Tap the DateTimePickerField trigger. showModalBottomSheet will throw
        // in test environment without a navigator overlay — we catch that or
        // accept the sheet not appearing; what matters is the unfocus side-effect.
        await tester.tap(find.byType(DateTimePickerField), warnIfMissed: false);
        await tester.pump();

        // Focus must have been cleared by the unfocus() call in onTap.
        expect(focusNode.hasFocus, isFalse);

        // onPicked should NOT have been called (no sheet confirmed).
        expect(picked, isNull);

        focusNode.dispose();
      },
    );
  });
}
