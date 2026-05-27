import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/datasources/support_remote_data_source.dart';
import '../../domain/repositories/support_repository.dart';
import '../../domain/usecases/submit_support_ticket_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure — resolved from the GetIt service locator.
// Register implementations in apps/mobile/lib/src/core/di/service_locator.dart.
// ---------------------------------------------------------------------------

final supportRemoteDataSourceProvider = Provider<SupportRemoteDataSource>(
  (_) => sl<SupportRemoteDataSource>(),
);

final supportRepositoryProvider = Provider<SupportRepository>(
  (_) => sl<SupportRepository>(),
);

// ---------------------------------------------------------------------------
// Use cases — resolved from the GetIt service locator.
// ---------------------------------------------------------------------------

final submitSupportTicketUseCaseProvider = Provider<SubmitSupportTicketUseCase>(
  (_) => sl<SubmitSupportTicketUseCase>(),
);
