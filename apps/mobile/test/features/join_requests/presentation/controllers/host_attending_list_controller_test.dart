// Controller tests for HostAttendingListController.
//
// Covers:
//   1. build() → initial state Loading → transitions to Loaded on success.
//   2. _load() failure → transitions to Error.
//   3. retry() re-invokes the use case.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request_with_requester.dart';
import 'package:tribely/src/features/join_requests/domain/usecases/list_approved_for_event_usecase.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/host_attending_list_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/host_attending_list_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockListApprovedForEventUseCase extends Mock
    implements ListApprovedForEventUseCase {}

class FakeListApprovedForEventParams extends Fake
    implements ListApprovedForEventParams {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testEventId = 'evt-attending-test';

JoinRequestWithRequester _makeItem(String id, String name) =>
    JoinRequestWithRequester(
      joinRequest: JoinRequest(
        id: id,
        eventId: _testEventId,
        requesterUserId: 'user-$id',
        status: JoinRequestStatus.approved,
        requestedAt: DateTime.utc(2026, 5, 1),
      ),
      requester: JoinRequestRequesterSummary(id: 'user-$id', displayName: name),
    );

// ---------------------------------------------------------------------------
// Container factory
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer(MockListApprovedForEventUseCase mock) {
  final container = ProviderContainer(
    overrides: [
      listApprovedForEventUseCaseProvider.overrideWithValue(mock),
    ],
  );
  addTearDown(container.dispose);
  // Eagerly read so build() fires and schedules the initial _load microtask.
  container.read(hostAttendingListControllerProvider(_testEventId));
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeListApprovedForEventParams());
  });

  // -------------------------------------------------------------------------
  // 1. load() success → HostAttendingListLoaded with returned items
  // -------------------------------------------------------------------------
  test('load() success → HostAttendingListLoaded with returned items', () async {
    final mock = MockListApprovedForEventUseCase();
    final items = [_makeItem('jr-1', 'Alice'), _makeItem('jr-2', 'Bob')];

    when(() => mock(any())).thenAnswer((_) async => Right(items));

    final container = _makeContainer(mock);
    await container
        .read(hostAttendingListControllerProvider(_testEventId).notifier)
        .retry();

    final state = container.read(hostAttendingListControllerProvider(_testEventId));
    expect(state, isA<HostAttendingListLoaded>());
    expect((state as HostAttendingListLoaded).items, equals(items));
  });

  // -------------------------------------------------------------------------
  // 2. load() failure → HostAttendingListError
  // -------------------------------------------------------------------------
  test('load() NetworkFailure → HostAttendingListError', () async {
    final mock = MockListApprovedForEventUseCase();

    when(() => mock(any())).thenAnswer(
      (_) async => const Left(NetworkFailure('timeout')),
    );

    final container = _makeContainer(mock);
    await container
        .read(hostAttendingListControllerProvider(_testEventId).notifier)
        .retry();

    final state = container.read(hostAttendingListControllerProvider(_testEventId));
    expect(state, isA<HostAttendingListError>());
    expect(
      (state as HostAttendingListError).failure,
      isA<NetworkFailure>(),
    );
  });

  // -------------------------------------------------------------------------
  // 3. retry() re-invokes the use case
  // -------------------------------------------------------------------------
  test('retry() re-invokes the use case', () async {
    final mock = MockListApprovedForEventUseCase();
    final items = [_makeItem('jr-1', 'Alice')];

    when(() => mock(any())).thenAnswer((_) async => Right(items));

    final container = _makeContainer(mock);
    await container
        .read(hostAttendingListControllerProvider(_testEventId).notifier)
        .retry();

    verify(() => mock(any())).called(1);

    await container
        .read(hostAttendingListControllerProvider(_testEventId).notifier)
        .retry();

    verify(() => mock(any())).called(1);
  });
}
