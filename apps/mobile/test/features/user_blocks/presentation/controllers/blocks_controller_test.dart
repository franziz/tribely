// Unit tests for BlocksController.
//
// Covers:
//   1. Initial state is BlocksLoading.
//   2. Transitions Loading → Loaded on successful fetch with rows.
//   3. Transitions Loading → Empty when rows list is empty.
//   4. Transitions Loading → Failure on error.
//   5. unblock() optimistically removes the row, then reconciles on success.
//   6. unblock() restores the row on API failure.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/user_blocks/domain/entities/blocked_user_summary.dart';
import 'package:tribely/src/features/user_blocks/domain/entities/user_block_list_page.dart';
import 'package:tribely/src/features/user_blocks/domain/usecases/list_my_blocks_usecase.dart';
import 'package:tribely/src/features/user_blocks/domain/usecases/unblock_user_usecase.dart';
import 'package:tribely/src/features/user_blocks/presentation/providers/user_block_providers.dart';
import 'package:tribely/src/features/user_blocks/presentation/state/blocks_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockListMyBlocksUseCase extends Mock implements ListMyBlocksUseCase {}

class MockUnblockUserUseCase extends Mock implements UnblockUserUseCase {}

class FakeListMyBlocksParams extends Fake implements ListMyBlocksParams {}

class FakeUnblockUserParams extends Fake implements UnblockUserParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BlockedUserSummary _fakeSummary(String blockedUserId) => BlockedUserSummary(
  blockId: 'blk-$blockedUserId',
  blockedUserId: blockedUserId,
  createdAt: DateTime(2026, 5, 1),
  displayName: 'User $blockedUserId',
);

UserBlockListPage _fakePage(List<String> userIds, {String? nextCursor}) =>
    UserBlockListPage(
      rows: userIds.map(_fakeSummary).toList(),
      nextCursor: nextCursor,
    );

Future<void> _pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _makeContainer({
  required MockListMyBlocksUseCase listUseCase,
  required MockUnblockUserUseCase unblockUseCase,
}) {
  final container = ProviderContainer(
    overrides: [
      listMyBlocksUseCaseProvider.overrideWithValue(listUseCase),
      unblockUserUseCaseProvider.overrideWithValue(unblockUseCase),
    ],
  );
  container.listen(blocksControllerProvider, (prev, next) {});
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeListMyBlocksParams());
    registerFallbackValue(FakeUnblockUserParams());
  });

  late MockListMyBlocksUseCase listUseCase;
  late MockUnblockUserUseCase unblockUseCase;

  setUp(() {
    listUseCase = MockListMyBlocksUseCase();
    unblockUseCase = MockUnblockUserUseCase();
  });

  test('initial state is BlocksLoading', () {
    when(
      () => listUseCase(any()),
    ).thenAnswer((_) async => Right(_fakePage([])));
    final container = _makeContainer(
      listUseCase: listUseCase,
      unblockUseCase: unblockUseCase,
    );
    expect(container.read(blocksControllerProvider), isA<BlocksLoading>());
  });

  group('Loading → Loaded', () {
    test(
      'transitions Loading → Loaded on successful fetch with rows',
      () async {
        when(
          () => listUseCase(any()),
        ).thenAnswer((_) async => Right(_fakePage(['user-b', 'user-c'])));

        final container = _makeContainer(
          listUseCase: listUseCase,
          unblockUseCase: unblockUseCase,
        );
        await _pump();

        final state = container.read(blocksControllerProvider);
        expect(state, isA<BlocksLoaded>());
        expect((state as BlocksLoaded).rows, hasLength(2));
      },
    );

    test('transitions Loading → Empty when rows list is empty', () async {
      when(
        () => listUseCase(any()),
      ).thenAnswer((_) async => Right(_fakePage([])));

      final container = _makeContainer(
        listUseCase: listUseCase,
        unblockUseCase: unblockUseCase,
      );
      await _pump();

      expect(container.read(blocksControllerProvider), isA<BlocksEmpty>());
    });

    test('transitions Loading → Failure on error', () async {
      when(
        () => listUseCase(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));

      final container = _makeContainer(
        listUseCase: listUseCase,
        unblockUseCase: unblockUseCase,
      );
      await _pump();

      expect(container.read(blocksControllerProvider), isA<BlocksFailure>());
    });
  });

  group('unblock()', () {
    test('optimistically removes the row, confirms on API success', () async {
      when(
        () => listUseCase(any()),
      ).thenAnswer((_) async => Right(_fakePage(['user-b', 'user-c'])));
      when(
        () => unblockUseCase(any()),
      ).thenAnswer((_) async => const Right(null));

      final container = _makeContainer(
        listUseCase: listUseCase,
        unblockUseCase: unblockUseCase,
      );
      await _pump();

      expect(
        (container.read(blocksControllerProvider) as BlocksLoaded).rows,
        hasLength(2),
      );

      unawaited(
        container.read(blocksControllerProvider.notifier).unblock('user-b'),
      );
      await Future<void>.delayed(Duration.zero);

      // Optimistic removal: row count drops immediately.
      final optimistic = container.read(blocksControllerProvider);
      expect(optimistic, isA<BlocksLoaded>());
      expect((optimistic as BlocksLoaded).rows, hasLength(1));
      expect(
        optimistic.rows.map((r) => r.blockedUserId),
        isNot(contains('user-b')),
      );

      await _pump();

      // Final state is still Loaded with 1 row.
      final final_ = container.read(blocksControllerProvider);
      expect(final_, isA<BlocksLoaded>());
    });

    test('restores the row on API failure', () async {
      when(
        () => listUseCase(any()),
      ).thenAnswer((_) async => Right(_fakePage(['user-b'])));
      when(
        () => unblockUseCase(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));

      final container = _makeContainer(
        listUseCase: listUseCase,
        unblockUseCase: unblockUseCase,
      );
      await _pump();

      await container.read(blocksControllerProvider.notifier).unblock('user-b');

      // Row restored after failure.
      final state = container.read(blocksControllerProvider);
      expect(state, isA<BlocksLoaded>());
      expect((state as BlocksLoaded).rows, hasLength(1));
      expect(state.rows.first.blockedUserId, 'user-b');
    });

    test('transitions to Empty when last row is unblocked', () async {
      when(
        () => listUseCase(any()),
      ).thenAnswer((_) async => Right(_fakePage(['user-b'])));
      when(
        () => unblockUseCase(any()),
      ).thenAnswer((_) async => const Right(null));

      final container = _makeContainer(
        listUseCase: listUseCase,
        unblockUseCase: unblockUseCase,
      );
      await _pump();

      unawaited(
        container.read(blocksControllerProvider.notifier).unblock('user-b'),
      );
      await Future<void>.delayed(Duration.zero);

      // Optimistic removal transitions to Empty (last row gone).
      expect(container.read(blocksControllerProvider), isA<BlocksEmpty>());
    });
  });
}
