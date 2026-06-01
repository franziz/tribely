import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/usecase/usecase.dart';
import 'package:tribely/src/features/check_ins/domain/entities/pending_check_in.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/acknowledge_check_in_usecase.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/flag_check_in_usecase.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/surface_pending_check_ins_usecase.dart';
import 'package:tribely/src/features/check_ins/presentation/controllers/check_ins_controller.dart';
import 'package:tribely/src/features/check_ins/presentation/providers/check_ins_providers.dart';
import 'package:tribely/src/features/check_ins/presentation/state/check_ins_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSurfacePendingCheckInsUseCase extends Mock
    implements SurfacePendingCheckInsUseCase {}

class MockAcknowledgeCheckInUseCase extends Mock
    implements AcknowledgeCheckInUseCase {}

class MockFlagCheckInUseCase extends Mock implements FlagCheckInUseCase {}

// ---------------------------------------------------------------------------
// Fake registrations for mocktail
// ---------------------------------------------------------------------------

class FakeNoParams extends Fake implements NoParams {}

class FakeAcknowledgeCheckInParams extends Fake
    implements AcknowledgeCheckInParams {}

class FakeFlagCheckInParams extends Fake implements FlagCheckInParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PendingCheckIn _makeCheckIn(String id) => PendingCheckIn(
  id: id,
  eventId: 'event-1',
  eventTitle: 'Test Event',
  hostDisplayName: 'Host Alice',
  endedAt: DateTime(2026, 6, 1, 21),
  createdAt: DateTime(2026, 6, 1, 22),
);

