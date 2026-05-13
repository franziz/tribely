// Widget tests for ConfirmJoinSheet.
//
// Covers:
//   1. Renders headline with host name and event title.
//   2. Renders body copy.
//   3. "Send request" button is enabled when idle.
//   4. Tapping "Send request" calls controller.submit().
//   5. Loading state: button enters loading, cancel disabled.
//   6. Failure state: BannerMessage appears above button.
//   7. Cancel button dismisses the sheet.
//   8. EmailNotVerifiedFailure renders correct copy.
//   9. CapacityFullFailure renders correct copy.
//  10. "Happening now" hint present when event is currently underway.
//  11. "Happening now" hint absent when event has not yet started.
//  12. "Happening now" hint absent within the 15-min buffer window.
//  13. "Happening now" hint absent when event has already ended.
//
// Mocking strategy:
//   - requestToJoinControllerProvider is overridden with _FixedRequestToJoinController
//     so the sheet renders without GetIt access.
//   - The [now] parameter on ConfirmJoinSheet is used to pin the clock in
//     tests — this is the minimal seam for time-dependent rendering without
//     introducing a Clock injection into domain/presentation code.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/widgets/banner_message.dart';
import 'package:tribely/src/core/widgets/primary_button.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/request_to_join_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/request_to_join_state.dart';
import 'package:tribely/src/features/join_requests/presentation/widgets/confirm_join_sheet.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testEventId = 'evt-test-1';
const _testHostName = 'Kai';
const _testEventTitle = 'Evening Drinks';

// ---------------------------------------------------------------------------
// Fixed-state controller helper
// ---------------------------------------------------------------------------

class _FixedRequestToJoinController extends RequestToJoinController {
  _FixedRequestToJoinController(this._state, {this.onSubmitCalled})
    : super(_testEventId);

  final RequestToJoinState _state;

  /// Invoked when [submit] is called. Test code reads this to verify side effects
  /// without exposing a mutable field on the Notifier.
  final VoidCallback? onSubmitCalled;

  @override
  RequestToJoinState build() => _state;

  @override
  Future<void> loadExisting() async {}

  @override
  Future<void> submit() async {
    onSubmitCalled?.call();
  }

