// Widget tests for SupportContactPage.
//
// Covers:
//   1. Submit disabled when category unset, even with message text.
//   2. Submit disabled when message empty, even with category selected.
//   3. Disabled button shows inline hint copy (supportSubmitDisabledHint).
//   4. Submit enabled when both category and message are non-empty.
//   5. Failure response shows error banner; page stays mounted.
//   6. RateLimitedFailure shows rate-limit-specific banner copy.
//   7. Error banner is dismissible.
//   8. Deep-link prefill: reportId in URI sets category + Report ID field.
//   9. Category sheet opens on subject row tap and selection updates row label.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/support/domain/entities/support_ticket_draft.dart';
import 'package:tribely/src/features/support/domain/repositories/support_repository.dart';
import 'package:tribely/src/features/support/domain/usecases/submit_support_ticket_usecase.dart';
import 'package:tribely/src/features/support/presentation/pages/support_contact_page.dart';
import 'package:tribely/src/features/support/presentation/providers/support_providers.dart';
import 'package:tribely/src/features/support/presentation/string_assets/support_copy.dart';
import 'package:tribely/src/features/support/presentation/widgets/category_selector_sheet.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockSubmitUseCase extends Mock implements SubmitSupportTicketUseCase {}

class _FakeDraft extends Fake implements SupportTicketDraft {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [SupportContactPage] in a [MaterialApp.router] so go_router
/// context calls (GoRouterState.of, context.pushReplacement) resolve.
///
/// [path] lets tests inject a URI with query parameters.
/// [overrideUseCase] wires in the mock submit use case.
Widget _wrap({
  required _MockSubmitUseCase useCase,
  String path = '/support/contact',
}) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/support/contact',
        builder: (context, state) => const SupportContactPage(),
      ),
      GoRoute(
        path: '/support/contact/success',
        builder: (context, state) => const Scaffold(body: Text('SuccessPage')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [submitSupportTicketUseCaseProvider.overrideWithValue(useCase)],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDraft());
  });

  late _MockSubmitUseCase useCase;

  setUp(() {
    useCase = _MockSubmitUseCase();
  });

  // -------------------------------------------------------------------------
  // Enable-when-valid contract
  // -------------------------------------------------------------------------

  testWidgets('submit disabled when no category selected (message present)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(useCase: useCase));
    await tester.pump();

    // Enter a message only.
    await tester.enterText(find.byType(TextField).first, 'Please help me');
    await tester.pump();

    // Submit button must be disabled — use case must not be called.
    await tester.tap(find.text(supportSubmitCta), warnIfMissed: false);
    await tester.pump();

    verifyNever(() => useCase(any()));
  });

  testWidgets('submit disabled when message is empty (category selected)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(useCase: useCase));
    await tester.pump();

    // Open the category sheet and select a category.
    await tester.tap(find.text(supportSubjectPlaceholder));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(supportCategoryDisplayName(SupportCategory.feedback)),
    );
    await tester.pumpAndSettle();

    // Do NOT enter a message.
    await tester.tap(find.text(supportSubmitCta), warnIfMissed: false);
    await tester.pump();

    verifyNever(() => useCase(any()));
  });

  testWidgets('disabled button shows inline hint copy', (tester) async {
    await tester.pumpWidget(_wrap(useCase: useCase));
    await tester.pump();

    // Initially disabled — hint should be visible.
    expect(find.text(supportSubmitDisabledHint), findsOneWidget);
  });

  testWidgets('submit enabled when category selected and message non-empty', (
    tester,
  ) async {
    when(() => useCase(any())).thenAnswer(
      (_) async =>
          Right(SubmitResult(id: 'tk-001', createdAt: DateTime(2026, 5, 28))),
    );

    await tester.pumpWidget(_wrap(useCase: useCase));
    await tester.pump();

    // Select a category.
    await tester.tap(find.text(supportSubjectPlaceholder));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(supportCategoryDisplayName(SupportCategory.other)),
    );
    await tester.pumpAndSettle();

    // Enter a message.
    await tester.enterText(find.byType(TextField).first, 'I need help');
    await tester.pump();

    // Hint should be gone once the form is valid.
    expect(find.text(supportSubmitDisabledHint), findsNothing);

    // Tap submit.
    await tester.tap(find.text(supportSubmitCta));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    verify(() => useCase(any())).called(1);
  });

  // -------------------------------------------------------------------------
  // Error banner
  // -------------------------------------------------------------------------

  testWidgets('failure shows error banner; page stays mounted', (tester) async {
    const failure = NetworkFailure('Request failed');
    when(() => useCase(any())).thenAnswer((_) async => const Left(failure));

    await tester.pumpWidget(_wrap(useCase: useCase));
    await tester.pump();

    // Fill the form.
    await tester.tap(find.text(supportSubjectPlaceholder));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(supportCategoryDisplayName(SupportCategory.appBroken)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'App keeps crashing');
    await tester.pump();

    await tester.tap(find.text(supportSubmitCta));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Banner shows the mapped copy for NetworkFailure.
    expect(
      find.text("Couldn't reach Tribely. Check your connection."),
      findsOneWidget,
    );
    // Page is still mounted.
    expect(find.byType(SupportContactPage), findsOneWidget);
  });

  testWidgets(
    'RateLimitedFailure shows rate-limit copy (not raw failure message)',
    (tester) async {
      const failure = RateLimitedFailure('rate limited');
      when(() => useCase(any())).thenAnswer((_) async => const Left(failure));

      await tester.pumpWidget(_wrap(useCase: useCase));
      await tester.pump();

      await tester.tap(find.text(supportSubjectPlaceholder));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(supportCategoryDisplayName(SupportCategory.other)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Hello');
      await tester.pump();

      await tester.tap(find.text(supportSubmitCta));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text(supportRateLimitedBannerCopy), findsOneWidget);
    },
  );

  testWidgets('error banner dismiss clears the banner', (tester) async {
    const failure = ServerFailure('Internal error', statusCode: 500);
    when(() => useCase(any())).thenAnswer((_) async => const Left(failure));

    await tester.pumpWidget(_wrap(useCase: useCase));
    await tester.pump();

    // Fill and submit.
    await tester.tap(find.text(supportSubjectPlaceholder));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(supportCategoryDisplayName(SupportCategory.feedback)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Feedback here');
    await tester.pump();

    await tester.tap(find.text(supportSubmitCta));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      find.text("Something's off on our end. Give it a moment."),
      findsOneWidget,
    );

    // Dismiss the banner via the close icon.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(
      find.text("Something's off on our end. Give it a moment."),
      findsNothing,
    );
  });

  // -------------------------------------------------------------------------
  // Deep-link prefill
  // -------------------------------------------------------------------------

  testWidgets('deep-link reportId prefills category and Report ID field', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(useCase: useCase, path: '/support/contact?reportId=rpt-abc123'),
    );
    // Wait for post-frame callbacks to fire.
    await tester.pump();
    await tester.pump();

    // Category row should show reportFollowup7d display name.
    expect(
      find.text(supportCategoryDisplayName(SupportCategory.reportFollowup7d)),
      findsOneWidget,
    );

    // Report ID field should be prefilled.
    // The Report ID field is the second TextField (after the message field).
    final textFields = tester.widgetList<TextField>(find.byType(TextField));
    final reportIdField = textFields.elementAt(1);
    expect(reportIdField.controller?.text, 'rpt-abc123');
  });

  // -------------------------------------------------------------------------
  // Category sheet opens and selection updates label
  // -------------------------------------------------------------------------

  testWidgets(
    'tapping subject row opens sheet; selecting a category updates the row',
    (tester) async {
      await tester.pumpWidget(_wrap(useCase: useCase));
      await tester.pump();

      // Tap the subject row.
      await tester.tap(find.text(supportSubjectPlaceholder));
      await tester.pumpAndSettle();

      // Sheet is visible.
      expect(find.byType(CategorySelectorSheet), findsOneWidget);

      // Tap "Event or host concern".
      await tester.tap(
        find.text(supportCategoryDisplayName(SupportCategory.eventOrHost)),
      );
      await tester.pumpAndSettle();

      // Subject row now shows the selected category.
      expect(
        find.text(supportCategoryDisplayName(SupportCategory.eventOrHost)),
        findsOneWidget,
      );

      // Sheet is dismissed.
      expect(find.byType(CategorySelectorSheet), findsNothing);
    },
  );
}
