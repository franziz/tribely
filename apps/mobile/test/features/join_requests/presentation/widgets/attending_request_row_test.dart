// Widget tests for AttendingRequestRow.
//
// Covers:
//   1. Renders display name.
//   2. onTapRequester is invoked when the avatar/name area is tapped.
//   3. Kebab icon is present when status=approved AND onTapRemove is non-null.
//   4. Kebab icon is absent when status != approved (even if onTapRemove given).
//   5. Kebab icon is absent when onTapRemove is null (even if status=approved).
//   6. Tapping kebab shows action sheet with "Remove from event" option.
//   7. Selecting "Remove from event" in the action sheet invokes onTapRemove.
//   8. Tapping "Cancel" in action sheet does NOT invoke onTapRemove.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request_with_requester.dart';
import 'package:tribely/src/features/join_requests/presentation/widgets/attending_request_row.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

JoinRequestWithRequester _makeItem({
  String id = 'jr-test',
  String eventId = 'evt-test',
  String userId = 'user-test',
  String name = 'Alice Tan',
  JoinRequestStatus status = JoinRequestStatus.approved,
}) => JoinRequestWithRequester(
  joinRequest: JoinRequest(
    id: id,
    eventId: eventId,
    requesterUserId: userId,
    status: status,
    requestedAt: DateTime.utc(2026, 5, 1),
  ),
  requester: JoinRequestRequesterSummary(id: userId, displayName: name),
);

Future<void> _pumpRow(
  WidgetTester tester, {
  required JoinRequestWithRequester item,
  VoidCallback? onTapRequester,
  VoidCallback? onTapRemove,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AttendingRequestRow(
          item: item,
          onTapRequester: onTapRequester,
          onTapRemove: onTapRemove,
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
  group('AttendingRequestRow', () {
    // -----------------------------------------------------------------------
    // 1. Renders display name
    // -----------------------------------------------------------------------
    testWidgets('renders the requester display name', (tester) async {
      final item = _makeItem(name: 'Alice Tan');
      await _pumpRow(tester, item: item);

      expect(find.textContaining('Alice Tan'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. onTapRequester invoked on tap
    // -----------------------------------------------------------------------
    testWidgets('onTapRequester is invoked when row is tapped', (tester) async {
      var tapped = false;
      final item = _makeItem();
      await _pumpRow(tester, item: item, onTapRequester: () => tapped = true);

      await tester.tap(find.textContaining('Alice Tan'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    // -----------------------------------------------------------------------
    // 3. Kebab present when status=approved AND onTapRemove non-null
    // -----------------------------------------------------------------------
    testWidgets(
      'kebab icon is present when status=approved AND onTapRemove is non-null',
      (tester) async {
        final item = _makeItem(status: JoinRequestStatus.approved);
        await _pumpRow(tester, item: item, onTapRemove: () {});

        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 4. Kebab absent when status != approved
    // -----------------------------------------------------------------------
    testWidgets(
      'kebab icon is absent when status is NOT approved (even with onTapRemove)',
      (tester) async {
        for (final status in [
          JoinRequestStatus.pending,
          JoinRequestStatus.declined,
          JoinRequestStatus.withdrawn,
          JoinRequestStatus.removedByHost,
        ]) {
          final item = _makeItem(status: status);
          await _pumpRow(tester, item: item, onTapRemove: () {});

          expect(
            find.byIcon(Icons.more_vert),
            findsNothing,
            reason: 'kebab should not render for status=$status',
          );
        }
      },
    );

    // -----------------------------------------------------------------------
    // 5. Kebab absent when onTapRemove is null
    // -----------------------------------------------------------------------
    testWidgets(
      'kebab icon is absent when onTapRemove is null (even if status=approved)',
      (tester) async {
        final item = _makeItem(status: JoinRequestStatus.approved);
        await _pumpRow(tester, item: item); // onTapRemove defaults to null

        expect(find.byIcon(Icons.more_vert), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 6. Tapping kebab shows action sheet with "Remove from event"
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping kebab shows action sheet with "Remove from event" option',
      (tester) async {
        final item = _makeItem(status: JoinRequestStatus.approved);
        await _pumpRow(tester, item: item, onTapRemove: () {});

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.textContaining('Remove from event'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 7. Selecting "Remove from event" invokes onTapRemove
    // -----------------------------------------------------------------------
    testWidgets(
      'selecting "Remove from event" in action sheet invokes onTapRemove',
      (tester) async {
        var removeInvoked = false;
        final item = _makeItem(status: JoinRequestStatus.approved);
        await _pumpRow(
          tester,
          item: item,
          onTapRemove: () => removeInvoked = true,
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('Remove from event'));
        await tester.pumpAndSettle();

        expect(removeInvoked, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // 8. Tapping "Cancel" in action sheet does NOT invoke onTapRemove
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping "Cancel" in action sheet does NOT invoke onTapRemove',
      (tester) async {
        var removeInvoked = false;
        final item = _makeItem(status: JoinRequestStatus.approved);
        await _pumpRow(
          tester,
          item: item,
          onTapRemove: () => removeInvoked = true,
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('Cancel'));
        await tester.pumpAndSettle();

        expect(removeInvoked, isFalse);
      },
    );
  });
}