  @override
  Future<void> withdraw(String joinRequestId) async {}
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

/// A fixed past time used as the default [now] in tests that do not exercise
/// the "happening now" hint — keeps existing tests deterministic.
final _defaultNow = DateTime(2025, 6, 1, 12, 0);

/// Default event timing: well in the future relative to [_defaultNow] so the
/// hint is never shown for tests that don't care about it.
final _defaultStartsAt = DateTime(2025, 6, 1, 18, 0);
final _defaultEndsAt = DateTime(2025, 6, 1, 21, 0);

Future<_FixedRequestToJoinController> _pumpSheet(
  WidgetTester tester,
  RequestToJoinState initialState, {
  VoidCallback? onSubmitCalled,
  DateTime? startsAt,
  DateTime? endsAt,
  DateTime? now,
}) async {
  final controller = _FixedRequestToJoinController(
    initialState,
    onSubmitCalled: onSubmitCalled,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requestToJoinControllerProvider(
          _testEventId,
        ).overrideWith(() => controller),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ConfirmJoinSheet(
            eventId: _testEventId,
            hostName: _testHostName,
            eventTitle: _testEventTitle,
            startsAt: startsAt ?? _defaultStartsAt,
            endsAt: endsAt ?? _defaultEndsAt,
            now: now ?? _defaultNow,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ConfirmJoinSheet', () {
    // -----------------------------------------------------------------------
    // 1. Headline with host + event title
    // -----------------------------------------------------------------------
    testWidgets('renders headline with host name and event title', (
      tester,
    ) async {
      await _pumpSheet(tester, const RequestToJoinIdle());

      expect(
        find.textContaining("Send a request to join Kai's Evening Drinks?"),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // 2. Body copy
    // -----------------------------------------------------------------------
    testWidgets('renders body copy', (tester) async {
      await _pumpSheet(tester, const RequestToJoinIdle());

      expect(
        find.textContaining(
          "They'll get a notification and can approve or decline.",
        ),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // 3. "Send request" button is enabled in idle state
    // -----------------------------------------------------------------------
    testWidgets(
      '"Send request" button is enabled (onPressed non-null) in idle',
      (tester) async {
        await _pumpSheet(tester, const RequestToJoinIdle());

        final button = tester.widget<PrimaryButton>(
          find.widgetWithText(PrimaryButton, 'Send request'),
        );
        expect(button.onPressed, isNotNull);
        expect(button.state, equals(PrimaryButtonState.idle));
      },
    );

    // -----------------------------------------------------------------------
    // 4. Tapping "Send request" calls submit()
    // -----------------------------------------------------------------------
    testWidgets('tapping "Send request" calls controller.submit()', (
      tester,
    ) async {
      var submitCalled = false;
      await _pumpSheet(
        tester,
        const RequestToJoinIdle(),
        onSubmitCalled: () => submitCalled = true,
      );

      await tester.tap(find.widgetWithText(PrimaryButton, 'Send request'));
      await tester.pump();

      expect(submitCalled, isTrue);
    });

    // -----------------------------------------------------------------------
    // 5. Loading state: button shows loading, cancel disabled
    // -----------------------------------------------------------------------
    testWidgets('submitting state: button is loading, cancel is disabled', (
      tester,
    ) async {
      await _pumpSheet(tester, const RequestToJoinSubmitting());

      // PrimaryButton.loading renders _LoadingDots, not the label text —
      // use byType to locate the button widget directly.
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.state, equals(PrimaryButtonState.loading));
      expect(button.onPressed, isNull); // disabled while submitting

      // Cancel TextButton should be disabled too.
      final cancelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(cancelButton.onPressed, isNull);
    });

    // -----------------------------------------------------------------------
    // 6. Failure state: BannerMessage appears
    // -----------------------------------------------------------------------
    testWidgets('failure state renders BannerMessage above button', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        const RequestToJoinFailed(failure: NetworkFailure('No connection')),
      );

      expect(find.byType(BannerMessage), findsOneWidget);
      expect(
        find.textContaining('No connection. Check your network and try again.'),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // 7. Cancel dismisses
    // -----------------------------------------------------------------------
    testWidgets('tapping Cancel is wired (onPressed non-null)', (tester) async {
      await _pumpSheet(tester, const RequestToJoinIdle());

      final cancelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(cancelButton.onPressed, isNotNull);
    });

    // -----------------------------------------------------------------------
    // 8. EmailNotVerifiedFailure — specific copy
    // -----------------------------------------------------------------------
    testWidgets('EmailNotVerifiedFailure renders verify-email copy', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        const RequestToJoinFailed(
          failure: EmailNotVerifiedFailure('Email not verified'),
        ),
      );

      expect(
        find.textContaining(
          'Please verify your email before requesting to join.',
        ),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // 9. CapacityFullFailure — specific copy
    // -----------------------------------------------------------------------
    testWidgets('CapacityFullFailure renders event-full copy', (tester) async {
      await _pumpSheet(
        tester,
        const RequestToJoinFailed(
          failure: CapacityFullFailure('Capacity full'),
        ),
      );

      expect(find.textContaining('This event is full.'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 10. "Happening now" hint present when event is currently underway.
    //     now is between startsAt+15min and endsAt.
    // -----------------------------------------------------------------------
    testWidgets(
      '"happening now" hint is present when event is currently underway',
      (tester) async {
        final now = DateTime(2025, 6, 1, 14, 0);
        // startsAt = now - 20min → now > startsAt + 15min ✓
        final startsAt = now.subtract(const Duration(minutes: 20));
        // endsAt = now + 1h → now < endsAt ✓
        final endsAt = now.add(const Duration(hours: 1));

        await _pumpSheet(
          tester,
          const RequestToJoinIdle(),
          startsAt: startsAt,
          endsAt: endsAt,
          now: now,
        );

        expect(
          find.textContaining(
            "$_testHostName might be on the go — they'll respond when they can.",
          ),
          findsOneWidget,
        );
      },
    );

    // -----------------------------------------------------------------------
    // 11. "Happening now" hint absent when event has not yet started.
    //     startsAt = now + 1h  (well in the future)
    // -----------------------------------------------------------------------
    testWidgets(
      '"happening now" hint is absent when event has not yet started',
      (tester) async {
        final now = DateTime(2025, 6, 1, 14, 0);
        final startsAt = now.add(const Duration(hours: 1));
        final endsAt = now.add(const Duration(hours: 3));

        await _pumpSheet(
          tester,
          const RequestToJoinIdle(),
          startsAt: startsAt,
          endsAt: endsAt,
          now: now,
        );

        expect(find.textContaining('might be on the go'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 12. "Happening now" hint absent within the 15-min buffer window.
    //     startsAt = now - 5min → now < startsAt + 15min, so hint NOT shown.
    // -----------------------------------------------------------------------
    testWidgets(
      '"happening now" hint is absent within the 15-min grace window',
      (tester) async {
        final now = DateTime(2025, 6, 1, 14, 0);
        // started 5 min ago — only 5 min into the 15-min buffer
        final startsAt = now.subtract(const Duration(minutes: 5));
        final endsAt = now.add(const Duration(hours: 1));

        await _pumpSheet(
          tester,
          const RequestToJoinIdle(),
          startsAt: startsAt,
          endsAt: endsAt,
          now: now,
        );

        expect(find.textContaining('might be on the go'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 13. "Happening now" hint absent when event has already ended.
    //     now > endsAt.
    // -----------------------------------------------------------------------
    testWidgets('"happening now" hint is absent when event has already ended', (
      tester,
    ) async {
      final now = DateTime(2025, 6, 1, 14, 0);
      final startsAt = now.subtract(const Duration(hours: 2));
      final endsAt = now.subtract(const Duration(hours: 1));

      await _pumpSheet(
        tester,
        const RequestToJoinIdle(),
        startsAt: startsAt,
        endsAt: endsAt,
        now: now,
      );

      expect(find.textContaining('might be on the go'), findsNothing);
    });
  });
}
