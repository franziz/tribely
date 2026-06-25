// Widget tests for SignInGateSheet — headline copy per intent (TRI-71 fix-now).
//
// Covers:
//   1. SignInIntentGeneral → sheet headline reads "Sign in to continue".
//   2. SignInIntentCreateEvent → sheet headline reads "Sign in to create an event".
//
// These are regression guards ensuring the exhaustive switch in _Headline
// routes each intent to the correct copy SoT constant.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/features/auth/presentation/controllers/sign_in_gate_controller.dart';
import 'package:tribely/src/features/auth/presentation/state/sign_in_gate_state.dart';
import 'package:tribely/src/features/auth/presentation/state/sign_in_intent.dart';
import 'package:tribely/src/features/auth/presentation/string_assets/sign_in_gate_copy.dart';
import 'package:tribely/src/features/auth/presentation/widgets/sign_in_gate_sheet.dart';

// ---------------------------------------------------------------------------
// Stub controller — returns idle without GetIt
// ---------------------------------------------------------------------------

class _FixedSignInGateController extends SignInGateController {
  _FixedSignInGateController(super.intent);

  @override
  SignInGateState build() => const SignInGateIdle();

  @override
  Future<void> submit({
    required String email,
    required String password,
  }) async {}
}

// ---------------------------------------------------------------------------
// Pump helper — surfaces the sheet from a minimal host scaffold
// ---------------------------------------------------------------------------

/// A stateful host widget that opens [showSignInGateSheet] on first frame.
class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.intent});

  final SignInIntent intent;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    // Schedule the sheet open after the first frame so BuildContext is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSignInGateSheet(context, intent: widget.intent);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required SignInIntent intent,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => _SheetHost(intent: intent),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const Scaffold(body: Text('Sign up stub')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        signInGateControllerProvider.overrideWith2(
          (i) => _FixedSignInGateController(i),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  // Drive the addPostFrameCallback + sheet open animation.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SignInGateSheet — headline copy per intent', () {
    // -----------------------------------------------------------------------
    // 1. SignInIntentGeneral → neutral "Sign in to continue" headline
    // -----------------------------------------------------------------------
    testWidgets(
      '1. SignInIntentGeneral → headline reads "${SignInGateCopy.generalHeadline}"',
      (tester) async {
        await _pumpSheet(tester, intent: const SignInIntentGeneral());

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text(SignInGateCopy.generalHeadline), findsOneWidget);
        // Must NOT show the create-event headline (wrong intent).
        expect(find.text(SignInGateCopy.createHeadline), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 2. SignInIntentCreateEvent → "Sign in to create an event" headline
    //
    // Regression guard ensuring that switching the tab empty-state widgets to
    // SignInIntentGeneral did NOT accidentally break the discover surface which
    // still uses SignInIntentCreateEvent.
    // -----------------------------------------------------------------------
    testWidgets(
      '2. SignInIntentCreateEvent → headline reads "${SignInGateCopy.createHeadline}"',
      (tester) async {
        await _pumpSheet(tester, intent: const SignInIntentCreateEvent());

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text(SignInGateCopy.createHeadline), findsOneWidget);
        expect(find.text(SignInGateCopy.generalHeadline), findsNothing);
      },
    );
  });
}
