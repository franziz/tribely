// Widget tests for PendingRequestRow.
//
// Covers:
//   1. Renders requester display name.
//   2. Approve button is enabled in idle state.
//   3. Decline button is enabled in idle state.
//   4. Tapping Approve calls onApprove.
//   5. Tapping Decline calls onDecline.
//   6. Both buttons are disabled when isInFlight = true.
//   7. Approve button carries correct a11y label.
//   8. Decline button carries correct a11y label.
//   9. Tapping avatar/name area calls onTapRequester.
//  10. Tapping Approve does NOT call onTapRequester.
//  11. Tapping Decline does NOT call onTapRequester.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request_with_requester.dart';
import 'package:tribely/src/features/join_requests/presentation/widgets/pending_request_row.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _item = JoinRequestWithRequester(
  joinRequest: JoinRequest(
    id: 'jr-test-1',
    eventId: 'evt-test-1',
    requesterUserId: 'user-test-1',
    status: JoinRequestStatus.pending,
    requestedAt: DateTime.utc(2026, 5, 1),
  ),
  requester: const JoinRequestRequesterSummary(
    id: 'user-test-1',
    displayName: 'Priya Sharma',
  ),
);

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

Future<void> _pumpRow(
  WidgetTester tester, {
  required VoidCallback onApprove,
  required ValueChanged<String> onDecline,
  bool isInFlight = false,
  VoidCallback? onTapRequester,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PendingRequestRow(
          item: _item,
          onApprove: onApprove,
          onDecline: onDecline,
          isInFlight: isInFlight,
          onTapRequester: onTapRequester,
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
  group('PendingRequestRow', () {
    // -----------------------------------------------------------------------
    // 1. Renders display name
    // -----------------------------------------------------------------------
    testWidgets('renders requester display name', (tester) async {
      await _pumpRow(tester, onApprove: () {}, onDecline: (_) {});
      expect(find.text('Priya Sharma'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. Approve button enabled in idle
    // -----------------------------------------------------------------------
    testWidgets('Approve button is enabled (onPressed non-null) in idle', (
      tester,
    ) async {
      await _pumpRow(tester, onApprove: () {}, onDecline: (_) {});

      final approveButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Approve'),
      );
      expect(approveButton.onPressed, isNotNull);
    });

    // -----------------------------------------------------------------------
    // 3. Decline button enabled in idle
    // -----------------------------------------------------------------------
    testWidgets('Decline button is enabled (onPressed non-null) in idle', (
      tester,
    ) async {
      await _pumpRow(tester, onApprove: () {}, onDecline: (_) {});

      final declineButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Decline'),
      );
      expect(declineButton.onPressed, isNotNull);
    });

    // -----------------------------------------------------------------------
    // 4. Tapping Approve calls onApprove
    // -----------------------------------------------------------------------
    testWidgets('tapping Approve calls onApprove callback', (tester) async {
      var approveCalled = false;
      await _pumpRow(
        tester,
        onApprove: () => approveCalled = true,
        onDecline: (_) {},
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Approve'));
      await tester.pump();

      expect(approveCalled, isTrue);
    });

    // -----------------------------------------------------------------------
    // 5. Tapping Decline calls onDecline
    // -----------------------------------------------------------------------
    testWidgets('tapping Decline calls onDecline callback', (tester) async {
      var declineCalled = false;
      await _pumpRow(
        tester,
        onApprove: () {},
        onDecline: (_) => declineCalled = true,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Decline'));
      await tester.pump();

      expect(declineCalled, isTrue);
    });

    // -----------------------------------------------------------------------
    // 6. Both buttons disabled when isInFlight = true
    // -----------------------------------------------------------------------
    testWidgets(
      'both buttons are disabled (onPressed null) when isInFlight = true',
      (tester) async {
        await _pumpRow(
          tester,
          onApprove: () {},
          onDecline: (_) {},
          isInFlight: true,
        );

        final approveButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Approve'),
        );
        final declineButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Decline'),
        );
        expect(approveButton.onPressed, isNull);
        expect(declineButton.onPressed, isNull);
      },
    );

    // -----------------------------------------------------------------------
    // 7. Approve a11y label includes requester name
    // -----------------------------------------------------------------------
    testWidgets('Approve button semantics label includes requester name', (
      tester,
    ) async {
      await _pumpRow(tester, onApprove: () {}, onDecline: (_) {});

      expect(find.bySemanticsLabel('Approve Priya Sharma'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 8. Decline a11y label includes requester name
    // -----------------------------------------------------------------------
    testWidgets('Decline button semantics label includes requester name', (
      tester,
    ) async {
      await _pumpRow(tester, onApprove: () {}, onDecline: (_) {});

      expect(find.bySemanticsLabel('Decline Priya Sharma'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 9. Tapping avatar/name area calls onTapRequester
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping avatar/name InkWell calls onTapRequester',
      (tester) async {
        var tapCalled = false;
        await _pumpRow(
          tester,
          onApprove: () {},
          onDecline: (_) {},
          onTapRequester: () => tapCalled = true,
        );

        // The InkWell wraps avatar + name; tap the name text.
        await tester.tap(find.text('Priya Sharma'));
        await tester.pump();

        expect(tapCalled, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // 10. Tapping Approve does NOT call onTapRequester
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping Approve does NOT call onTapRequester',
      (tester) async {
        var tapCalled = false;
        await _pumpRow(
          tester,
          onApprove: () {},
          onDecline: (_) {},
          onTapRequester: () => tapCalled = true,
        );

        await tester.tap(find.widgetWithText(OutlinedButton, 'Approve'));
        await tester.pump();

        expect(tapCalled, isFalse);
      },
    );

    // -----------------------------------------------------------------------
    // 11. Tapping Decline does NOT call onTapRequester
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping Decline does NOT call onTapRequester',
      (tester) async {
        var tapCalled = false;
        await _pumpRow(
          tester,
          onApprove: () {},
          onDecline: (_) {},
          onTapRequester: () => tapCalled = true,
        );

        await tester.tap(find.widgetWithText(OutlinedButton, 'Decline'));
        await tester.pump();

        expect(tapCalled, isFalse);
      },
    );
  });
}
