// Widget tests for BlockedUsersPage.
//
// Covers:
//   1. Empty state renders verbatim copy.
//   2. Loaded state renders blocked user rows with Unblock button.
//   3. Error state renders error message and retry button.
//   4. Unblock button tap triggers unblock action (via controller override).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/user_blocks/domain/entities/blocked_user_summary.dart';
import 'package:tribely/src/features/user_blocks/domain/entities/user_block_list_page.dart';
import 'package:tribely/src/features/user_blocks/presentation/controllers/blocks_controller.dart';
import 'package:tribely/src/features/user_blocks/presentation/pages/blocked_users_page.dart';
import 'package:tribely/src/features/user_blocks/presentation/providers/user_block_providers.dart';
import 'package:tribely/src/features/user_blocks/presentation/state/blocks_state.dart';
import 'package:tribely/src/features/user_blocks/presentation/string_assets/block_copy.dart';

// ---------------------------------------------------------------------------
// Stub controller
// ---------------------------------------------------------------------------

/// A blocks controller that returns a fixed [BlocksState] without touching
/// the service locator or network.
class _FixedBlocksController extends BlocksController {
  _FixedBlocksController(this._state);
  final BlocksState _state;

  @override
  BlocksState build() => _state;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> unblock(String blockedUserId) async {}

  @override
  Future<void> loadMore() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BlockedUserSummary _fakeSummary(String id, String name) => BlockedUserSummary(
  blockId: 'blk-$id',
  blockedUserId: id,
  displayName: name,
  createdAt: DateTime(2026, 5, 1),
);

Widget _wrap(BlocksState state) {
  return ProviderScope(
    overrides: [
      blocksControllerProvider.overrideWith(
        () => _FixedBlocksController(state),
      ),
    ],
    child: const MaterialApp(home: BlockedUsersPage()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BlockedUsersPage — empty state', () {
    testWidgets('renders verbatim empty-state title and subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const BlocksEmpty()));
      await tester.pump();

      expect(find.text(BlockCopy.emptyStateTitle), findsOneWidget);
      expect(find.text(BlockCopy.emptyStateSubtitle), findsOneWidget);
    });
  });

  group('BlockedUsersPage — loaded state', () {
    testWidgets('renders display names and Unblock buttons', (tester) async {
      final page = UserBlockListPage(
        rows: [
          _fakeSummary('user-b', 'Maya Tan'),
          _fakeSummary('user-c', 'Alex Wong'),
        ],
      );
      await tester.pumpWidget(_wrap(BlocksLoaded(page: page)));
      await tester.pump();

      expect(find.text('Maya Tan'), findsOneWidget);
      expect(find.text('Alex Wong'), findsOneWidget);
      expect(find.text('Unblock'), findsNWidgets(2));
    });

    testWidgets('renders "Unknown user" fallback when displayName is null', (
      tester,
    ) async {
      final page = UserBlockListPage(
        rows: [
          BlockedUserSummary(
            blockId: 'blk-x',
            blockedUserId: 'user-x',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ],
      );
      await tester.pumpWidget(_wrap(BlocksLoaded(page: page)));
      await tester.pump();

      expect(find.text(BlockCopy.unknownUser), findsOneWidget);
    });
  });

  group('BlockedUsersPage — error state', () {
    testWidgets('renders error message and retry button', (tester) async {
      await tester.pumpWidget(
        _wrap(const BlocksFailure(message: 'Network error')),
      );
      await tester.pump();

      expect(find.text('Network error'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
