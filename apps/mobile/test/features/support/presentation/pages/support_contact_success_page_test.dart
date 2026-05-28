// Widget tests for SupportContactSuccessPage.
//
// Covers:
//   1. Renders check_circle_outline icon.
//   2. Renders "Message sent" heading.
//   3. Renders verbatim SLA body copy.
//   4. Renders "Done" CTA button.
//   5. Tapping "Done" navigates to /settings.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/features/support/presentation/pages/support_contact_success_page.dart';
import 'package:tribely/src/features/support/presentation/string_assets/support_copy.dart';

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Widget _wrap({String path = '/support/contact/success'}) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/support/contact/success',
        builder: (context, state) => const SupportContactSuccessPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Text('Settings page')),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SupportContactSuccessPage — renders', () {
    testWidgets('renders check_circle_outline icon', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renders "Message sent" heading', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text(supportSuccessHeading), findsOneWidget);
    });

    testWidgets('renders verbatim SLA body copy', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text(supportSuccessBody), findsOneWidget);
    });

    testWidgets('renders "Done" CTA button', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text(supportSuccessCta), findsOneWidget);
    });
  });

  group('SupportContactSuccessPage — navigation', () {
    testWidgets('tapping "Done" navigates to /settings', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text(supportSuccessCta));
      await tester.pumpAndSettle();

      expect(find.text('Settings page'), findsOneWidget);
    });

    testWidgets('ticketId in query param does not appear on screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(path: '/support/contact/success?id=tk-test-001'),
      );
      await tester.pump();

      expect(find.text('tk-test-001'), findsNothing);
    });
  });
}
