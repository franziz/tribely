import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/storage/intro_flag_storage.dart';
import '../../data/datasources/check_ins_remote_datasource.dart';
import '../../domain/repositories/check_ins_repository.dart';
import '../../domain/usecases/acknowledge_check_in_usecase.dart';
import '../../domain/usecases/flag_check_in_usecase.dart';
import '../../domain/usecases/surface_pending_check_ins_usecase.dart';
import '../controllers/check_ins_controller.dart';
import '../controllers/safety_report_controller.dart';
import '../state/check_ins_state.dart';
import '../state/safety_report_state.dart';

// ---------------------------------------------------------------------------
// Datasource
// ---------------------------------------------------------------------------

final checkInsRemoteDataSourceProvider = Provider<CheckInsRemoteDataSource>(
  (_) => sl<CheckInsRemoteDataSource>(),
);

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final checkInsRepositoryProvider = Provider<CheckInsRepository>(
  (_) => sl<CheckInsRepository>(),
);

// ---------------------------------------------------------------------------
// Use cases — resolved from the GetIt service locator.
// Register implementations in apps/mobile/lib/src/core/di/service_locator.dart.
// ---------------------------------------------------------------------------

final surfacePendingCheckInsUseCaseProvider =
    Provider<SurfacePendingCheckInsUseCase>(
      (_) => sl<SurfacePendingCheckInsUseCase>(),
    );

final acknowledgeCheckInUseCaseProvider = Provider<AcknowledgeCheckInUseCase>(
  (_) => sl<AcknowledgeCheckInUseCase>(),
);

final flagCheckInUseCaseProvider = Provider<FlagCheckInUseCase>(
  (_) => sl<FlagCheckInUseCase>(),
);

// ---------------------------------------------------------------------------
// Controller
//
// autoDispose: discards state when no widget is listening (e.g. signed-out
// state). The controller itself extends Notifier<CheckInsState> (not
// AutoDisposeNotifier — not exported in our Riverpod 3.x version per CLAUDE.md).
// ---------------------------------------------------------------------------

final checkInsControllerProvider =
    NotifierProvider.autoDispose<CheckInsController, CheckInsState>(
      CheckInsController.new,
    );

// ---------------------------------------------------------------------------
// IntroFlagStorage — bridges GetIt singleton into Riverpod for the overlay.
// ---------------------------------------------------------------------------

final introFlagStorageProvider = Provider<IntroFlagStorage>(
  (_) => sl<IntroFlagStorage>(),
);

// ---------------------------------------------------------------------------
// SafetyReport page controller
// ---------------------------------------------------------------------------

final safetyReportControllerProvider =
    NotifierProvider<SafetyReportController, SafetyReportState>(
      SafetyReportController.new,
    );
