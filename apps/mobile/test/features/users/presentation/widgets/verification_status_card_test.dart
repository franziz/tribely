// Widget tests for VerificationStatusCard — all 4 visual states.
//
// Covers:
//   1. not_started state: renders camera icon, "Verify your selfie" label, tappable.
//   2. pending state: renders "Under review" label, NOT tappable.
//   3. failed state: renders warning icon, category body, tappable.
//   4. locked state: renders lock icon, lockout body, tappable.
//   5. approved state: renders checkmark icon, "Selfie verified", tappable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/users/domain/value_objects/selfie_failure_category.dart';
import 'package:tribely/src/features/users/presentation/state/selfie_gating_state.dart';
import 'package:tribely/src/features/users/presentation/widgets/verification_status_card.dart';
import 'package:tribely/src/features/users/presentation/string_assets/verification_failure_copy.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  group('VerificationStatusCard', () {
    testWidgets('1. not_started: renders invite copy, tappable', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          VerificationStatusCard(
            gatingState: const SelfieGatingNotStarted(),
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Verify your selfie'), findsOneWidget);
      await tester.tap(find.byType(VerificationStatusCard));
      expect(tapped, isTrue);
    });

    testWidgets('2. pending: renders "Under review", NOT tappable', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          VerificationStatusCard(
            gatingState: const SelfieGatingPending(),
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text(kPendingRowLabel), findsOneWidget);
      // Tap on the card — should NOT invoke onTap because pending is read-only.
      await tester.tap(
        find.byType(VerificationStatusCard),
        warnIfMissed: false,
      );
      expect(tapped, isFalse, reason: 'pending state must be non-interactive');
    });

    testWidgets('3. failed: renders warning icon + category body, tappable', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          VerificationStatusCard(
            gatingState: const SelfieGatingFailed(
              category: SelfieFailureCategory.poorLighting,
              attemptCount: 1,
            ),
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      // Body copy contains "dark" for poorLighting per spec.
      expect(find.textContaining('dark'), findsWidgets);
      await tester.tap(find.byType(VerificationStatusCard));
      expect(tapped, isTrue);
    });

    testWidgets('4. locked: renders lock icon + lockout body, tappable', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          VerificationStatusCard(
            gatingState: const SelfieGatingLocked(
              category: SelfieFailureCategory.faceNotVisible,
            ),
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.textContaining('24 hours'), findsWidgets);
      await tester.tap(find.byType(VerificationStatusCard));
      expect(tapped, isTrue);
    });

    testWidgets('5. approved: renders checkmark, tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          VerificationStatusCard(
            gatingState: const SelfieGatingApproved(),
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Selfie verified'), findsOneWidget);
      await tester.tap(find.byType(VerificationStatusCard));
      expect(tapped, isTrue);
    });
  });
}
