import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/get_event_detail_usecase.dart';
import '../controllers/event_detail_controller.dart';
import '../state/event_detail_state.dart';

// ---------------------------------------------------------------------------
// Use cases
// ---------------------------------------------------------------------------

final getEventDetailUseCaseProvider = Provider<GetEventDetailUseCase>(
  (_) => sl<GetEventDetailUseCase>(),
);

// ---------------------------------------------------------------------------
// Controller — autoDispose + family keyed by eventId.
//
// autoDispose: the detail page is ephemeral — when popped, the state is
// discarded, avoiding a stale cache that would show old data on re-entry.
//
// family(String): each eventId gets its own controller instance. Matches the
// UserProfileController pattern already established in this codebase.
// ---------------------------------------------------------------------------

final eventDetailControllerProvider = NotifierProvider.autoDispose
    .family<EventDetailController, EventDetailState, String>(
      EventDetailController.new,
    );
