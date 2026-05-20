import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/delete_account_usecase.dart';
import '../controllers/delete_account_controller.dart';
import '../state/delete_account_state.dart';

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

/// Exposes [DeleteAccountUseCase] to the widget tree via the get_it service
/// locator. Not autoDisposed — the use case is stateless.
final deleteAccountUseCaseProvider = Provider<DeleteAccountUseCase>(
  (_) => sl<DeleteAccountUseCase>(),
);

// ---------------------------------------------------------------------------
// Controller providers
// ---------------------------------------------------------------------------

/// Drives the [DeleteAccountPage] confirmation surface.
///
/// [NotifierProvider.autoDispose] so controller state (including the typed
/// token) is cleared when the page leaves the widget tree. Convention:
/// [Notifier<T>] + [NotifierProvider.autoDispose] per CLAUDE.md.
final deleteAccountControllerProvider =
    NotifierProvider.autoDispose<DeleteAccountController, DeleteAccountState>(
  DeleteAccountController.new,
);
