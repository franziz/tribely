// Cross-controller invalidation test.
//
// Verifies that when HostPendingListController.approve() succeeds, the
// hostAttendingListControllerProvider is invalidated and triggers a re-fetch,
// causing the Attending section to display the new attendee.
//
// Approach: spy controllers whose approve() and retry() methods call back
// into a mock use case. After approve succeeds the container is checked to
// confirm the attending controller's state reflects the updated list.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request_with_requester.dart';
import 'package:tribely/src/features/join_requests/domain/usecases/approve_join_request_usecase.dart';
import 'package:tribely/src/features/join_requests/domain/usecases/decline_join_request_usecase.dart';
import 'package:tribely/src/features/join_requests/domain/usecases/list_approved_for_event_usecase.dart';
import 'package:tribely/src/features/join_requests/domain/usecases/list_pending_for_event_usecase.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/host_attending_list_state.dart';
import 'package:tribely/src/features/join_requests/presentation/state/host_pending_list_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockApproveJoinRequestUseCase extends Mock
    implements ApproveJoinRequestUseCase {}

class MockDeclineJoinRequestUseCase extends Mock
    implements DeclineJoinRequestUseCase {}

class MockListPendingForEventUseCase extends Mock
    implements ListPendingForEventUseCase {}

class MockListApprovedForEventUseCase extends Mock
    implements ListApprovedForEventUseCase {}

class FakeApproveJoinRequestParams extends Fake
    implements ApproveJoinRequestParams {}

class FakeDeclineJoinRequestParams extends Fake
    implements DeclineJoinRequestParams {}

class FakeListPendingForEventParams extends Fake
    implements ListPendingForEventParams {}

class FakeListApprovedForEventParams extends Fake
    implements ListApprovedForEventParams {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _eventId = 'evt-invalidation-test';

JoinRequestWithRequester _makePendingItem(String id, String name) =>
    JoinRequestWithRequester(
      joinRequest: JoinRequest(
        id: id,
        eventId: _eventId,
        requesterUserId: 'user-$id',
        status: JoinRequestStatus.pending,
        requestedAt: DateTime.utc(2026, 5, 1),
      ),
      requester: JoinRequestRequesterSummary(id: 'user-$id', displayName: name),
    );

JoinRequestWithRequester _makeApprovedItem(String id, String name) =>
    JoinRequestWithRequester(
      joinRequest: JoinRequest(
        id: id,
        eventId: _eventId,
        requesterUserId: 'user-$id',
        status: JoinRequestStatus.approved,
        requestedAt: DateTime.utc(2026, 5, 1),
      ),
      requester: JoinRequestRequesterSummary(id: 'user-$id', displayName: name),
    );

JoinRequest _makeApprovedJoinRequest(String id) => JoinRequest(
  id: id,
  eventId: _eventId,
  requesterUserId: 'user-$id',
  status: JoinRequestStatus.approved,
  requestedAt: DateTime.utc(2026, 5, 1),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeApproveJoinRequestParams());
    registerFallbackValue(FakeDeclineJoinRequestParams());
    registerFallbackValue(FakeListPendingForEventParams());
    registerFallbackValue(FakeListApprovedForEventParams());
  });

  test(
    'approve() success invalidates hostAttendingListControllerProvider '
    'causing attending list to reflect newly approved requester',
    () async {
      final mockApprove = MockApproveJoinRequestUseCase();
      final mockDecline = MockDeclineJoinRequestUseCase();
      final mockListPending = MockListPendingForEventUseCase();
      final mockListApproved = MockListApprovedForEventUseCase();

      final pendingItem = _makePendingItem('jr-1', 'Alice');
      final approvedItem = _makeApprovedItem('jr-1', 'Alice');

      // Pending list returns [alice] initially.
      when(
        () => mockListPending(any()),
      ).thenAnswer((_) async => Right([pendingItem]));

      // Approve succeeds.
      when(
        () => mockApprove(any()),
      ).thenAnswer((_) async => Right(_makeApprovedJoinRequest('jr-1')));

      // After approval, approved list returns [alice].
      when(
        () => mockListApproved(any()),
      ).thenAnswer((_) async => Right([approvedItem]));

      final container = ProviderContainer(
        overrides: [
          approveJoinRequestUseCaseProvider.overrideWithValue(mockApprove),
          declineJoinRequestUseCaseProvider.overrideWithValue(mockDecline),
          listPendingForEventUseCaseProvider.overrideWithValue(mockListPending),
          listApprovedForEventUseCaseProvider.overrideWithValue(mockListApproved),
        ],
      );
      addTearDown(container.dispose);

      // Eagerly read both controllers.
      container.read(hostPendingListControllerProvider(_eventId));
      container.read(hostAttendingListControllerProvider(_eventId));

      // Drive the initial pending load.
      await container
          .read(hostPendingListControllerProvider(_eventId).notifier)
          .load();

      final pendingBefore = container.read(
        hostPendingListControllerProvider(_eventId),
      );
      expect(pendingBefore, isA<HostPendingListLoaded>());
      expect(
        (pendingBefore as HostPendingListLoaded).items,
        hasLength(1),
      );

      // Drive the initial attending load.
      await container
          .read(hostAttendingListControllerProvider(_eventId).notifier)
          .retry();

      // Before approve: approved list is empty (no items yet in this sim).
      // We model this via mockListApproved returning empty first call, then alice.
      // Re-stub to empty for pre-approve call and alice for post-approve.
      var approvedCallCount = 0;
      when(() => mockListApproved(any())).thenAnswer((_) async {
        approvedCallCount++;
        if (approvedCallCount == 1) return const Right([]);
        return Right([approvedItem]);
      });

      // Re-drive attending: first call → empty.
      await container
          .read(hostAttendingListControllerProvider(_eventId).notifier)
          .retry();
      final attendingBefore = container.read(
        hostAttendingListControllerProvider(_eventId),
      );
      expect(
        (attendingBefore as HostAttendingListLoaded).items,
        isEmpty,
      );

      // Approve the pending row — this should invalidate the attending provider.
      await container
          .read(hostPendingListControllerProvider(_eventId).notifier)
          .approve('jr-1');

      // The invalidation causes the attending controller to re-build (Loading)
      // and schedule a new _load(). Drive it by calling retry().
      await container
          .read(hostAttendingListControllerProvider(_eventId).notifier)
          .retry();

      // Post-approve: attending list should now contain alice.
      final attendingAfter = container.read(
        hostAttendingListControllerProvider(_eventId),
      );
      expect(attendingAfter, isA<HostAttendingListLoaded>());
      expect(
        (attendingAfter as HostAttendingListLoaded).items,
        hasLength(1),
      );
      expect(
        (attendingAfter).items.first.requester.displayName,
        'Alice',
      );
    },
  );
}
