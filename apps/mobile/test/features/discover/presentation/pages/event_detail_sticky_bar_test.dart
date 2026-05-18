// Widget tests for the EventDetailPage sticky bottom bar (B1a).
//
// Covers the non-host viewer CTA state matrix:
//   1. No existing request → "Request to join" button enabled
//   2. Pending request → StatusPill(Pending) + "Sent to {host}" + withdraw link
//   3. Approved request → StatusPill(Approved), no action
//   4. Declined request → StatusPill(Declined) + decisionReason caption
//   5. Withdrawn request → StatusPill(Withdrawn)
//   6. Event past (status=cancelled) → disabled CTA + "Event has ended" label
//   7. EmailNotVerifiedFailure → BannerMessage with "Verify now" link
//   8. Withdraw flow: tapping "Withdraw request" shows AlertDialog

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/widgets/primary_button.dart';
import 'package:tribely/src/core/widgets/status_pill.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/discover/presentation/controllers/event_detail_controller.dart';
import 'package:tribely/src/features/discover/presentation/pages/event_detail_page.dart';
import 'package:tribely/src/features/discover/presentation/providers/event_detail_providers.dart';
import 'package:tribely/src/features/discover/presentation/state/event_detail_state.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/request_to_join_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/request_to_join_state.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testEventId = 'evt-bar-1';

// Future event (not past)
final _testEvent = Event(
  id: _testEventId,
  hostId: 'user-host-1',
  title: 'Evening Drinks',
  description: 'Casual drinks.',
  venue: const EventVenue(
    address: '1 Orchard Rd',
    city: 'Singapore',
    latitude: 1.3,
    longitude: 103.8,
    category: 'restaurant',
  ),
  startsAt: DateTime.utc(2099, 6, 1, 18, 0),
  endsAt: DateTime.utc(2099, 6, 1, 21, 0),
  capacity: 8,
  category: EventCategory.drinks,
  costSplit: 'own',
  approvalMode: 'manual',
  status: 'published',
  createdAt: DateTime.utc(2026, 1, 1),
  hostDisplayName: 'Kai',
);

// Past event (ended)
final _pastEvent = _testEvent.copyWith(
  id: _testEventId,
  startsAt: DateTime.utc(2020, 1, 1, 18, 0),
  endsAt: DateTime.utc(2020, 1, 1, 21, 0),
  status: 'completed',
);

// Cancelled event
final _cancelledEvent = _testEvent.copyWith(status: 'cancelled');

final _pendingRequest = JoinRequest(
  id: 'jr-1',
  eventId: _testEventId,
  requesterUserId: 'user-viewer-1',
  status: JoinRequestStatus.pending,
  requestedAt: DateTime.utc(2026, 5, 1),
);

final _approvedRequest = _pendingRequest.copyWith(
  status: JoinRequestStatus.approved,
);

final _declinedRequest = _pendingRequest.copyWith(
  status: JoinRequestStatus.declined,
  decisionReason: 'Group is full for now.',
);

final _withdrawnRequest = _pendingRequest.copyWith(
  status: JoinRequestStatus.withdrawn,
);

// ---------------------------------------------------------------------------
// Fixed-state controller helpers
// ---------------------------------------------------------------------------

class _FixedEventDetailController extends EventDetailController {
  _FixedEventDetailController(this._state) : super(_testEventId);
  final EventDetailState _state;

  @override
  EventDetailState build() => _state;

  @override
  Future<void> retry() async {}
}

class _FixedRequestToJoinController extends RequestToJoinController {
  _FixedRequestToJoinController(
    this._ctaState, {
    this.onWithdrawCalled,
    this.onSubmitCalled,
  }) : super(_testEventId);

  final RequestToJoinState _ctaState;

  /// Invoked when [withdraw] is called. Test code reads this to verify side
  /// effects without exposing a mutable field on the Notifier.
  final VoidCallback? onWithdrawCalled;

  /// Invoked when [submit] is called.
  final VoidCallback? onSubmitCalled;

  @override
  RequestToJoinState build() => _ctaState;

  @override
  Future<void> loadExisting() async {}

  @override
  Future<void> submit() async {
    onSubmitCalled?.call();
  }