/// Builds a [ProviderContainer] with [CheckInsController] wired to the
/// provided mock use cases. Registers teardown automatically.
///
/// Eagerly subscribes to [checkInsControllerProvider] via `listen` so that
/// the autoDispose provider is kept alive for the duration of the test. Without
/// this, the provider would dispose after the first `read` (no persistent
/// listeners) and the controller's state would reset to [CheckInsIdle] between
/// async operations.
ProviderContainer _makeContainer({
  required MockSurfacePendingCheckInsUseCase surfaceUseCase,
  required MockAcknowledgeCheckInUseCase acknowledgeUseCase,
  required MockFlagCheckInUseCase flagUseCase,
}) {
  final container = ProviderContainer(
    overrides: [
      surfacePendingCheckInsUseCaseProvider.overrideWithValue(surfaceUseCase),
      acknowledgeCheckInUseCaseProvider.overrideWithValue(acknowledgeUseCase),
      flagCheckInUseCaseProvider.overrideWithValue(flagUseCase),
    ],
  );
  addTearDown(container.dispose);
  // Keep the autoDispose provider alive for the full test lifetime.
  container.listen<CheckInsState>(
    checkInsControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  return container;
}

Future<void> _pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeNoParams());
    registerFallbackValue(FakeAcknowledgeCheckInParams());
    registerFallbackValue(FakeFlagCheckInParams());
  });

  late MockSurfacePendingCheckInsUseCase surfaceUseCase;
  late MockAcknowledgeCheckInUseCase acknowledgeUseCase;
  late MockFlagCheckInUseCase flagUseCase;

  setUp(() {
    surfaceUseCase = MockSurfacePendingCheckInsUseCase();
    acknowledgeUseCase = MockAcknowledgeCheckInUseCase();
    flagUseCase = MockFlagCheckInUseCase();
  });

  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------

  group('initial state', () {
    test('build() returns CheckInsIdle', () {
      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      expect(container.read(checkInsControllerProvider), isA<CheckInsIdle>());
    });
  });

  // ---------------------------------------------------------------------------
  // refresh()
  // ---------------------------------------------------------------------------

  group('refresh()', () {
    test('Idle → Loading → Showing when items returned', () async {
      final item = _makeCheckIn('ci-1');
      when(() => surfaceUseCase(any())).thenAnswer((_) async => Right([item]));

      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      // Kick off refresh — do NOT await yet so we can observe Loading.
      final future = container
          .read(checkInsControllerProvider.notifier)
          .refresh();

      // After scheduling but before await the state is Loading.
      expect(
        container.read(checkInsControllerProvider),
        isA<CheckInsLoading>(),
      );

      await future;

      final state = container.read(checkInsControllerProvider);
      expect(state, isA<CheckInsShowing>());
      expect((state as CheckInsShowing).item.id, 'ci-1');
    });

    test('Idle → Loading → Empty when empty list returned', () async {
      when(
        () => surfaceUseCase(any()),
      ).thenAnswer((_) async => const Right([]));

      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      await container.read(checkInsControllerProvider.notifier).refresh();

      expect(container.read(checkInsControllerProvider), isA<CheckInsEmpty>());
    });

    test('Idle → Loading → Error on failure', () async {
      const failure = NetworkFailure('offline');
      when(
        () => surfaceUseCase(any()),
      ).thenAnswer((_) async => const Left(failure));

      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      await container.read(checkInsControllerProvider.notifier).refresh();

      final state = container.read(checkInsControllerProvider);
      expect(state, isA<CheckInsError>());
      expect((state as CheckInsError).failure, equals(failure));
    });
  });

  // ---------------------------------------------------------------------------
  // acknowledged()
  // ---------------------------------------------------------------------------

  group('acknowledged()', () {
    test('Showing → Loading → Empty when no more pending items', () async {
      final item = _makeCheckIn('ci-1');
      // First call (from refresh) returns item; second call (re-surface after
      // acknowledge) returns empty list.
      var surfaceCallCount = 0;
      when(() => surfaceUseCase(any())).thenAnswer((_) async {
        surfaceCallCount++;
        return surfaceCallCount == 1 ? Right([item]) : const Right([]);
      });
      when(
        () => acknowledgeUseCase(any()),
      ).thenAnswer((_) async => const Right(unit));

      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      // Get into Showing state.
      await container.read(checkInsControllerProvider.notifier).refresh();
      expect(
        container.read(checkInsControllerProvider),
        isA<CheckInsShowing>(),
      );

      // Acknowledge — should re-surface and land on Empty.
      await container.read(checkInsControllerProvider.notifier).acknowledged();

      expect(container.read(checkInsControllerProvider), isA<CheckInsEmpty>());
      verify(() => acknowledgeUseCase(any())).called(1);
    });

    test('Showing → Loading → Showing(next) when more items pending', () async {
      final first = _makeCheckIn('ci-1');
      final second = _makeCheckIn('ci-2');
      var surfaceCallCount = 0;
      when(() => surfaceUseCase(any())).thenAnswer((_) async {
        surfaceCallCount++;
        return surfaceCallCount == 1 ? Right([first]) : Right([second]);
      });
      when(
        () => acknowledgeUseCase(any()),
      ).thenAnswer((_) async => const Right(unit));

      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      await container.read(checkInsControllerProvider.notifier).refresh();
      await container.read(checkInsControllerProvider.notifier).acknowledged();

      final state = container.read(checkInsControllerProvider);
      expect(state, isA<CheckInsShowing>());
      expect((state as CheckInsShowing).item.id, 'ci-2');
    });

    test('acknowledged() is a no-op when state is not Showing', () async {
      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      // State is Idle — acknowledged() must not call the use case.
      await container.read(checkInsControllerProvider.notifier).acknowledged();

      verifyNever(() => acknowledgeUseCase(any()));
    });

    test('Showing → Error when acknowledge fails', () async {
      final item = _makeCheckIn('ci-1');
      when(() => surfaceUseCase(any())).thenAnswer((_) async => Right([item]));
      const failure = ServerFailure('oops', statusCode: 500);
      when(
        () => acknowledgeUseCase(any()),
      ).thenAnswer((_) async => const Left(failure));

      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      await container.read(checkInsControllerProvider.notifier).refresh();
      await container.read(checkInsControllerProvider.notifier).acknowledged();

      final state = container.read(checkInsControllerProvider);
      expect(state, isA<CheckInsError>());
      expect((state as CheckInsError).failure, equals(failure));
    });
  });

  // ---------------------------------------------------------------------------
  // flagged()
  // ---------------------------------------------------------------------------

  group('flagged()', () {
    test('Showing → Loading → Empty after successful flag', () async {
      final item = _makeCheckIn('ci-1');
      var surfaceCallCount = 0;
      when(() => surfaceUseCase(any())).thenAnswer((_) async {
        surfaceCallCount++;
        return surfaceCallCount == 1 ? Right([item]) : const Right([]);
      });
      when(() => flagUseCase(any())).thenAnswer((_) async => const Right(unit));

      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      await container.read(checkInsControllerProvider.notifier).refresh();
      await container
          .read(checkInsControllerProvider.notifier)
          .flagged('Felt unsafe', disclaimerAcknowledged: true);

      expect(container.read(checkInsControllerProvider), isA<CheckInsEmpty>());
      verify(() => flagUseCase(any())).called(1);
    });

    test('flagged() is a no-op when state is not Showing', () async {
      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      await container
          .read(checkInsControllerProvider.notifier)
          .flagged('report', disclaimerAcknowledged: true);

      verifyNever(() => flagUseCase(any()));
    });

    test('Showing → Error when flag call fails', () async {
      final item = _makeCheckIn('ci-1');
      when(() => surfaceUseCase(any())).thenAnswer((_) async => Right([item]));
      const failure = NetworkFailure('offline');
      when(
        () => flagUseCase(any()),
      ).thenAnswer((_) async => const Left(failure));

      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      await container.read(checkInsControllerProvider.notifier).refresh();
      await container
          .read(checkInsControllerProvider.notifier)
          .flagged('Felt unsafe', disclaimerAcknowledged: true);

      final state = container.read(checkInsControllerProvider);
      expect(state, isA<CheckInsError>());
    });
  });

  // ---------------------------------------------------------------------------
  // dismissShown()
  // ---------------------------------------------------------------------------

  group('dismissShown()', () {
    test('Showing → Idle (client-only, no API call)', () async {
      final item = _makeCheckIn('ci-1');
      when(() => surfaceUseCase(any())).thenAnswer((_) async => Right([item]));

      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      await container.read(checkInsControllerProvider.notifier).refresh();
      expect(
        container.read(checkInsControllerProvider),
        isA<CheckInsShowing>(),
      );

      container.read(checkInsControllerProvider.notifier).dismissShown();

      expect(container.read(checkInsControllerProvider), isA<CheckInsIdle>());
      // No API calls should have been made for acknowledge or flag.
      verifyNever(() => acknowledgeUseCase(any()));
      verifyNever(() => flagUseCase(any()));
    });

    test('dismissShown() is a no-op when state is not Showing', () async {
      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      // State is Idle — dismiss must not change state.
      container.read(checkInsControllerProvider.notifier).dismissShown();

      expect(container.read(checkInsControllerProvider), isA<CheckInsIdle>());
    });
  });

  // ---------------------------------------------------------------------------
  // Full happy-path: Idle → Loading → Showing → Loading → Empty
  // ---------------------------------------------------------------------------

  group('full happy-path', () {
    test('Idle → refresh → Showing(item) → acknowledged → Empty', () async {
      final item = _makeCheckIn('ci-1');
      var surfaceCallCount = 0;
      when(() => surfaceUseCase(any())).thenAnswer((_) async {
        surfaceCallCount++;
        return surfaceCallCount == 1 ? Right([item]) : const Right([]);
      });
      when(
        () => acknowledgeUseCase(any()),
      ).thenAnswer((_) async => const Right(unit));

      final container = _makeContainer(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      );

      // Step 1: starts Idle.
      expect(container.read(checkInsControllerProvider), isA<CheckInsIdle>());

      // Step 2: refresh → Loading intermediate.
      final refreshFuture = container
          .read(checkInsControllerProvider.notifier)
          .refresh();
      expect(
        container.read(checkInsControllerProvider),
        isA<CheckInsLoading>(),
      );
      await refreshFuture;

      // Step 3: → Showing.
      expect(
        container.read(checkInsControllerProvider),
        isA<CheckInsShowing>(),
      );

      // Step 4: acknowledge → Loading → Empty.
      final ackFuture = container
          .read(checkInsControllerProvider.notifier)
          .acknowledged();
      expect(
        container.read(checkInsControllerProvider),
        isA<CheckInsLoading>(),
      );
      await ackFuture;
      await _pump();

      expect(container.read(checkInsControllerProvider), isA<CheckInsEmpty>());
    });
  });
}
