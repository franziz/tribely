import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/datasources/user_block_remote_datasource.dart';
import '../../domain/repositories/user_block_repository.dart';
import '../../domain/usecases/block_user_usecase.dart';
import '../../domain/usecases/list_my_blocks_usecase.dart';
import '../../domain/usecases/unblock_user_usecase.dart';
import '../controllers/block_action_controller.dart';
import '../controllers/blocks_controller.dart';
import '../state/block_action_state.dart';
import '../state/blocks_state.dart';

// ---------------------------------------------------------------------------
// Infrastructure — resolved from the GetIt service locator.
// Register implementations in apps/mobile/lib/src/core/di/service_locator.dart.
// ---------------------------------------------------------------------------

final userBlockRemoteDataSourceProvider = Provider<UserBlockRemoteDatasource>(
  (_) => sl<UserBlockRemoteDatasource>(),
);

final userBlockRepositoryProvider = Provider<UserBlockRepository>(
  (_) => sl<UserBlockRepository>(),
);

// ---------------------------------------------------------------------------
// Use cases — resolved from the GetIt service locator.
//
// [blockUserUseCaseProvider] is also consumed by reports/presentation/widgets/
// block_opt_in_sheet.dart via the sanctioned cross-feature provider reference.
// ---------------------------------------------------------------------------

final blockUserUseCaseProvider = Provider<BlockUserUseCase>(
  (_) => sl<BlockUserUseCase>(),
);

final unblockUserUseCaseProvider = Provider<UnblockUserUseCase>(
  (_) => sl<UnblockUserUseCase>(),
);

final listMyBlocksUseCaseProvider = Provider<ListMyBlocksUseCase>(
  (_) => sl<ListMyBlocksUseCase>(),
);

// ---------------------------------------------------------------------------
// Controllers
//
// blocksControllerProvider — autoDispose
//   Blocked Users page list. Single instance, auto-discarded on pop.
//
// blockActionControllerProvider — autoDispose
//   One-shot block confirm action. Discarded when the confirm sheet is dismissed.
// ---------------------------------------------------------------------------

final blocksControllerProvider =
    NotifierProvider.autoDispose<BlocksController, BlocksState>(
      BlocksController.new,
    );

final blockActionControllerProvider =
    NotifierProvider.autoDispose<BlockActionController, BlockActionState>(
      BlockActionController.new,
    );