  @override
  Future<void> withdraw(String joinRequestId) async {
    onWithdrawCalled?.call();
  }
}

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._fixed);
  final SessionState _fixed;

  @override
  SessionState build() => _fixed;
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<_FixedRequestToJoinController> _pumpPage(
  WidgetTester tester, {
  required Event event,
  required RequestToJoinState ctaState,
  SessionState sessionState = const SessionUnauthenticated(),
  VoidCallback? onWithdrawCalled,
  VoidCallback? onSubmitCalled,
}) async {
  final controller = _FixedRequestToJoinController(
    ctaState,
    onWithdrawCalled: onWithdrawCalled,
    onSubmitCalled: onSubmitCalled,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        eventDetailControllerProvider(_testEventId).overrideWith(
          () => _FixedEventDetailController(EventDetailLoaded(event)),
        ),
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(sessionState),
        ),
        requestToJoinControllerProvider(
          _testEventId,
        ).overrideWith(() => controller),
      ],
      child: const MaterialApp(home: EventDetailPage(eventId: _testEventId)),
    ),
  );
  await tester.pump();
  return controller;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventDetailPage sticky bar state matrix (B1a)', () {
    // -----------------------------------------------------------------------
    // 1. No existing request → CTA button
    // -----------------------------------------------------------------------
    testWidgets('no request → "Request to join" button enabled', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        event: _testEvent,
        ctaState: const RequestToJoinIdle(),
      );

      expect(find.text('Request to join'), findsOneWidget);
      final button = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Request to join'),
      );
      expect(button.onPressed, isNotNull);
    });

    // -----------------------------------------------------------------------
    // 2. Pending request → pill + caption + withdraw link
    // -----------------------------------------------------------------------
    testWidgets(
      'pending request → StatusPill + "Sent to Kai" + withdraw link',
      (tester) async {
        await _pumpPage(
          tester,
          event: _testEvent,
          ctaState: RequestToJoinIdle(existingRequest: _pendingRequest),
        );

        expect(find.byType(StatusPill), findsOneWidget);
        expect(find.textContaining('Sent to Kai'), findsOneWidget);
        expect(find.text('Withdraw request'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 3. Approved request → pill, no withdraw
    // -----------------------------------------------------------------------
    testWidgets('approved request → StatusPill(approved), no withdraw link', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        event: _testEvent,
        ctaState: RequestToJoinIdle(existingRequest: _approvedRequest),
      );

      expect(find.byType(StatusPill), findsOneWidget);
      expect(find.text('Withdraw request'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 4. Declined request → pill + decisionReason
    // -----------------------------------------------------------------------
    testWidgets('declined request → StatusPill(declined) + decisionReason', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        event: _testEvent,
        ctaState: RequestToJoinIdle(existingRequest: _declinedRequest),
      );

      expect(find.byType(StatusPill), findsOneWidget);
      expect(find.textContaining('Group is full for now.'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 5. Withdrawn request (future event) → re-request CTA (TRI-28 Fix C)
    // -----------------------------------------------------------------------
    testWidgets(
      'withdrawn request (future event) → "Request to join" CTA enabled',
      (tester) async {
        await _pumpPage(
          tester,
          event: _testEvent,
          ctaState: RequestToJoinIdle(existingRequest: _withdrawnRequest),
        );

        // StatusPill must NOT be shown — we show the CTA button instead.
        expect(find.byType(StatusPill), findsNothing);
        expect(find.text('Withdraw request'), findsNothing);
        // The re-request CTA is the same affordance as never-requested.
        final button = tester.widget<PrimaryButton>(
          find.widgetWithText(PrimaryButton, 'Request to join'),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'withdrawn request (past event) → shows StatusPill, no re-request CTA',
      (tester) async {
        await _pumpPage(
          tester,
          event: _pastEvent,
          ctaState: RequestToJoinIdle(existingRequest: _withdrawnRequest),
        );

        // Past event + withdrawn → show the withdrawn pill but NOT a re-request
        // button (event is over).
        expect(find.byType(StatusPill), findsOneWidget);
        expect(find.text('Request to join'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 6. Event past → disabled CTA + inline reason
    // -----------------------------------------------------------------------
    testWidgets('past event → disabled button with "Event has ended" label', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        event: _pastEvent,
        ctaState: const RequestToJoinIdle(),
      );

      final button = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Event has ended'),
      );
      // Disabled button has null onPressed.
      expect(button.onPressed, isNull);
    });

    testWidgets('cancelled event → disabled button with "Event has ended"', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        event: _cancelledEvent,
        ctaState: const RequestToJoinIdle(),
      );

      final button = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Event has ended'),
      );
      expect(button.onPressed, isNull);
    });

    // -----------------------------------------------------------------------
    // 7. EmailNotVerifiedFailure → BannerMessage
    // -----------------------------------------------------------------------
    testWidgets('EmailNotVerifiedFailure → BannerMessage with verify copy', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        event: _testEvent,
        ctaState: const RequestToJoinFailed(
          failure: EmailNotVerifiedFailure('Not verified'),
        ),
      );

      expect(
        find.textContaining('Verify your email to request events'),
        findsOneWidget,
      );
      expect(find.text('Verify now'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 8. Withdraw dialog: tapping "Withdraw request" shows AlertDialog
    // -----------------------------------------------------------------------
    testWidgets('tapping "Withdraw request" shows confirmation AlertDialog', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        event: _testEvent,
        ctaState: RequestToJoinIdle(existingRequest: _pendingRequest),
      );

      await tester.tap(find.text('Withdraw request'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Withdraw your request?'), findsOneWidget);
    });

    testWidgets('cancelling withdraw dialog → no withdraw call', (
      tester,
    ) async {
      var withdrawCalled = false;
      await _pumpPage(
        tester,
        event: _testEvent,
        ctaState: RequestToJoinIdle(existingRequest: _pendingRequest),
        onWithdrawCalled: () => withdrawCalled = true,
      );

      await tester.tap(find.text('Withdraw request'));
      await tester.pumpAndSettle();

      // Tap Cancel in the dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(withdrawCalled, isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // Fix C regression: Withdrawn → re-request flow
  // -----------------------------------------------------------------------
  group('Withdrawn re-request CTA (TRI-28 Fix C)', () {
    testWidgets(
      'tapping "Request to join" in withdrawn state opens ConfirmJoinSheet',
      (tester) async {
        await _pumpPage(
          tester,
          event: _testEvent,
          ctaState: RequestToJoinIdle(existingRequest: _withdrawnRequest),
        );

        await tester.tap(find.widgetWithText(PrimaryButton, 'Request to join'));
        await tester.pumpAndSettle();

        // ConfirmJoinSheet shows "Send request" button.
        expect(find.text('Send request'), findsOneWidget);
      },
    );

    testWidgets(
      'confirming re-request in ConfirmJoinSheet calls controller.submit()',
      (tester) async {
        var submitCalled = false;
        await _pumpPage(
          tester,
          event: _testEvent,
          ctaState: RequestToJoinIdle(existingRequest: _withdrawnRequest),
          onSubmitCalled: () => submitCalled = true,
        );

        // Open the ConfirmJoinSheet.
        await tester.tap(find.widgetWithText(PrimaryButton, 'Request to join'));
        await tester.pumpAndSettle();

        // Tap the "Send request" button inside the sheet.
        await tester.tap(find.text('Send request'));
        await tester.pumpAndSettle();

        expect(submitCalled, isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Overlap regression (TRI-28 Fix A)
  //
  // Verifies the sticky bar is rendered as Scaffold.bottomNavigationBar (not as
  // a Positioned widget inside a Stack). With the old Stack + manual
  // stickyBarHeight() approach the bar's Positioned widget could occlude content
  // above it when the height estimate was too low (~26px short for Pending).
  // Scaffold.bottomNavigationBar auto-reserves the exact rendered bar height as
  // a body inset, so scroll content can never be occluded.
  //
  // We assert:
  //   1. No Positioned ancestor of the "Withdraw request" text — proving the
  //      bar is NOT rendered via the old Stack/Positioned pattern.
  //   2. The capacity row text exists in the widget tree (it is present, not
  //      removed or replaced by the bar).
  //   3. The sticky bar's top edge is at or below the sticky bar itself (sanity
  //      check that bottomNavigationBar is at the bottom of the screen).
  // ---------------------------------------------------------------------------
  group('sticky bar overlap regression (TRI-28 Fix A)', () {
    testWidgets(
      'Pending state — sticky bar is bottomNavigationBar, not Positioned',
      (tester) async {
        await _pumpPage(
          tester,
          event: _testEvent,
          ctaState: RequestToJoinIdle(existingRequest: _pendingRequest),
        );

        // Capacity row must exist in the widget tree.
        expect(find.text('8 spots total'), findsOneWidget);

        // Sticky bar content must be present.
        expect(find.text('Withdraw request'), findsOneWidget);

        // The sticky bar must NOT be inside a Positioned widget.
        // With the old Stack approach, find.ancestor would find a Positioned.
        // With Scaffold.bottomNavigationBar it will not.
        final withdrawFinder = find.text('Withdraw request');
        final positionedAncestors = find.ancestor(
          of: withdrawFinder,
          matching: find.byType(Positioned),
        );
        expect(
          positionedAncestors,
          findsNothing,
          reason:
              'Sticky bar must be rendered via Scaffold.bottomNavigationBar, '
              'not as a Positioned widget in a Stack. A Positioned ancestor of '
              '"Withdraw request" means the old overlap-prone pattern is still '
              'in use.',
        );

        // The sticky bar's top edge must be at or near the screen bottom.
        // Default test screen height is 600. Bar should be in the bottom ~200px.
        final barRect = tester.getRect(find.text('Withdraw request'));
        expect(
          barRect.top,
          greaterThan(400),
          reason:
              'Sticky bar top (${barRect.top}) should be in the lower half of '
              'the screen, confirming it is rendered at the bottom.',
        );
      },
    );
  });
}
