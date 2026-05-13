// Controller tests for HostingTabController.
//
// Covers:
//   1. load() success → state transitions to HostingTabLoaded with returned events.
//   2. load() failure → state transitions to HostingTabError with user-facing copy.
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
import 'package:tribely/src/features/my_events/presentation/controllers/hosting_tab_controller.dart';
import 'package:tribely/src/features/my_events/presentation/state/hosting_tab_state.dart';

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

/// Builds a [ProviderContainer] with [HostingTabController] wired to [mock].
/// Eagerly reads the provider so that [build] fires and the initial load
/// microtask is scheduled. Caller must `await _pump()` to let it complete.
ProviderContainer _makeContainer(MockListMyHostedEventsUseCase mock) {
  final container = ProviderContainer(
    overrides: [listMyHostedEventsUseCaseProvider.overrideWithValue(mock)],
  );
  addTearDown(container.dispose);
  container.read(hostingTabControllerProvider);
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
  // 1. load() success → HostingTabLoaded with returned events
  // -------------------------------------------------------------------------
  test('load() success → HostingTabLoaded with returned events', () async {
    final mock = MockListMyHostedEventsUseCase();
    final events = [_makeEvent('evt-1'), _makeEvent('evt-2')];

    when(() => mock(any())).thenAnswer((_) async => Right(events));

    final container = _makeContainer(mock);
    await container.read(hostingTabControllerProvider.notifier).load();

    final state = container.read(hostingTabControllerProvider);
    expect(state, isA<HostingTabLoaded>());
    expect((state as HostingTabLoaded).events, equals(events));
  });

  // -------------------------------------------------------------------------
  // 2. load() failure → HostingTabError with user-facing copy
  // -------------------------------------------------------------------------
  test('load() NetworkFailure → HostingTabError with network copy', () async {
    final mock = MockListMyHostedEventsUseCase();

    when(
      () => mock(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('timeout')));

    final container = _makeContainer(mock);
    await container.read(hostingTabControllerProvider.notifier).load();

    final state = container.read(hostingTabControllerProvider);
    expect(state, isA<HostingTabError>());
    expect(
      (state as HostingTabError).message,
      'No connection. Pull down to retry.',
    );
  });

  test('load() generic failure → HostingTabError with fallback copy', () async {
    final mock = MockListMyHostedEventsUseCase();

    when(
      () => mock(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('internal')));

    final container = _makeContainer(mock);
    await container.read(hostingTabControllerProvider.notifier).load();

    final state = container.read(hostingTabControllerProvider);
    expect(state, isA<HostingTabError>());
    expect(
      (state as HostingTabError).message,
      'Something went wrong. Please try again.',
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
    // Explicitly drive the initial load — don't rely on build()'s scheduled
    // Future(() => load()) which autoDispose can kill before it fires.
    await container.read(hostingTabControllerProvider.notifier).load();

    // First load should have called once.
    verify(() => mock(any())).called(1);

    // refresh() triggers a second call.
    await container.read(hostingTabControllerProvider.notifier).refresh();

    verify(() => mock(any())).called(1); // one more call
  });
}
