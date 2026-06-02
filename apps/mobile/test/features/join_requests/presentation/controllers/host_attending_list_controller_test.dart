// Controller tests for HostAttendingListController.
//
// Covers:
//   1. build() → initial state Loading → transitions to Loaded on success.
//   2. _load() failure → transitions to Error.
//   3. retry() re-invokes the use case.
//   4. removeAttendee() happy path — optimistic remove, use case succeeds,
//      returns null (success signal to sheet).
//   5. removeAttendee() failure — use case returns Left, snapshot restored,
//      returns human-readable error string.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request_with_requester.dart';
import 'package:tribely/src/features/join_requests/domain/usecases/list_approved_for_event_usecase.dart';
import 'package:tribely/src/features/join_requests/domain/usecases/remove_attendee_usecase.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/host_attending_list_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockListApprovedForEventUseCase extends Mock
    implements ListApprovedForEventUseCase {}

class FakeListApprovedForEventParams extends Fake
    implements ListApprovedForEventParams {}

class MockRemoveAttendeeUseCase extends Mock implements RemoveAttendeeUseCase {}

class FakeRemoveAttendeeParams extends Fake implements RemoveAttendeeParams {}

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

ProviderContainer _makeContainer(
  MockListApprovedForEventUseCase listMock, {
  MockRemoveAttendeeUseCase? removeMock,
}) {
  final container = ProviderContainer(
    overrides: [
      listApprovedForEventUseCaseProvider.overrideWithValue(listMock),
      if (removeMock != null)
        removeAttendeeUseCaseProvider.overrideWithValue(removeMock),
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
    registerFallbackValue(FakeRemoveAttendeeParams());
  });

  // -------------------------------------------------------------------------
  // 1. load() success → HostAttendingListLoaded with returned items
  // -------------------------------------------------------------------------
  test(
    'load() success → HostAttendingListLoaded with returned items',
    () async {
      final mock = MockListApprovedForEventUseCase();
      final items = [_makeItem('jr-1', 'Alice'), _makeItem('jr-2', 'Bob')];

      when(() => mock(any())).thenAnswer((_) async => Right(items));

      final container = _makeContainer(mock);
      await container
          .read(hostAttendingListControllerProvider(_testEventId).notifier)
          .retry();

      final state = container.read(
        hostAttendingListControllerProvider(_testEventId),
      );
      expect(state, isA<HostAttendingListLoaded>());
      expect((state as HostAttendingListLoaded).items, equals(items));
    },
  );

  // -------------------------------------------------------------------------
  // 2. load() failure → HostAttendingListError
  // -------------------------------------------------------------------------
  test('load() NetworkFailure → HostAttendingListError', () async {
    final mock = MockListApprovedForEventUseCase();

    when(
      () => mock(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('timeout')));

    final container = _makeContainer(mock);
    await container
        .read(hostAttendingListControllerProvider(_testEventId).notifier)
        .retry();

    final state = container.read(
      hostAttendingListControllerProvider(_testEventId),
    );
    expect(state, isA<HostAttendingListError>());
    expect((state as HostAttendingListError).failure, isA<NetworkFailure>());
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

  // -------------------------------------------------------------------------
  // 4. removeAttendee() happy path — optimistic remove + success
  // -------------------------------------------------------------------------
  test(
    'removeAttendee() removes item optimistically and returns null on success',
    () async {
      final listMock = MockListApprovedForEventUseCase();
      final removeMock = MockRemoveAttendeeUseCase();

      final items = [_makeItem('jr-1', 'Alice'), _makeItem('jr-2', 'Bob')];
      when(() => listMock(any())).thenAnswer((_) async => Right(items));
      when(() => removeMock(any())).thenAnswer((_) async => const Right(unit));

      final container = _makeContainer(listMock, removeMock: removeMock);
      await container
          .read(hostAttendingListControllerProvider(_testEventId).notifier)
          .retry();

      // Confirm Loaded with 2 items.
      final stateBefore = container.read(
        hostAttendingListControllerProvider(_testEventId),
      );
      expect((stateBefore as HostAttendingListLoaded).items.length, equals(2));

      // Remove Alice.
      final result = await container
          .read(hostAttendingListControllerProvider(_testEventId).notifier)
          .removeAttendee(
            item: items.first,
            eventTitle: 'Morning Hike',
            reason: 'capacity concern',
          );

      expect(result, isNull); // null = success

      final stateAfter = container.read(
        hostAttendingListControllerProvider(_testEventId),
      );
      final loaded = stateAfter as HostAttendingListLoaded;
      expect(loaded.items.length, equals(1));
      expect(loaded.items.first.joinRequest.id, equals('jr-2'));
    },
  );

  // -------------------------------------------------------------------------
  // 5. removeAttendee() failure — restores snapshot, returns error string
  // -------------------------------------------------------------------------
  test(
    'removeAttendee() restores snapshot and returns error string on failure',
    () async {
      final listMock = MockListApprovedForEventUseCase();
      final removeMock = MockRemoveAttendeeUseCase();

      final items = [_makeItem('jr-1', 'Alice'), _makeItem('jr-2', 'Bob')];
      when(() => listMock(any())).thenAnswer((_) async => Right(items));
      when(
        () => removeMock(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('timeout')));

      final container = _makeContainer(listMock, removeMock: removeMock);
      await container
          .read(hostAttendingListControllerProvider(_testEventId).notifier)
          .retry();

      // Attempt remove — use case fails.
      final result = await container
          .read(hostAttendingListControllerProvider(_testEventId).notifier)
          .removeAttendee(
            item: items.first,
            eventTitle: 'Morning Hike',
            reason: 'reason',
          );

      expect(result, isNotNull); // non-null = error

      // Snapshot restored — still 2 items.
      final state = container.read(
        hostAttendingListControllerProvider(_testEventId),
      );
      expect((state as HostAttendingListLoaded).items.length, equals(2));
    },
  );
}
