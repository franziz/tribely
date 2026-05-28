// Routing smoke test: Settings → SupportContactPage → submit → success → Done → Settings.
//
// Covers:
//   1. Settings page renders "Help & Support" tile and navigates to /support/contact.
//   2. Filling the form and submitting (mocked use case) triggers pushReplacement
//      to /support/contact/success.
//   3. "Done" on the success page navigates back to /settings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/support/domain/entities/support_ticket_draft.dart';
import 'package:tribely/src/features/support/domain/repositories/support_repository.dart';
import 'package:tribely/src/features/support/domain/usecases/submit_support_ticket_usecase.dart';
import 'package:tribely/src/features/support/presentation/pages/support_contact_page.dart';
import 'package:tribely/src/features/support/presentation/pages/support_contact_success_page.dart';
import 'package:tribely/src/features/support/presentation/providers/support_providers.dart';
import 'package:tribely/src/features/support/presentation/string_assets/support_copy.dart';
import 'package:tribely/src/features/support/presentation/widgets/category_selector_sheet.dart';
import 'package:tribely/src/features/users/presentation/pages/settings_page.dart';

// ---------------------------------------------------------------------------
// Mocks + stubs
// ---------------------------------------------------------------------------

class _MockSubmitUseCase extends Mock implements SubmitSupportTicketUseCase {}

class _FakeDraft extends Fake implements SupportTicketDraft {}

final _epoch = DateTime.utc(2020);
final _fakeUser = User(
  id: 'user-smoke-01',
  email: 'smoke@example.com',
  displayName: 'Smoke User',
  createdAt: _epoch,
  updatedAt: _epoch,
);
final _fakeSession = AuthSession(
  user: _fakeUser,
  accessToken: 'token',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'refresh',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

class _StubSessionController extends SessionController {
  @override
  SessionState build() => SessionAuthenticated(_fakeSession);

  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------------------
// Pump helper — builds the full Settings → support route sub-tree.
// ---------------------------------------------------------------------------

Widget _wrap(_MockSubmitUseCase useCase) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/settings/blocked-users',
        builder: (context, state) =>
            const Scaffold(body: Text('Blocked users page')),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) =>
            const Scaffold(body: Text('Edit profile page')),
      ),
      GoRoute(
        path: '/support/contact',
        builder: (context, state) => const SupportContactPage(),
      ),
      GoRoute(
        path: '/support/contact/success',
        builder: (context, state) => const SupportContactSuccessPage(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(() => _StubSessionController()),
      submitSupportTicketUseCaseProvider.overrideWithValue(useCase),
    ],
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

  testWidgets(
    'Settings → Help & Support → form → submit → success → Done → Settings',
    (tester) async {
      when(() => useCase(any())).thenAnswer(
        (_) async => Right(
          SubmitResult(id: 'tk-smoke-001', createdAt: DateTime(2026, 5, 28)),
        ),
      );

      await tester.pumpWidget(_wrap(useCase));
      await tester.pump();

      // Step 1: Settings page renders "Help & Support".
      expect(find.text('Help & Support'), findsOneWidget);

      // Step 2: Tap "Help & Support" → navigate to /support/contact.
      await tester.tap(find.text('Help & Support'));
      await tester.pumpAndSettle();

      expect(find.byType(SupportContactPage), findsOneWidget);

      // Step 3: Fill the form — select category.
      await tester.tap(find.text(supportSubjectPlaceholder));
      await tester.pumpAndSettle();
      expect(find.byType(CategorySelectorSheet), findsOneWidget);
      await tester.tap(
        find.text(supportCategoryDisplayName(SupportCategory.other)),
      );
      await tester.pumpAndSettle();

      // Step 4: Enter a message.
      await tester.enterText(
        find.byType(TextField).first,
        'Smoke test message',
      );
      await tester.pump();

      // Hint copy disappears when form is valid.
      expect(find.text(supportSubmitDisabledHint), findsNothing);

      // Step 5: Submit the form.
      await tester.tap(find.text(supportSubmitCta));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Step 6: Success page renders.
      expect(find.byType(SupportContactSuccessPage), findsOneWidget);
      expect(find.text(supportSuccessHeading), findsOneWidget);
      expect(find.text(supportSuccessBody), findsOneWidget);

      // Step 7: Tap "Done" → navigate back to /settings.
      await tester.tap(find.text(supportSuccessCta));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
    },
  );
}
