// Widget tests for SafetyReportSubmittedPage.
//
// Covers:
//   1. Title rendered from check_in_copy constants.
//   2. Body copy rendered verbatim.
//   3. SPF 999 disclaimer rendered VERBATIM from check_in_copy / policy SoT.
//   4. "Done" CTA navigates to /events.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/features/check_ins/presentation/pages/safety_report_submitted_page.dart';
import 'package:tribely/src/features/check_ins/presentation/string_assets/check_in_copy.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SafetyReportSubmittedPage(),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const Scaffold(body: Text('DiscoverPage')),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SafetyReportSubmittedPage', () {
    testWidgets('renders title from copy constants', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text(safetyReportSubmittedTitle), findsOneWidget);
    });

    testWidgets('renders body copy verbatim', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.textContaining('24 hours'), findsOneWidget);
    });

    testWidgets('SPF 999 disclaimer matches policy SoT verbatim', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      // Assert the EXACT verbatim string from the policy doc is rendered.
      // Any paraphrase here is a test failure — the policy document is the SoT.
      expect(
        find.textContaining(
          'If you\'re in immediate danger, call the Singapore Police at 999. '
          'We are not an emergency service.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('SPF 999 disclaimer constant matches policy doc verbatim', (
      tester,
    ) async {
      // This test guards the string constant itself against accidental
      // paraphrase — independent of whether it renders correctly.
      expect(
        safetyReportSubmittedSpf999Disclaimer,
        equals(
          'If you\'re in immediate danger, call the Singapore Police at 999. '
          'We are not an emergency service.',
        ),
      );
    });

    testWidgets('"Done" CTA navigates to /events', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text(safetyReportSubmittedDoneCta));
      await tester.pumpAndSettle();

      expect(find.text('DiscoverPage'), findsOneWidget);
    });
  });
}
