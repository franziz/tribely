import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/approve_join_request_usecase.dart';
import '../../domain/usecases/decline_join_request_usecase.dart';
import '../../domain/usecases/list_approved_for_event_usecase.dart';
import '../../domain/usecases/list_my_join_requests_usecase.dart';
import '../../domain/usecases/list_pending_for_event_usecase.dart';
import '../../domain/usecases/request_to_join_event_usecase.dart';
import '../../domain/usecases/withdraw_join_request_usecase.dart';
import '../controllers/host_attending_list_controller.dart';
import '../controllers/host_pending_list_controller.dart';
import '../controllers/my_join_requests_controller.dart';
import '../controllers/request_to_join_controller.dart';
import '../state/host_attending_list_state.dart';
import '../state/host_pending_list_state.dart';
import '../state/my_join_requests_state.dart';
import '../state/request_to_join_state.dart';

// ---------------------------------------------------------------------------
// Use cases — resolved from the GetIt service locator.
// Register implementations in apps/mobile/lib/src/core/di/service_locator.dart.
// ---------------------------------------------------------------------------

final requestToJoinEventUseCaseProvider = Provider<RequestToJoinEventUseCase>(
  (_) => sl<RequestToJoinEventUseCase>(),
);

final approveJoinRequestUseCaseProvider = Provider<ApproveJoinRequestUseCase>(
  (_) => sl<ApproveJoinRequestUseCase>(),
);

final declineJoinRequestUseCaseProvider = Provider<DeclineJoinRequestUseCase>(
  (_) => sl<DeclineJoinRequestUseCase>(),
);

final withdrawJoinRequestUseCaseProvider = Provider<WithdrawJoinRequestUseCase>(
  (_) => sl<WithdrawJoinRequestUseCase>(),
);

final listPendingForEventUseCaseProvider = Provider<ListPendingForEventUseCase>(
  (_) => sl<ListPendingForEventUseCase>(),
);

final listApprovedForEventUseCaseProvider = Provider<ListApprovedForEventUseCase>(
  (_) => sl<ListApprovedForEventUseCase>(),
);

final listMyJoinRequestsUseCaseProvider = Provider<ListMyJoinRequestsUseCase>(
  (_) => sl<ListMyJoinRequestsUseCase>(),
);

// ---------------------------------------------------------------------------
// Controllers
//
// requestToJoinControllerProvider — autoDispose + family(eventId: String)
//   Each event page gets its own isolated CTA state. autoDispose discards the
//   state when the page is popped.
//
// hostPendingListControllerProvider — autoDispose + family(eventId: String)
//   Each host-side event detail page gets its own independent pending list.
//
// hostAttendingListControllerProvider — autoDispose + family(eventId: String)
//   Each host-side event detail page gets its own independent attending list.
//   Invalidated by HostPendingListController.approve() so the Attending section
//   reflects the newly approved requester without a manual refresh.
//
// myJoinRequestsControllerProvider — autoDispose + family(eventId: String?)
//   The joiner "My Requests" tab. family key is nullable: null = all requests,
//   non-null = filtered to a specific event.
// ---------------------------------------------------------------------------

final requestToJoinControllerProvider = NotifierProvider.autoDispose
    .family<RequestToJoinController, RequestToJoinState, String>(
      RequestToJoinController.new,
    );

final hostPendingListControllerProvider = NotifierProvider.autoDispose
    .family<HostPendingListController, HostPendingListState, String>(
      HostPendingListController.new,
    );

final hostAttendingListControllerProvider = NotifierProvider.autoDispose
    .family<HostAttendingListController, HostAttendingListState, String>(
      HostAttendingListController.new,
    );

final myJoinRequestsControllerProvider = NotifierProvider.autoDispose
    .family<MyJoinRequestsController, MyJoinRequestsState, String?>(
      MyJoinRequestsController.new,
    );
