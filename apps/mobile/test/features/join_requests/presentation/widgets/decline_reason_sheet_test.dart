// Widget tests for DeclineReasonSheet.
//
// Covers:
//   1. Renders title with requester first name.
//   2. Renders sub-copy.
//   3. Renders placeholder text in the field.
//   4. Submit button is disabled when input is empty.
//   5. Submit button is enabled after entering text.
//   6. Char counter shows "0 / 200" initially.
//   7. Char counter updates as user types.
//   8. Cancel button is present and tappable (no confirm dialog) when empty.
//   9. Cancel tapped with non-empty input shows "Abandon this note?" dialog.
//  10. Choosing "Keep Writing" in dialog keeps sheet open.
//  11. Choosing "Discard" in dialog pops the sheet.
//  12. Submit calls onSubmit with trimmed reason.
//  13. On submit failure, BannerMessage is shown and sheet stays open.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/widgets/banner_message.dart';
import 'package:tribely/src/core/widgets/primary_button.dart';
import 'package:tribely/src/features/join_requests/presentation/widgets/decline_reason_sheet.dart';

// ---------------------------------------------------------------------------
// Pump helper — pumps the sheet inside a MaterialApp/Scaffold so Navigator
// and MediaQuery are available.
// ---------------------------------------------------------------------------

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Future<String?> Function(String) onSubmit,
  String requesterDisplayName = 'Priya Sharma',
}) async {
  // Set a taller surface so the Cancel button is within the hit-test bounds.
  // DeclineReasonSheet renders a multiline text field + buttons that exceed the
  // default 800×600 test surface when laid out in a Scaffold body directly.
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(800, 900));

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(800, 900)),
      child: MaterialApp(
        home: Scaffold(
          body: DeclineReasonSheet(
            requesterDisplayName: requesterDisplayName,
            onSubmit: onSubmit,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DeclineReasonSheet', () {
    // -----------------------------------------------------------------------
    // 1. Title uses first name
    // -----------------------------------------------------------------------
    testWidgets('renders title with requester first name only', (tester) async {
      await _pumpSheet(tester, onSubmit: (_) async => null);

      expect(find.textContaining('Let Priya know why'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. Sub-copy
    // -----------------------------------------------------------------------
    testWidgets('renders sub-copy', (tester) async {
      await _pumpSheet(tester, onSubmit: (_) async => null);

      expect(
        find.textContaining('A brief, kind note goes a long way'),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // 3. Placeholder text
    // -----------------------------------------------------------------------
    testWidgets('renders placeholder in the text field', (tester) async {
      await _pumpSheet(tester, onSubmit: (_) async => null);

      expect(
        find.textContaining("I've already got a full group"),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // 4. Submit disabled when empty
    // -----------------------------------------------------------------------
    testWidgets(
      'Submit button is disabled (onPressed null) when input is empty',
      (tester) async {
        await _pumpSheet(tester, onSubmit: (_) async => null);

        final button = tester.widget<PrimaryButton>(
          find.widgetWithText(PrimaryButton, 'Send rejection'),
        );
        expect(button.onPressed, isNull);
      },
    );

    // -----------------------------------------------------------------------
    // 5. Submit enabled after typing
    // -----------------------------------------------------------------------
    testWidgets('Submit button is enabled after entering non-whitespace text', (
      tester,
    ) async {
      await _pumpSheet(tester, onSubmit: (_) async => null);

      await tester.enterText(find.byType(TextField), 'Some reason');
      await tester.pump();

      final button = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Send rejection'),
      );
      expect(button.onPressed, isNotNull);
    });

    // -----------------------------------------------------------------------
    // 6. Char counter initial state
    // -----------------------------------------------------------------------
    testWidgets('char counter shows "0 / 200" initially', (tester) async {
      await _pumpSheet(tester, onSubmit: (_) async => null);

      expect(find.text('0 / 200'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 7. Char counter updates
    // -----------------------------------------------------------------------
    testWidgets('char counter updates as user types', (tester) async {
      await _pumpSheet(tester, onSubmit: (_) async => null);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      expect(find.text('5 / 200'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 8. Cancel with empty input closes without dialog
    // -----------------------------------------------------------------------
    testWidgets('Cancel with empty input pops without showing dialog', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(800, 900));

      var popped = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 900)),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await showDeclineReasonSheet(
                      context,
                      requesterDisplayName: 'Priya Sharma',
                      onSubmit: (_) async => null,
                    );
                    popped = true;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Sheet is now open. Tap Cancel with empty field.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 9. Cancel with non-empty input shows "Abandon this note?" dialog
    // -----------------------------------------------------------------------
    testWidgets(
      'Cancel with non-empty input shows "Abandon this note?" dialog',
      (tester) async {
        await _pumpSheet(tester, onSubmit: (_) async => null);

        await tester.enterText(find.byType(TextField), 'Some reason');
        await tester.pump();

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('Abandon this note?'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 10. "Keep Writing" in dialog keeps sheet open
    // -----------------------------------------------------------------------
    testWidgets('"Keep Writing" in abandon dialog keeps sheet open', (
      tester,
    ) async {
      await _pumpSheet(tester, onSubmit: (_) async => null);

      await tester.enterText(find.byType(TextField), 'Reason text');
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Keep Writing'));
      await tester.pumpAndSettle();

      // Sheet is still visible (TextField still present).
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 11. "Discard" in dialog closes the sheet
    // -----------------------------------------------------------------------
    testWidgets('"Discard" in abandon dialog pops the sheet', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(800, 900));

      var popped = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 900)),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await showDeclineReasonSheet(
                      context,
                      requesterDisplayName: 'Priya Sharma',
                      onSubmit: (_) async => null,
                    );
                    popped = true;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Some reason');
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    // -----------------------------------------------------------------------
    // 12. Submit calls onSubmit with trimmed reason
    // -----------------------------------------------------------------------
    testWidgets('Submit calls onSubmit with trimmed text', (tester) async {
      String? submittedReason;
      await _pumpSheet(
        tester,
        onSubmit: (reason) async {
          submittedReason = reason;
          return null; // success
        },
      );

      await tester.enterText(find.byType(TextField), '  some reason  ');
      await tester.pump();

      await tester.tap(find.widgetWithText(PrimaryButton, 'Send rejection'));
      await tester.pumpAndSettle();

      expect(submittedReason, equals('some reason'));
    });

    // -----------------------------------------------------------------------
    // 13. Submit failure shows BannerMessage; sheet stays open
    // -----------------------------------------------------------------------
    testWidgets(
      'submit failure shows BannerMessage above button; sheet stays open',
      (tester) async {
        await _pumpSheet(
          tester,
          onSubmit: (_) async => 'No connection. Check your network.',
        );

        await tester.enterText(find.byType(TextField), 'A reason');
        await tester.pump();

        await tester.tap(find.widgetWithText(PrimaryButton, 'Send rejection'));
        await tester.pumpAndSettle();

        expect(find.byType(BannerMessage), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget); // sheet still open
      },
    );
  });
}
