import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/cancel_event_usecase.dart';
import '../../domain/usecases/clear_event_draft_usecase.dart';
import '../../domain/usecases/create_event_usecase.dart';
import '../../domain/usecases/load_event_draft_usecase.dart';
import '../../domain/usecases/save_event_draft_usecase.dart';
import '../../domain/usecases/replace_cover_photo_usecase.dart';
import '../../domain/usecases/upload_cover_photo_usecase.dart';
import '../controllers/create_event_controller.dart';
import '../state/create_event_state.dart';

// ---------------------------------------------------------------------------
// Use cases — resolved from the GetIt service locator.
// Register implementations in apps/mobile/lib/src/core/di/service_locator.dart.
// ---------------------------------------------------------------------------

final createEventUseCaseProvider = Provider<CreateEventUseCase>(
  (_) => sl<CreateEventUseCase>(),
);

final saveEventDraftUseCaseProvider = Provider<SaveEventDraftUseCase>(
  (_) => sl<SaveEventDraftUseCase>(),
);

final loadEventDraftUseCaseProvider = Provider<LoadEventDraftUseCase>(
  (_) => sl<LoadEventDraftUseCase>(),
);

final clearEventDraftUseCaseProvider = Provider<ClearEventDraftUseCase>(
  (_) => sl<ClearEventDraftUseCase>(),
);

final cancelEventUseCaseProvider = Provider<CancelEventUseCase>(
  (_) => sl<CancelEventUseCase>(),
);

final uploadCoverPhotoUseCaseProvider = Provider<UploadCoverPhotoUseCase>(
  (_) => sl<UploadCoverPhotoUseCase>(),
);

final replaceCoverPhotoUseCaseProvider = Provider<ReplaceCoverPhotoUseCase>(
  (_) => sl<ReplaceCoverPhotoUseCase>(),
);

// ---------------------------------------------------------------------------
// Controller — Riverpod 3.x NotifierProvider API (mirrors auth_providers.dart:52-53)
// ---------------------------------------------------------------------------

final createEventControllerProvider =
    NotifierProvider<CreateEventController, CreateEventState>(
      CreateEventController.new,
    );
