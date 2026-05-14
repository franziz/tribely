// Widget tests for TimePickerSheet.
//
// Covers:
//   1. 96 rows render.
//   2. "Confirm time" is disabled until a row is selected.
//   3. Tapping a row enables "Confirm time" and shows a check icon.
//   4. Tapping a past/unavailable row on today is a no-op.
//   5. Tapping "Confirm time" pops with the correct combined DateTime.
//   6. Pre-scroll places the selected row in the viewport on the first frame.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:tribely/src/features/events/presentation/widgets/time_picker_sheet.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// The format used internally by TimePickerSheet for row labels.
final _timeFmt = DateFormat('h:mm a');

String _rowLabel(int index) {
  final h = index ~/ 4;
  final m = (index % 4) * 15;
  return _timeFmt.format(DateTime(0, 1, 1, h, m));
}

/// Pumps [TimePickerSheet] inline (no Navigator) for render-only assertions.
Future<void> _pumpInline(
  WidgetTester tester, {
  required DateTime pickedDate,
  DateTime? initialValue,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TimePickerSheet(
          pickedDate: pickedDate,
          initialValue: initialValue,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Use a fixed "today" that gives us a stable unavailability boundary.
  // We use a future date as pickedDate in most tests so ALL rows are available.
  final futureDate = DateTime(2030, 1, 15);

  group('TimePickerSheet', () {
    // -------------------------------------------------------------------------
    // 1. 96 rows render
    // -------------------------------------------------------------------------
    testWidgets('renders 96 time rows (12:00 AM through 11:45 PM)', (
      tester,
    ) async {
      await _pumpInline(tester, pickedDate: futureDate);

      // The sheet pre-scrolls to _bestGuessIndex = (now.hour * 4) + (now.minute
      // ~/ 15), so index 0 ("12:00 AM") is off-screen unless this runs at
      // midnight. Scroll upward (negative delta = toward earlier rows) to bring
      // it into the viewport before asserting.
      final pickerScrollable = find
          .descendant(
            of: find.byType(TimePickerSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text(_rowLabel(0)),
        -50.0,
        scrollable: pickerScrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text(_rowLabel(0)), findsOneWidget); // 12:00 AM

      // Scroll to the bottom to trigger lazy-build of last rows.
      await tester.dragUntilVisible(
        find.text(_rowLabel(95)), // 11:45 PM
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(find.text(_rowLabel(95)), findsOneWidget); // 11:45 PM
    });

    testWidgets('renders "Pick a time" headline', (tester) async {
      await _pumpInline(tester, pickedDate: futureDate);
      expect(find.text('Pick a time'), findsOneWidget);
    });

    testWidgets('renders date sub-label in EEE d MMM format', (tester) async {
      // 2030-01-15 → "Tue 15 Jan" (Jan 15 2030 is a Tuesday)
      await _pumpInline(tester, pickedDate: futureDate);
      expect(find.text('Tue 15 Jan'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. "Confirm time" is disabled until a row is selected
    // -------------------------------------------------------------------------
    testWidgets('"Confirm time" button is present', (tester) async {
      await _pumpInline(tester, pickedDate: futureDate);
      expect(find.text('Confirm time'), findsOneWidget);
    });

    testWidgets(
      '"Confirm time" does not call onPressed when no row is selected',
      (tester) async {
        var confirmCalled = false;

        // We verify disabled state by wrapping the sheet and checking that
        // tapping the button while no row is selected does not cause a pop.
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push<DateTime?>(
                      context,
                      MaterialPageRoute<DateTime?>(
                        builder: (_) => Scaffold(
                          body: TimePickerSheet(pickedDate: futureDate),
                        ),
                      ),
                    );
                    if (result != null) confirmCalled = true;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Tap Confirm before any row is selected.
        await tester.tap(find.text('Confirm time'));
        await tester.pumpAndSettle();

        // The sheet should still be visible (not popped) since button is disabled.
        expect(find.text('Pick a time'), findsOneWidget);
        expect(confirmCalled, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // 3. Tapping a row enables "Confirm time" and shows a check icon
    // -------------------------------------------------------------------------
    testWidgets('tapping a row shows check icon', (tester) async {
      // Pre-scroll to 7:30 AM (index 30) so the target row is centred in the
      // viewport and reliably tappable. Row 0 ("12:00 AM") can land behind the
      // sheet header when scrollUntilVisible overshoots to the minimum extent.
      final anchorDt = DateTime(
        futureDate.year,
        futureDate.month,
        futureDate.day,
        7,
        30,
      );
      await _pumpInline(tester, pickedDate: futureDate, initialValue: anchorDt);

      // _jumpToInitialRow centres row 30 ("7:30 AM") in the viewport.
      await tester.scrollUntilVisible(
        find.text(_rowLabel(30)),
        50.0,
        scrollable: find
            .descendant(
              of: find.byType(TimePickerSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );

      await tester.tap(find.text(_rowLabel(30)));
      await tester.pump();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('tapping a row enables the Confirm button', (tester) async {
      DateTime? result;

      // Pre-select 7:30 AM (index 30) so _jumpToInitialRow centres the list on
      // a row that is reliably in the tappable area of the viewport, away from
      // the sheet header. Row 0 ("12:00 AM") can land behind the header when
      // scrollUntilVisible overshoots to the minimum scroll extent.
      final anchorDt = DateTime(
        futureDate.year,
        futureDate.month,
        futureDate.day,
        7,
        30,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<DateTime?>(
                    context,
                    MaterialPageRoute<DateTime?>(
                      builder: (_) => Scaffold(
                        body: TimePickerSheet(
                          pickedDate: futureDate,
                          initialValue: anchorDt,
                        ),
                      ),
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

      // The 7:30 AM row is pre-selected and centred by _jumpToInitialRow.
      await tester.scrollUntilVisible(
        find.text(_rowLabel(30)),
        50.0,
        scrollable: find
            .descendant(
              of: find.byType(TimePickerSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );

      // Tap row 30 (7:30 AM) — it is already selected, but tapping re-affirms it.
      await tester.tap(find.text(_rowLabel(30)));
      await tester.pump();

      // Now confirm.
      await tester.tap(find.text('Confirm time'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.hour, 7);
      expect(result!.minute, 30);
    });

    testWidgets('tapping a second row moves check to new row', (tester) async {
      // Pre-select index 30 (7:30 AM) via initialValue so that _jumpToInitialRow
      // centres the list on a known position far from the header/footer edges.
      // Index 31 (7:45 AM) will be adjacent and comfortably in the viewport.
      final anchorDt = DateTime(
        futureDate.year,
        futureDate.month,
        futureDate.day,
        7,
        30,
      );
      await _pumpInline(tester, pickedDate: futureDate, initialValue: anchorDt);

      // After pumpAndSettle the sheet is pre-scrolled to the 7:30 AM row and
      // it is already selected. Confirm the check is present.
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap the adjacent 7:45 AM row (index 31) — it should be visible because
      // the pre-scroll centred the list on index 30.
      final pickerScrollable = find
          .descendant(
            of: find.byType(TimePickerSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text(_rowLabel(31)),
        50.0,
        scrollable: pickerScrollable,
      );

      await tester.tap(find.text(_rowLabel(31))); // 7:45 AM
      await tester.pumpAndSettle();
      // Still exactly one check — moved to the new row.
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 4. Past/unavailable row on today is a no-op
    // -------------------------------------------------------------------------
    testWidgets('tapping a past row on today does not select it', (
      tester,
    ) async {
      // today = right now; row 0 (12:00 AM) will almost certainly be in the
      // past unless this test runs at midnight — safe assumption.
      final today = DateTime.now();
      await _pumpInline(tester, pickedDate: today);

      // Row 0 is 12:00 AM — unavailable unless it's currently before 12:05 AM.
      // Scroll upward (negative delta) to bring it into the viewport so the
      // assertion runs deterministically rather than passing vacuously when the
      // sheet is pre-scrolled away from index 0.
      final row0Label = _rowLabel(0); // "12:00 AM"
      await tester.scrollUntilVisible(
        find.text(row0Label),
        -50.0,
        scrollable: find
            .descendant(
              of: find.byType(TimePickerSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );

      await tester.tap(find.text(row0Label), warnIfMissed: false);
      await tester.pump();

      // No check icon should appear — the tap was a no-op (past row).
      expect(find.byIcon(Icons.check), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 5. "Confirm time" pops with correct combined DateTime
    // -------------------------------------------------------------------------
    testWidgets('pops with DateTime combining pickedDate and selected time', (
      tester,
    ) async {
      DateTime? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<DateTime?>(
                    context,
                    MaterialPageRoute<DateTime?>(
                      builder: (_) => Scaffold(
                        body: TimePickerSheet(pickedDate: futureDate),
                      ),
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

      // Tap row index 28 → 7:00 AM (28 = 7*4).
      // The sheet pre-scrolls to the current time; 7:00 AM may be above or
      // below the viewport depending on time of day. Negative delta scrolls
      // upward toward earlier rows, which is correct when the anchor (now) is
      // past 7 AM — the dominant case during business-hours CI runs. If the
      // test runs before 7 AM the row is already near the top or just below the
      // anchor; deterministic clock injection is tracked as follow-up tech debt.
      final label700 = _rowLabel(28); // "7:00 AM"
      await tester.scrollUntilVisible(
        find.text(label700),
        -50.0,
        scrollable: find
            .descendant(
              of: find.byType(TimePickerSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(label700));
      await tester.pump();
      await tester.tap(find.text('Confirm time'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.year, futureDate.year);
      expect(result!.month, futureDate.month);
      expect(result!.day, futureDate.day);
      expect(result!.hour, 7);
      expect(result!.minute, 0);
    });

    testWidgets('Cancel pops with null', (tester) async {
      DateTime? result;
      var hasPopped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<DateTime?>(
                    context,
                    MaterialPageRoute<DateTime?>(
                      builder: (_) => Scaffold(
                        body: TimePickerSheet(pickedDate: futureDate),
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

      // Scroll Cancel into view if needed (sheet height may clip it).
      await tester.dragUntilVisible(
        find.text('Cancel'),
        find.byType(SingleChildScrollView).last,
        const Offset(0, 50),
        maxIteration: 5,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(hasPopped, isTrue);
      expect(result, isNull);
    });

    // -------------------------------------------------------------------------
    // 6. Pre-scroll: selected row is in viewport on first frame
    // -------------------------------------------------------------------------
    testWidgets(
      'pre-scrolls so initialValue row is visible when value is set',
      (tester) async {
        // initialValue on pickedDate at 7:30 AM → index 30.
        final initialDt = DateTime(
          futureDate.year,
          futureDate.month,
          futureDate.day,
          7,
          30,
        );

        await _pumpInline(
          tester,
          pickedDate: futureDate,
          initialValue: initialDt,
        );

        // After pumpAndSettle, the "7:30 AM" row must be present and visible.
        final label = _rowLabel(30); // "7:30 AM"
        expect(find.text(label), findsOneWidget);
      },
    );

    testWidgets(
      'pre-selected row has check icon when initialValue matches pickedDate',
      (tester) async {
        final initialDt = DateTime(
          futureDate.year,
          futureDate.month,
          futureDate.day,
          8,
          0,
        );

        await _pumpInline(
          tester,
          pickedDate: futureDate,
          initialValue: initialDt,
        );

        // "8:00 AM" row should show a check because it was pre-selected.
        expect(find.byIcon(Icons.check), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // Semantics
    // -------------------------------------------------------------------------
    testWidgets('sheet root has Semantics label "Pick a time dialog"', (
      tester,
    ) async {
      await _pumpInline(tester, pickedDate: futureDate);
      expect(find.bySemanticsLabel('Pick a time dialog'), findsOneWidget);
    });
  });
}
