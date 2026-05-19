import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/usecases/file_report_usecase.dart';
import '../controllers/report_composer_controller.dart';
import '../state/report_composer_state.dart';

// ---------------------------------------------------------------------------
// Infrastructure — resolved from the GetIt service locator.
// Register implementations in apps/mobile/lib/src/core/di/service_locator.dart.
// ---------------------------------------------------------------------------

final reportRemoteDataSourceProvider = Provider<ReportRemoteDatasource>(
  (_) => sl<ReportRemoteDatasource>(),
);

final reportRepositoryProvider = Provider<ReportRepository>(
  (_) => sl<ReportRepository>(),
);

// ---------------------------------------------------------------------------
// Use cases — resolved from the GetIt service locator.
// ---------------------------------------------------------------------------

final fileReportUseCaseProvider = Provider<FileReportUseCase>(
  (_) => sl<FileReportUseCase>(),
);

// ---------------------------------------------------------------------------
// Controllers
//
// reportComposerControllerProvider — autoDispose (sheet lifecycle).
//   One controller per sheet instance; discarded when the sheet is popped.
// ---------------------------------------------------------------------------

final reportComposerControllerProvider =
    NotifierProvider.autoDispose<ReportComposerController, ReportComposerState>(
      ReportComposerController.new,
    );
