// Widget tests for VerificationRejectedSheet.
//
// Covers:
//   1. Renders title + body for non-locked state.
//   2. Renders lock icon + lockout body for locked state.
//   3. Warning icon shown for non-locked, lock icon for locked.
//   4. "See what to do next" CTA invokes onViewDetails and dismisses sheet.
//   5. "Contact support" CTA shown when isLocked.
//   6. Semantics live-region label is present.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/users/domain/value_objects/selfie_failure_category.dart';
import 'package:tribely/src/features/users/presentation/string_assets/verification_failure_copy.dart';
import 'package:tribely/src/features/users/presentation/widgets/verification_rejected_sheet.dart';

Widget _wrapSheet(Widget sheet) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => sheet,
        ),
        child: const Text('Open'),
      ),
    ),
  ),
);

Future<void> _openSheet(WidgetTester tester, Widget sheet) async {
  await tester.pumpWidget(_wrapSheet(sheet));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  group('VerificationRejectedSheet', () {
    testWidgets('1. Non-locked: renders title + body', (tester) async {
      await _openSheet(
        tester,
        VerificationRejectedSheet(
          category: SelfieFailureCategory.poorLighting,
          attemptCount: 1,
          isLocked: false,
          onViewDetails: () {},
        ),
      );

      expect(
        find.text(verificationFailureTitle(SelfieFailureCategory.poorLighting)),
        findsOneWidget,
      );
      expect(find.textContaining('dark'), findsWidgets);
    });

    testWidgets('2. Locked: renders lockout body', (tester) async {
      await _openSheet(
        tester,
        VerificationRejectedSheet(
          category: SelfieFailureCategory.faceNotVisible,
          attemptCount: 3,
          isLocked: true,
          onViewDetails: () {},
        ),
      );

      expect(find.textContaining('24 hours'), findsWidgets);
    });

    testWidgets('3a. Non-locked: warning icon shown', (tester) async {
      await _openSheet(
        tester,
        VerificationRejectedSheet(
          category: SelfieFailureCategory.qualityTooLow,
          attemptCount: 2,
          isLocked: false,
          onViewDetails: () {},
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('3b. Locked: lock icon shown', (tester) async {
      await _openSheet(
        tester,
        VerificationRejectedSheet(
          category: null,
          attemptCount: 3,
          isLocked: true,
          onViewDetails: () {},
        ),
      );

      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('4. "See what to do next" CTA invokes onViewDetails', (
      tester,
    ) async {
      var detailsTapped = false;
      await _openSheet(
        tester,
        VerificationRejectedSheet(
          category: SelfieFailureCategory.other,
          attemptCount: 1,
          isLocked: false,
          onViewDetails: () => detailsTapped = true,
        ),
      );

      await tester.tap(find.text('See what to do next'));
      await tester.pumpAndSettle();

      expect(detailsTapped, isTrue);
    });

    testWidgets('5. Locked: "Contact support" CTA shown', (tester) async {
      await _openSheet(
        tester,
        VerificationRejectedSheet(
          category: SelfieFailureCategory.poorLighting,
          attemptCount: 3,
          isLocked: true,
          onViewDetails: () {},
        ),
      );

      expect(find.text('Contact support'), findsOneWidget);
    });

    testWidgets('6. Semantics live-region label present', (tester) async {
      await _openSheet(
        tester,
        VerificationRejectedSheet(
          category: SelfieFailureCategory.poorLighting,
          attemptCount: 1,
          isLocked: false,
          onViewDetails: () {},
        ),
      );

      final allSemantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final hasLiveRegion = allSemantics.any(
        (s) => s.properties.liveRegion == true,
      );
      expect(
        hasLiveRegion,
        isTrue,
        reason: 'Sheet must include a liveRegion Semantics node',
      );
    });
  });
}
