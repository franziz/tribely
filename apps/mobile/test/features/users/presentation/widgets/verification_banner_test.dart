// Widget tests for VerificationBanner — verified and partial states.
//
// Covers:
//   1. Verified state: shows "You're verified" copy + success token background.
//   2. Partial state: shows "Required to request" copy + neutral surface background.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/design/colors.dart';
import 'package:tribely/src/features/users/presentation/string_assets/verification_settings_copy.dart';
import 'package:tribely/src/features/users/presentation/widgets/verification_banner.dart';

Widget _wrap(Widget child, {bool dark = false}) => MaterialApp(
  theme: dark ? ThemeData.dark() : ThemeData.light(),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  group('VerificationBanner', () {
    testWidgets('1. verified state: shows verified copy + success background', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const VerificationBanner(isFullyVerified: true)),
      );

      // Verified copy is displayed.
      expect(find.text(kVerificationBannerFullyVerified), findsOneWidget);

      // Partial copy is absent.
      expect(find.text(kVerificationBannerPartial), findsNothing);

      // Leading icon is the verified icon.
      expect(find.byIcon(Icons.verified), findsOneWidget);

      // Background container uses the success soft token (light mode).
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(VerificationBanner),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, TribelyColors.paperSuccessSoft);
    });

    testWidgets('2. partial state: shows neutral copy + neutral background', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const VerificationBanner(isFullyVerified: false)),
      );

      // Neutral copy is displayed.
      expect(find.text(kVerificationBannerPartial), findsOneWidget);

      // Verified copy is absent.
      expect(find.text(kVerificationBannerFullyVerified), findsNothing);

      // Leading icon is the lock icon.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      // Background container uses the neutral surface-high token (light mode).
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(VerificationBanner),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, TribelyColors.paperSurfaceHigh);
    });
  });
}
