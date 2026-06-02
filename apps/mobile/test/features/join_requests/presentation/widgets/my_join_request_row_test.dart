// Widget tests for MyJoinRequestRow.
//
// Covers:
//   1. Renders event title.
//   2. Renders SGT-formatted date (UTC startsAt → UTC+8).
//   3. Pending status → StatusPill present + "Withdraw request" link visible.
//   4. Approved status → StatusPill present, no withdraw link.
//   5. Declined status → StatusPill present, no withdraw link.
//   6. Withdrawn status → StatusPill present, no withdraw link.
//   7. Tapping "Withdraw request" calls onWithdraw.
//   8. isWithdrawing=true → spinner shown, no tap target.
//   9. removedByHost → "Removed" StatusPill + "No longer attending" subtext,
//      no withdraw link, no kebab, no action affordances (Path B).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request_with_event.dart';
import 'package:tribely/src/features/join_requests/presentation/widgets/my_join_request_row.dart';
import 'package:tribely/src/core/widgets/status_pill.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _baseEvent = JoinRequestEventSummary(
  id: 'evt-row-1',
  title: 'Evening Drinks',
  startsAt: DateTime.utc(2026, 6, 14, 11, 0), // 11:00 UTC = 19:00 SGT
  endsAt: DateTime.utc(2026, 6, 14, 13, 0),
  venueAddress: '1 Orchard Rd',
  venueCity: 'Singapore',
  status: 'published',
  capacity: 8,
);

final _baseRequest = JoinRequest(
  id: 'jr-row-1',
  eventId: 'evt-row-1',
  requesterUserId: 'user-1',
  status: JoinRequestStatus.pending,
  requestedAt: DateTime.utc(2026, 5, 1),
);

JoinRequestWithEvent _makeItem(JoinRequestStatus status) =>
    JoinRequestWithEvent(
      joinRequest: _baseRequest.copyWith(status: status),
      event: _baseEvent,
    );

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpRow(
  WidgetTester tester, {
  required JoinRequestStatus status,
  VoidCallback? onWithdraw,
  bool isWithdrawing = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MyJoinRequestRow(
          item: _makeItem(status),
          onWithdraw: onWithdraw,
          isWithdrawing: isWithdrawing,
        ),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MyJoinRequestRow', () {
    // -------------------------------------------------------------------------
    // 1. Event title
    // -------------------------------------------------------------------------
    testWidgets('renders event title', (tester) async {
      await _pumpRow(tester, status: JoinRequestStatus.pending);
      expect(find.text('Evening Drinks'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. SGT date formatting (UTC 11:00 → SGT 19:00 = "7 PM")
    // -------------------------------------------------------------------------
    testWidgets('renders SGT-formatted date for UTC 11:00 event', (
      tester,
    ) async {
      await _pumpRow(tester, status: JoinRequestStatus.pending);
      // UTC+8: 11:00 UTC → 19:00 SGT → "7 PM"
      // Date: 14 Jun 2026, Sunday → "Sun, 14 Jun · 7 PM"
      expect(find.textContaining('7 PM'), findsOneWidget);
      expect(find.textContaining('14 Jun'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 3. Pending → StatusPill + withdraw link
    // -------------------------------------------------------------------------
    testWidgets(
      'pending → StatusPill shown and "Withdraw request" link visible',
      (tester) async {
        await _pumpRow(tester, status: JoinRequestStatus.pending);

        expect(find.byType(StatusPill), findsOneWidget);
        expect(find.text('Withdraw request'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // 4. Approved → StatusPill, no withdraw
    // -------------------------------------------------------------------------
    testWidgets('approved → StatusPill shown, no withdraw link', (
      tester,
    ) async {
      await _pumpRow(tester, status: JoinRequestStatus.approved);

      expect(find.byType(StatusPill), findsOneWidget);
      expect(find.text('Withdraw request'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 5. Declined → StatusPill, no withdraw
    // -------------------------------------------------------------------------
    testWidgets('declined → StatusPill shown, no withdraw link', (
      tester,
    ) async {
      await _pumpRow(tester, status: JoinRequestStatus.declined);

      expect(find.byType(StatusPill), findsOneWidget);
      expect(find.text('Withdraw request'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 6. Withdrawn → StatusPill, no withdraw
    // -------------------------------------------------------------------------
    testWidgets('withdrawn → StatusPill shown, no withdraw link', (
      tester,
    ) async {
      await _pumpRow(tester, status: JoinRequestStatus.withdrawn);

      expect(find.byType(StatusPill), findsOneWidget);
      expect(find.text('Withdraw request'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 7. Tapping "Withdraw request" calls onWithdraw
    // -------------------------------------------------------------------------
    testWidgets('tapping "Withdraw request" calls onWithdraw callback', (
      tester,
    ) async {
      var called = false;
      await _pumpRow(
        tester,
        status: JoinRequestStatus.pending,
        onWithdraw: () => called = true,
      );

      await tester.tap(find.text('Withdraw request'));
      await tester.pump();

      expect(called, isTrue);
    });

    // -------------------------------------------------------------------------
    // 8. isWithdrawing=true → spinner, no tap target
    // -------------------------------------------------------------------------
    testWidgets('isWithdrawing=true → spinner shown, no withdraw text', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        status: JoinRequestStatus.pending,
        isWithdrawing: true,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Withdraw request'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 9. removedByHost → "Removed" pill + "No longer attending" subtext,
    //    no withdraw link, no other action affordances (Path B).
    // -------------------------------------------------------------------------
    testWidgets('removedByHost → "Removed" StatusPill shown', (tester) async {
      await _pumpRow(tester, status: JoinRequestStatus.removedByHost);

      expect(find.byType(StatusPill), findsOneWidget);
    });

    testWidgets('removedByHost → "No longer attending" subtext shown', (
      tester,
    ) async {
      await _pumpRow(tester, status: JoinRequestStatus.removedByHost);

      expect(find.text('No longer attending'), findsOneWidget);
    });

    testWidgets('removedByHost → no "Withdraw request" link', (tester) async {
      await _pumpRow(tester, status: JoinRequestStatus.removedByHost);

      expect(find.text('Withdraw request'), findsNothing);
    });

    testWidgets(
      'removedByHost → no GestureDetector tap targets (no kebab, no action)',
      (tester) async {
        await _pumpRow(tester, status: JoinRequestStatus.removedByHost);

        // The only interactive element in a non-pending row is the StatusPill
        // touch target (SizedBox height 48). There must be no GestureDetector.
        expect(find.byType(GestureDetector), findsNothing);
      },
    );
  });
}
