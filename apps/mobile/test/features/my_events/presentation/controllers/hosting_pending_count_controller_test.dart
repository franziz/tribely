// Controller tests for HostingPendingCountController.
//
// Covers:
//   1. All-pending list → total equals list length.
//   2. Mixed-status list (1 pending, 1 approved, 1 withdrawn) → total == 1.
//      This is the regression guard for the TRI-28 host-count bug.
//   3. Multiple event IDs → totals summed correctly with pending-only filter.
//   4. Use-case failure → total stays 0; event id appears in failedEventIds.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request_with_requester.dart';
import 'package:tribely/src/features/join_requests/domain/usecases/list_pending_for_event_usecase.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/hosting_pending_count_controller.dart';

// ---------------------------------------------------------------------------
// Mock / fake
// ---------------------------------------------------------------------------

class MockListPendingForEventUseCase extends Mock
    implements ListPendingForEventUseCase {}

class FakeListPendingForEventParams extends Fake
    implements ListPendingForEventParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

JoinRequest _makeJoinRequest(String id, JoinRequestStatus status) => JoinRequest(
      id: id,
      eventId: 'evt-1',
      requesterUserId: 'user-$id',
      status: status,
      requestedAt: DateTime.utc(2026, 5, 1),
    );

JoinRequestWithRequester _makeWithRequester(
  String id,
  JoinRequestStatus status,
) => JoinRequestWithRequester(
      joinRequest: _makeJoinRequest(id, status),
      requester: JoinRequestRequesterSummary(
        id: 'user-$id',
        displayName: 'User $id',
      ),
    );

/// Build a container with the mock use case overridden and the controller
/// eagerly initialised. Caller must call [refresh()] to drive the async load.
ProviderContainer _makeContainer(
  MockListPendingForEventUseCase mock,
  String key,
) {
  final container = ProviderContainer(
    overrides: [listPendingForEventUseCaseProvider.overrideWithValue(mock)],
  );
  addTeardown(container.dispose);
  // Eagerly read to initialise the Notifier (triggers build()).
  container.read(hostingPendingCountControllerProvider(key));
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeListPendingForEventParams());
  });

  // -------------------------------------------------------------------------
  // 1. All-pending list
  // -------------------------------------------------------------------------
  test('all-pending list → total equals list length', () async {
    final mock = MockListPendingForEventUseCase();
    when(() => mock(any())).thenAnswer(
      (_) async => Right([
        _makeWithRequester('a', JoinRequestStatus.pending),
        _makeWithRequester('b', JoinRequestStatus.pending),
      ]),
    );

    const key = 'evt-1';
    final container = _makeContainer(mock, key);
    await container
        .read(hostingPendingCountControllerProvider(key).notifier)
        .refresh();

    final state = container.read(hostingPendingCountControllerProvider(key));
    expect(state.total, 2);
    expect(state.perEvent['evt-1'], 2);
    expect(state.failedEventIds, isEmpty);
  });

  // -------------------------------------------------------------------------
  // 2. Mixed-status list — regression guard for TRI-28
  // -------------------------------------------------------------------------
  test(
    'mixed-status list (1 pending, 1 approved, 1 withdrawn) → total == 1',
    () async {
      final mock = MockListPendingForEventUseCase();
      when(() => mock(any())).thenAnswer(
        (_) async => Right([
          _makeWithRequester('pending-1', JoinRequestStatus.pending),
          _makeWithRequester('approved-1', JoinRequestStatus.approved),
          _makeWithRequester('withdrawn-1', JoinRequestStatus.withdrawn),
        ]),
      );

      const key = 'evt-1';
      final container = _makeContainer(mock, key);
      await container
          .read(hostingPendingCountControllerProvider(key).notifier)
          .refresh();

      final state = container.read(hostingPendingCountControllerProvider(key));
      expect(state.total, 1);
      expect(state.perEvent['evt-1'], 1);
    },
  );

  // -------------------------------------------------------------------------
  // 3. Multiple event IDs — totals summed correctly with pending-only filter
  // -------------------------------------------------------------------------
  test('multiple events → sums only pending across all events', () async {
    final mock = MockListPendingForEventUseCase();

    when(
      () => mock(
        const ListPendingForEventParams(eventId: 'evt-1'),
      ),
    ).thenAnswer(
      (_) async => Right([
        _makeWithRequester('p1', JoinRequestStatus.pending),
        _makeWithRequester('a1', JoinRequestStatus.approved),
      ]),
    );
    when(
      () => mock(
        const ListPendingForEventParams(eventId: 'evt-2'),
      ),
    ).thenAnswer(
      (_) async => Right([
        _makeWithRequester('p2', JoinRequestStatus.pending),
        _makeWithRequester('p3', JoinRequestStatus.pending),
        _makeWithRequester('d1', JoinRequestStatus.declined),
      ]),
    );

    // Key must be sorted, comma-joined.
    const key = 'evt-1,evt-2';
    final container = _makeContainer(mock, key);
    await container
        .read(hostingPendingCountControllerProvider(key).notifier)
        .refresh();

    final state = container.read(hostingPendingCountControllerProvider(key));
    expect(state.total, 3); // 1 from evt-1 + 2 from evt-2
    expect(state.perEvent['evt-1'], 1);
    expect(state.perEvent['evt-2'], 2);
  });

  // -------------------------------------------------------------------------
  // 4. Use-case failure → total stays 0; event id in failedEventIds
  // -------------------------------------------------------------------------
  test('use-case failure → total 0 and event id in failedEventIds', () async {
    final mock = MockListPendingForEventUseCase();
    when(() => mock(any())).thenAnswer(
      (_) async => const Left(ServerFailure('network error')),
    );

    const key = 'evt-1';
    final container = _makeContainer(mock, key);
    await container
        .read(hostingPendingCountControllerProvider(key).notifier)
        .refresh();

    final state = container.read(hostingPendingCountControllerProvider(key));
    expect(state.total, 0);
    expect(state.failedEventIds, contains('evt-1'));
  });
}
