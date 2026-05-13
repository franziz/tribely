// Widget tests for MyJoinRequestsTab.
//
// Covers:
//   1. Loading state → CircularProgressIndicator.
//   2. Error state → BannerMessage with retry button.
//   3. Empty state → InkMark + copy + "Find something on Discover" button.
//   4. Loaded state → event title rows visible.
//   5. Pending row → "Withdraw request" link present.
//   6. Non-pending row → no "Withdraw request" link.
//   7. Tapping "Withdraw request" shows AlertDialog.
//   8. Cancelling dialog → controller.withdraw NOT called.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/widgets/banner_message.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request_with_event.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/my_join_requests_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/my_join_requests_state.dart';
import 'package:tribely/src/features/my_events/presentation/pages/my_join_requests_tab.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _baseEvent = JoinRequestEventSummary(
  id: 'evt-tab-1',
  title: 'Evening Drinks',
  startsAt: DateTime.utc(2026, 6, 14, 11, 0),
  endsAt: DateTime.utc(2026, 6, 14, 13, 0),
  venueAddress: '1 Orchard Rd',
  venueCity: 'Singapore',
  status: 'published',
  capacity: 8,
);

final _pendingItem = JoinRequestWithEvent(
  joinRequest: JoinRequest(
    id: 'jr-tab-1',
    eventId: 'evt-tab-1',
    requesterUserId: 'user-1',
    status: JoinRequestStatus.pending,
    requestedAt: DateTime.utc(2026, 5, 1),
  ),
  event: _baseEvent,
);

final _approvedItem = JoinRequestWithEvent(
  joinRequest: JoinRequest(
    id: 'jr-tab-2',
    eventId: 'evt-tab-2',
    requesterUserId: 'user-1',
    status: JoinRequestStatus.approved,
    requestedAt: DateTime.utc(2026, 5, 2),
  ),
  event: _baseEvent.copyWith(id: 'evt-tab-2', title: 'Approved Hike'),
);

// ---------------------------------------------------------------------------
// Fixed-state controller helper
// ---------------------------------------------------------------------------

class _FixedMyJoinRequestsController extends MyJoinRequestsController {
  _FixedMyJoinRequestsController(this._fixed, {this.onWithdrawCalled})
    : super(null);

  final MyJoinRequestsState _fixed;

  /// Invoked when [withdraw] is called. Test code reads this to verify side
  /// effects without exposing a mutable field on the Notifier.
  final VoidCallback? onWithdrawCalled;

  @override
  MyJoinRequestsState build() => _fixed;

  @override
  Future<void> retry() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> withdraw(String joinRequestId) async {
    onWithdrawCalled?.call();
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<_FixedMyJoinRequestsController> _pumpTab(
  WidgetTester tester,
  MyJoinRequestsState state, {
  VoidCallback? onWithdrawCalled,
}) async {
  final controller = _FixedMyJoinRequestsController(
    state,
    onWithdrawCalled: onWithdrawCalled,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myJoinRequestsControllerProvider(null).overrideWith(() => controller),
      ],
      child: const MaterialApp(home: Scaffold(body: MyJoinRequestsTab())),
    ),
  );
  await tester.pump();
  return controller;
}

// ---------------------------------------------------------------------------
// JoinRequestEventSummary helper (no copyWith in codegen — manual extension)
// ---------------------------------------------------------------------------

extension _EventSummaryCopyWith on JoinRequestEventSummary {
  JoinRequestEventSummary copyWith({String? id, String? title}) {
    return JoinRequestEventSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      startsAt: startsAt,
      endsAt: endsAt,
      venueAddress: venueAddress,
      venueCity: venueCity,
      status: status,
      capacity: capacity,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MyJoinRequestsTab', () {
    // -----------------------------------------------------------------------
    // 1. Loading state
    // -----------------------------------------------------------------------
    testWidgets('loading state → CircularProgressIndicator', (tester) async {
      await _pumpTab(tester, const MyJoinRequestsLoading());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. Error state
    // -----------------------------------------------------------------------
    testWidgets('error state → BannerMessage with retry', (tester) async {
      await _pumpTab(
        tester,
        const MyJoinRequestsError(failure: NetworkFailure('No connection')),
      );

      expect(find.byType(BannerMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 3. Empty state
    // -----------------------------------------------------------------------
    testWidgets('empty state → copy + "Find something on Discover" button', (
      tester,
    ) async {
      await _pumpTab(tester, const MyJoinRequestsLoaded(items: []));

      expect(
        find.textContaining("You haven't requested any events yet."),
        findsOneWidget,
      );
      expect(find.text('Find something on Discover'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 4. Loaded state → event titles visible
    // -----------------------------------------------------------------------
    testWidgets('loaded state → event title rows rendered', (tester) async {
      await _pumpTab(
        tester,
        MyJoinRequestsLoaded(items: [_pendingItem, _approvedItem]),
      );

      expect(find.text('Evening Drinks'), findsOneWidget);
      expect(find.text('Approved Hike'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 5. Pending row → withdraw link present
    // -----------------------------------------------------------------------
    testWidgets('pending row → "Withdraw request" link visible', (
      tester,
    ) async {
      await _pumpTab(tester, MyJoinRequestsLoaded(items: [_pendingItem]));

      expect(find.text('Withdraw request'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 6. Non-pending row → no withdraw link
    // -----------------------------------------------------------------------
    testWidgets('approved row → no "Withdraw request" link', (tester) async {
      await _pumpTab(tester, MyJoinRequestsLoaded(items: [_approvedItem]));

      expect(find.text('Withdraw request'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 7. Tapping "Withdraw request" shows AlertDialog
    // -----------------------------------------------------------------------
    testWidgets('tapping "Withdraw request" shows confirmation AlertDialog', (
      tester,
    ) async {
      await _pumpTab(tester, MyJoinRequestsLoaded(items: [_pendingItem]));

      await tester.tap(find.text('Withdraw request'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Withdraw your request?'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 8. Cancelling dialog → controller.withdraw NOT called
    // -----------------------------------------------------------------------
    testWidgets('cancelling withdraw dialog → controller.withdraw not called', (
      tester,
    ) async {
      var withdrawCalled = false;
      await _pumpTab(
        tester,
        MyJoinRequestsLoaded(items: [_pendingItem]),
        onWithdrawCalled: () => withdrawCalled = true,
      );

      await tester.tap(find.text('Withdraw request'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(withdrawCalled, isFalse);
    });
  });
}
