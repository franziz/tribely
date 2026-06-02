// Widget tests for VerificationSignalRow.
//
// Covers:
//   1. Chip rendered when ctaLabel != null and isCheckingStatus == false.
//   2. Spinner rendered when isCheckingStatus == true (chip absent).
//   3. No trailing element when ctaLabel == null and isCheckingStatus == false.
//   4. Tap fires onCtaTap callback.
//   5. Semantics label merged — verified-row format and actionable-row format.
//   6. isLastRow == false renders a divider; isLastRow == true does not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/design/colors.dart';
import 'package:tribely/src/features/users/presentation/widgets/verification_signal_row.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

VerificationSignalRow _makeRow({
  String label = 'Email',
  IconData icon = Icons.email_outlined,
  Color iconColor = TribelyColors.paperInkSecondary,
  String stateLabel = 'Verified',
  String? ctaLabel,
  VoidCallback? onCtaTap,
  bool isLastRow = false,
  bool isCheckingStatus = false,
}) {
  return VerificationSignalRow(
    label: label,
    icon: icon,
    iconColor: iconColor,
    stateLabel: stateLabel,
    ctaLabel: ctaLabel,
    onCtaTap: onCtaTap,
    isLastRow: isLastRow,
    isCheckingStatus: isCheckingStatus,
  );
}

void main() {
  group('VerificationSignalRow', () {
    testWidgets(
      '1. chip rendered when ctaLabel != null and isCheckingStatus == false',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_makeRow(ctaLabel: 'Verify now', isCheckingStatus: false)),
        );

        // Chip text label is rendered.
        expect(find.text('Verify now'), findsOneWidget);

        // No spinner.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      '2. spinner rendered when isCheckingStatus == true, chip absent',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_makeRow(ctaLabel: 'Check status', isCheckingStatus: true)),
        );

        // Spinner is present.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Chip label is absent (spinner replaces it).
        expect(find.text('Check status'), findsNothing);
      },
    );

    testWidgets(
      '3. no trailing element when ctaLabel == null and isCheckingStatus == false',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_makeRow(ctaLabel: null, isCheckingStatus: false)),
        );

        // No spinner.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('4. tap fires onCtaTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(_makeRow(ctaLabel: 'Verify now', onCtaTap: () => tapped = true)),
      );

      await tester.tap(find.byType(VerificationSignalRow));
      expect(tapped, isTrue);
    });

    testWidgets('5a. semantics label: verified-row format (no CTA)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_makeRow(label: 'Email', stateLabel: 'Verified', ctaLabel: null)),
      );

      // The Semantics node is present in the tree with the correct label.
      expect(find.bySemanticsLabel('Email — Verified'), findsOneWidget);
    });

    testWidgets('5b. semantics label: actionable-row format (with CTA)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _makeRow(
            label: 'Phone',
            stateLabel: 'Not started',
            ctaLabel: 'Verify now',
            onCtaTap: () {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Phone — Not started — Verify now button'),
        findsOneWidget,
      );
    });

    testWidgets('6a. isLastRow == false renders a Divider', (tester) async {
      await tester.pumpWidget(_wrap(_makeRow(isLastRow: false)));

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('6b. isLastRow == true does NOT render a Divider', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_makeRow(isLastRow: true)));

      expect(find.byType(Divider), findsNothing);
    });
  });
}
