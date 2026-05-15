// Widget tests for FirstEventMustBePublicModal.
//
// Covers:
//   1. Both CTAs are rendered.
//   2. Tapping "Pick a public place" pops with pickPublicPlace result.
//   3. Tapping "Cancel" pops with cancel result.
//
// Golden tests are skipped on Linux (macOS-baseline golden files would cause
// ~1–2% pixel-diff failures due to FreeType font hinting on CI).

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/events/presentation/state/create_event_state.dart';
import 'package:tribely/src/features/events/presentation/widgets/first_event_must_be_public_modal.dart';

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

/// Pumps a minimal [MaterialApp] that shows [FirstEventMustBePublicModal]
/// immediately via [showDialog]. The [resultCompleter] is completed with the
/// dialog result once the modal is dismissed.
Future<void> _pumpModal(
  WidgetTester tester, {
  required void Function(FirstEventMustBePublicModalResult) onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          // Show the dialog on the first frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirstEventMustBePublicModal.show(context).then(onResult);
          });
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ),
  );
  // Allow the postFrameCallback + showDialog to run.
  await tester.pump();
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FirstEventMustBePublicModal', () {
    // -------------------------------------------------------------------------
    // 1. Both CTAs are present
    // -------------------------------------------------------------------------
    testWidgets('renders title and both CTAs', (tester) async {
      await _pumpModal(tester, onResult: (_) {});

      expect(find.text('First event must be public'), findsOneWidget);
      expect(find.text('Pick a public place'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. "Pick a public place" → pickPublicPlace result
    // -------------------------------------------------------------------------
    testWidgets('tapping "Pick a public place" returns pickPublicPlace', (
      tester,
    ) async {
      FirstEventMustBePublicModalResult? captured;

      await _pumpModal(tester, onResult: (r) => captured = r);

      await tester.tap(find.text('Pick a public place'));
      await tester.pumpAndSettle();

      expect(captured, FirstEventMustBePublicModalResult.pickPublicPlace);
    });

    // -------------------------------------------------------------------------
    // 3. "Cancel" → cancel result
    // -------------------------------------------------------------------------
    testWidgets('tapping "Cancel" returns cancel', (tester) async {
      FirstEventMustBePublicModalResult? captured;

      await _pumpModal(tester, onResult: (r) => captured = r);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(captured, FirstEventMustBePublicModalResult.cancel);
    });

    // -------------------------------------------------------------------------
    // 4. barrierDismissible=false — tapping outside does not dismiss
    // -------------------------------------------------------------------------
    testWidgets('tapping outside the dialog does not dismiss it', (
      tester,
    ) async {
      await _pumpModal(tester, onResult: (_) {});

      // Tap well outside the dialog bounds.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // The dialog should still be present.
      expect(find.text('Pick a public place'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 5. Golden — skipped on Linux (macOS-baseline)
    // -------------------------------------------------------------------------
    testWidgets(
      'FirstEventMustBePublicModal — golden',
      skip: Platform.isLinux,
      (tester) async {
        await _pumpModal(tester, onResult: (_) {});
        // Settle all pending animations so the render tree is clean before
        // capture — required by matchesGoldenFile's !debugNeedsPaint assertion.
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(AlertDialog),
          matchesGoldenFile('goldens/first_event_must_be_public_modal.png'),
        );
      },
    );
  });
}
