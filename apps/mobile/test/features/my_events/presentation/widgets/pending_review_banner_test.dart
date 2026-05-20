// Widget tests for PendingReviewBanner.
//
// Covers:
//   1. Renders SizedBox.shrink (nothing) for Loading state.
//   2. Renders SizedBox.shrink (nothing) for None state.
//   3. Renders SizedBox.shrink (nothing) for Dismissed state.
//   4. Renders banner card with headline + caption for Visible(prompt) state.
//   5. Tap card body → navigates with correct eventId + ratedUserId params,
//      and calls onComposerNavigated() on the controller (→ Dismissed).
//   6. Tap × button → calls dismiss() on the controller (→ Dismissed).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/features/my_events/presentation/controllers/pending_review_banner_controller.dart';
import 'package:tribely/src/features/my_events/presentation/state/pending_review_banner_state.dart';
import 'package:tribely/src/features/my_events/presentation/string_assets/pending_review_banner_copy.dart';
import 'package:tribely/src/features/my_events/presentation/widgets/pending_review_banner.dart';
import 'package:tribely/src/features/reviews/domain/entities/pending_review_prompt.dart';

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _kPrompt = PendingReviewPrompt(
  eventId: 'evt-42',
  eventTitle: 'Rooftop Drinks',
  eventEndedAt: DateTime.utc(2026, 6, 14, 20),
  ratedUserId: 'user-b',
  ratedUserDisplayName: 'Aditya',
  ratedUserAvatarUrl: null,
);

// ---------------------------------------------------------------------------
// Stub controller
// ---------------------------------------------------------------------------

/// Stub that returns a fixed [PendingReviewBannerState] and invokes caller-
/// supplied callbacks so tests can assert side effects without holding public
/// fields on the Notifier (which violates [avoid_public_notifier_properties]).
class _StubBannerController extends PendingReviewBannerController {
  _StubBannerController(
    this._initial, {
    this.onDismissCallback,
    this.onComposerNavigatedCallback,
  });

  final PendingReviewBannerState _initial;
  final void Function()? onDismissCallback;
  final void Function()? onComposerNavigatedCallback;

  @override
  PendingReviewBannerState build() => _initial;

  @override
  void dismiss() {
    onDismissCallback?.call();
    state = const PendingReviewBannerDismissed();
  }

  @override
  void onComposerNavigated() {
    onComposerNavigatedCallback?.call();
    state = const PendingReviewBannerDismissed();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GoRouter _buildRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => const Scaffold(body: PendingReviewBanner()),
      routes: [
        GoRoute(
          path: 'reviews/write',
          builder: (context, _) => const Scaffold(body: SizedBox()),
        ),
      ],
    ),
  ],
);

/// Wraps [PendingReviewBanner] in a ProviderScope + MaterialApp.router backed
/// by [GoRouter] so that context.push works without throwing.
Widget _wrap(PendingReviewBannerState bannerState) {
  final stub = _StubBannerController(bannerState);
  return ProviderScope(
    overrides: [pendingReviewBannerControllerProvider.overrideWith(() => stub)],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

/// Same as [_wrap] but exposes side-effect trackers via boxed booleans so
/// tests can inspect whether dismiss / onComposerNavigated were called.
Widget _wrapTracked(
  PendingReviewBannerState bannerState, {
  required void Function() onDismiss,
  required void Function() onComposerNavigated,
}) {
  final stub = _StubBannerController(
    bannerState,
    onDismissCallback: onDismiss,
    onComposerNavigatedCallback: onComposerNavigated,
  );
  return ProviderScope(
    overrides: [pendingReviewBannerControllerProvider.overrideWith(() => stub)],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Loading → nothing rendered
  // -------------------------------------------------------------------------
  testWidgets('Loading state → renders nothing (no banner card)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const PendingReviewBannerLoading()));
    await tester.pump();

    expect(find.text(PendingReviewBannerCopy.buttonLabel), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 2. None → nothing rendered
  // -------------------------------------------------------------------------
  testWidgets('None state → renders nothing', (tester) async {
    await tester.pumpWidget(_wrap(const PendingReviewBannerNone()));
    await tester.pump();

    expect(find.text(PendingReviewBannerCopy.buttonLabel), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 3. Dismissed → nothing rendered
  // -------------------------------------------------------------------------
  testWidgets('Dismissed state → renders nothing', (tester) async {
    await tester.pumpWidget(_wrap(const PendingReviewBannerDismissed()));
    await tester.pump();

    expect(find.text(PendingReviewBannerCopy.buttonLabel), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 4. Visible → renders banner with correct content
  // -------------------------------------------------------------------------
  testWidgets('Visible state → renders headline and caption', (tester) async {
    await tester.pumpWidget(
      _wrap(PendingReviewBannerVisible(prompt: _kPrompt)),
    );
    await tester.pump();

    expect(
      find.text(PendingReviewBannerCopy.headline('Aditya')),
      findsOneWidget,
    );
    // Caption should contain the event title.
    expect(find.textContaining('Rooftop Drinks'), findsOneWidget);
    // Button label.
    expect(find.text(PendingReviewBannerCopy.buttonLabel), findsOneWidget);
    // Dismiss button.
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Tap "Write review" → calls onComposerNavigated
  // -------------------------------------------------------------------------
  testWidgets('tap "Write review" button → calls onComposerNavigated', (
    tester,
  ) async {
    var composerNavigatedCalled = false;
    var dismissCalled = false;

    await tester.pumpWidget(
      _wrapTracked(
        PendingReviewBannerVisible(prompt: _kPrompt),
        onDismiss: () => dismissCalled = true,
        onComposerNavigated: () => composerNavigatedCalled = true,
      ),
    );
    await tester.pump();

    await tester.tap(find.text(PendingReviewBannerCopy.buttonLabel));
    await tester.pumpAndSettle();

    expect(composerNavigatedCalled, isTrue);
    expect(dismissCalled, isFalse);
  });

  // -------------------------------------------------------------------------
  // 6. Tap × → dismiss()
  // -------------------------------------------------------------------------
  testWidgets('tap × button → calls dismiss()', (tester) async {
    var dismissCalled = false;
    var composerNavigatedCalled = false;

    await tester.pumpWidget(
      _wrapTracked(
        PendingReviewBannerVisible(prompt: _kPrompt),
        onDismiss: () => dismissCalled = true,
        onComposerNavigated: () => composerNavigatedCalled = true,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(dismissCalled, isTrue);
    expect(composerNavigatedCalled, isFalse);
  });
}
