// Widget tests for LocationPermissionSheet.
//
// Covers:
//   1. Both CTAs ("Allow location" and "Not now...") are rendered.
//   2. Tapping "Allow location" fires [onAllow] callback.
//   3. Tapping "Not now..." fires [onDecline] callback.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/widgets/primary_button.dart';
import 'package:tribely/src/core/widgets/secondary_button.dart';
import 'package:tribely/src/features/discover/presentation/widgets/location_permission_sheet.dart';

void main() {
  group('LocationPermissionSheet', () {
    Future<void> pump(
      WidgetTester tester, {
      required VoidCallback onAllow,
      required VoidCallback onDecline,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPermissionSheet(
              onAllow: onAllow,
              onDecline: onDecline,
            ),
          ),
        ),
      );
    }

    // -----------------------------------------------------------------------
    // 1. Both CTAs are rendered
    // -----------------------------------------------------------------------
    testWidgets('renders "Allow location" primary button', (tester) async {
      await pump(tester, onAllow: () {}, onDecline: () {});

      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.text('Allow location'), findsOneWidget);
    });

    testWidgets('renders "Not now" secondary button', (tester) async {
      await pump(tester, onAllow: () {}, onDecline: () {});

      expect(find.byType(SecondaryButton), findsOneWidget);
      expect(find.text('Not now — browse all SG events'), findsOneWidget);
    });

    testWidgets('renders headline text', (tester) async {
      await pump(tester, onAllow: () {}, onDecline: () {});

      expect(find.text('Events near you'), findsOneWidget);
    });

    testWidgets('renders body copy', (tester) async {
      await pump(tester, onAllow: () {}, onDecline: () {});

      expect(
        find.text('So we can show events near you in Singapore.'),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // 2. "Allow location" fires onAllow
    // -----------------------------------------------------------------------
    testWidgets('tapping "Allow location" fires onAllow callback', (
      tester,
    ) async {
      var allowCalled = false;
      await pump(tester, onAllow: () => allowCalled = true, onDecline: () {});

      await tester.tap(find.text('Allow location'));
      await tester.pump();

      expect(allowCalled, isTrue);
    });

    // -----------------------------------------------------------------------
    // 3. "Not now" fires onDecline
    // -----------------------------------------------------------------------
    testWidgets('tapping "Not now" fires onDecline callback', (tester) async {
      var declineCalled = false;
      await pump(tester, onAllow: () {}, onDecline: () => declineCalled = true);

      await tester.tap(find.text('Not now — browse all SG events'));
      await tester.pump();

      expect(declineCalled, isTrue);
    });
  });
}
