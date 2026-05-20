// Unit tests for BlockActionController.
//
// Covers:
//   1. Initial state is BlockActionIdle.
//   2. block() transitions Idle → Blocking → Success on happy path.
//   3. block() transitions Idle → Blocking → Failure on error.
//   4. block() is a no-op when already Blocking (double-submit guard).
//   5. reset() returns to Idle from Failure.
//   6. SelfBlockFailure renders the "can't block yourself" message.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/user_blocks/domain/entities/user_block.dart';
import 'package:tribely/src/features/user_blocks/domain/usecases/block_user_usecase.dart';
import 'package:tribely/src/features/user_blocks/presentation/providers/user_block_providers.dart';
import 'package:tribely/src/features/user_blocks/presentation/state/block_action_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockBlockUserUseCase extends Mock implements BlockUserUseCase {}

class FakeBlockUserParams extends Fake implements BlockUserParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserBlock _fakeBlock() => UserBlock(
  id: 'blk-1',
  initiatorUserId: 'user-a',
  blockedUserId: 'user-b',
  createdAt: DateTime(2026, 5, 1),
);

Future<void> _pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _makeContainer({required MockBlockUserUseCase useCase}) {
  final container = ProviderContainer(
    overrides: [blockUserUseCaseProvider.overrideWithValue(useCase)],
  );
  container.listen(blockActionControllerProvider, (prev, next) {});
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBlockUserParams());
  });

  late MockBlockUserUseCase useCase;

  setUp(() {
    useCase = MockBlockUserUseCase();
  });

  test('initial state is BlockActionIdle', () {
    final container = _makeContainer(useCase: useCase);
    expect(
      container.read(blockActionControllerProvider),
      isA<BlockActionIdle>(),
    );
  });

  group('block() — Idle → Blocking → Success', () {
    test('transitions Idle → Blocking → Success on happy path', () async {
      final completer = Completer<Either<Failure, UserBlock>>();
      when(() => useCase(any())).thenAnswer((_) async => completer.future);

      final container = _makeContainer(useCase: useCase);

      unawaited(
        container.read(blockActionControllerProvider.notifier).block('user-b'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(blockActionControllerProvider),
        isA<BlockActionBlocking>(),
      );

      completer.complete(Right(_fakeBlock()));
      await _pump();

      expect(
        container.read(blockActionControllerProvider),
        isA<BlockActionSuccess>(),
      );
    });

    test('calls use case with correct params', () async {
      when(() => useCase(any())).thenAnswer((_) async => Right(_fakeBlock()));

      final container = _makeContainer(useCase: useCase);
      await container
          .read(blockActionControllerProvider.notifier)
          .block('user-b');

      final captured = verify(() => useCase(captureAny())).captured;
      expect(captured, hasLength(1));
      final params = captured.first as BlockUserParams;
      expect(params.blockedUserId, 'user-b');
    });
  });

  group('block() — Failure transitions', () {
    test(
      'transitions to Failure with user-friendly message on NetworkFailure',
      () async {
        when(
          () => useCase(any()),
        ).thenAnswer((_) async => const Left(NetworkFailure('offline')));

        final container = _makeContainer(useCase: useCase);
        await container
            .read(blockActionControllerProvider.notifier)
            .block('user-b');

        final state = container.read(blockActionControllerProvider);
        expect(state, isA<BlockActionFailure>());
        expect(
          (state as BlockActionFailure).message,
          contains("Couldn't reach Tribely"),
        );
      },
    );

    test('renders self-block message on SelfBlockFailure', () async {
      when(
        () => useCase(any()),
      ).thenAnswer((_) async => const Left(SelfBlockFailure('Self-block')));

      final container = _makeContainer(useCase: useCase);
      await container
          .read(blockActionControllerProvider.notifier)
          .block('user-a');

      final state = container.read(blockActionControllerProvider);
      expect(state, isA<BlockActionFailure>());
      expect(
        (state as BlockActionFailure).message,
        contains("can't block yourself"),
      );
    });
  });

  group('double-submit guard', () {
    test('ignores second block() while Blocking', () async {
      final completer = Completer<Either<Failure, UserBlock>>();
      when(() => useCase(any())).thenAnswer((_) async => completer.future);

      final container = _makeContainer(useCase: useCase);

      unawaited(
        container.read(blockActionControllerProvider.notifier).block('user-b'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(blockActionControllerProvider),
        isA<BlockActionBlocking>(),
      );

      await container
          .read(blockActionControllerProvider.notifier)
          .block('user-b');

      verify(() => useCase(any())).called(1);

      completer.complete(Right(_fakeBlock()));
      await _pump();
    });
  });

  group('reset()', () {
    test('reset returns to Idle from Failure', () async {
      when(
        () => useCase(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));

      final container = _makeContainer(useCase: useCase);
      await container
          .read(blockActionControllerProvider.notifier)
          .block('user-b');

      expect(
        container.read(blockActionControllerProvider),
        isA<BlockActionFailure>(),
      );

      container.read(blockActionControllerProvider.notifier).reset();
      expect(
        container.read(blockActionControllerProvider),
        isA<BlockActionIdle>(),
      );
    });
  });
}
