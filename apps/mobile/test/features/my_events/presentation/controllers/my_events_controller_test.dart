// Controller tests for MyEventsController.
//
// Covers:
//   1. load() success → state transitions to MyEventsLoaded with event IDs.
//   2. load() NetworkFailure → state transitions to MyEventsError with network copy.
//   3. refresh() re-invokes the use case (call count increments).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/providers/list_my_hosted_events_usecase_provider.dart';
import 'package:tribely/src/features/discover/domain/usecases/list_my_hosted_events_usecase.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/my_events_controller.dart';
import 'package:tribely/src/features/my_events/presentation/state/my_events_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockListMyHostedEventsUseCase extends Mock
    implements ListMyHostedEventsUseCase {}

// ---------------------------------------------------------------------------
// Fake registrations for mocktail
// ---------------------------------------------------------------------------

class FakeListMyHostedEventsParams extends Fake
    implements ListMyHostedEventsParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Drains the microtask queue so the async load triggered by
/// `Future(() => load())` in [MyEventsController.build] completes.
///
/// 20 turns are needed to cover the chained async hops:
/// (1) Future() callback, (2) load() await useCase, (3) state assignment,
/// (4+) Riverpod notification propagation. 10 is too few and causes silent
/// timeouts where the state never transitions out of Loading.
Future<void> _pump() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Event _makeEvent(String id) => Event(
  id: id,
  hostId: 'host-1',
  title: 'Event $id',
  description: null,
  venue: const EventVenue(
    address: '1 Orchard Rd',
    city: 'Singapore',
    latitude: 1.3,
    longitude: 103.8,
  ),
  startsAt: DateTime.utc(2026, 6, 14, 11),
  endsAt: DateTime.utc(2026, 6, 14, 13),
  capacity: 8,
  category: EventCategory.drinks,
  costSplit: 'own',
  approvalMode: 'manual',
  status: 'published',
  createdAt: DateTime.utc(2026, 5, 1),
);

/// Builds a [ProviderContainer] with [MyEventsController] wired to [mock].
/// Eagerly reads the provider so that [build] fires and the initial load
/// microtask is scheduled. Caller must `await _pump()` to let it complete.
ProviderContainer _makeContainer(MockListMyHostedEventsUseCase mock) {
  final container = ProviderContainer(
    overrides: [listMyHostedEventsUseCaseProvider.overrideWithValue(mock)],
  );
  addTearDown(container.dispose);
  container.read(myEventsControllerProvider);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeListMyHostedEventsParams());
  });

  // -------------------------------------------------------------------------
  // 1. load() success → MyEventsLoaded with event IDs mapped from entities
  // -------------------------------------------------------------------------
  test('load() success → MyEventsLoaded with event IDs', () async {
    final mock = MockListMyHostedEventsUseCase();
    final events = [_makeEvent('evt-1'), _makeEvent('evt-2')];

    when(() => mock(any())).thenAnswer((_) async => Right(events));

    final container = _makeContainer(mock);
    await _pump();

    final state = container.read(myEventsControllerProvider);
    expect(state, isA<MyEventsLoaded>());
    expect(
      (state as MyEventsLoaded).hostedEventIds,
      equals(['evt-1', 'evt-2']),
    );
  });

  // -------------------------------------------------------------------------
  // 2. load() NetworkFailure → MyEventsError with user-facing copy
  // -------------------------------------------------------------------------
  test('load() NetworkFailure → MyEventsError with network copy', () async {
    final mock = MockListMyHostedEventsUseCase();

    when(
      () => mock(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('timeout')));

    final container = _makeContainer(mock);
    await _pump();

    final state = container.read(myEventsControllerProvider);
    expect(state, isA<MyEventsError>());
    expect(
      (state as MyEventsError).message,
      'No connection. Pull down to retry.',
    );
  });

  // -------------------------------------------------------------------------
  // 3. refresh() re-invokes the use case (call count increments)
  // -------------------------------------------------------------------------
  test('refresh() re-invokes the use case', () async {
    final mock = MockListMyHostedEventsUseCase();
    final events = [_makeEvent('evt-1')];

    when(() => mock(any())).thenAnswer((_) async => Right(events));

    final container = _makeContainer(mock);
    await _pump();

    // First load from build() should have called once.
    verify(() => mock(any())).called(1);

    // refresh() triggers a second call.
    await container.read(myEventsControllerProvider.notifier).refresh();
    await _pump();

    verify(() => mock(any())).called(1); // one more call
  });
}
