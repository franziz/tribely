import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/support_ticket_draft.dart';
import '../providers/support_providers.dart';
import '../string_assets/support_copy.dart';
import 'support_contact_state.dart';

/// Drives the support contact form submission lifecycle.
///
/// Uses [Notifier<SupportContactState>] (not AutoDisposeNotifier — not exported
/// in our Riverpod 3.x version per CLAUDE.md). Auto-dispose is configured on
/// the provider via [NotifierProvider.autoDispose] in [supportContactControllerProvider].
class SupportContactController extends Notifier<SupportContactState> {
  @override
  SupportContactState build() => const SupportContactIdle();

  /// Submits a [SupportTicketDraft] to the backend.
  ///
  /// Transitions:
  ///   * → Submitting (in-flight)
  ///   * → Success(ticketId) (on success)
  ///   * → Error(message) (on failure)
  Future<void> submit(SupportTicketDraft draft) async {
    if (state is SupportContactSubmitting) return;

    state = const SupportContactSubmitting();

    final useCase = ref.read(submitSupportTicketUseCaseProvider);
    final result = await useCase(draft);

    if (!ref.mounted) return;

    state = result.fold(
      (failure) => SupportContactError(message: _messageFor(failure)),
      (submitResult) => SupportContactSuccess(ticketId: submitResult.id),
    );
  }

  /// Dismisses the error banner, returning to [SupportContactIdle].
  void dismissBanner() {
    if (state is SupportContactError) {
      state = const SupportContactIdle();
    }
  }

  // ---------------------------------------------------------------------------
  // Failure → user-facing copy
  // ---------------------------------------------------------------------------

  String _messageFor(Failure failure) {
    if (failure is RateLimitedFailure) {
      return supportRateLimitedBannerCopy;
    }
    return failure.message.isNotEmpty
        ? failure.message
        : supportGenericErrorBannerCopy;
  }
}

/// Provider for [SupportContactController].
///
/// Auto-disposed when the page leaves the tree — the form state should not
/// survive navigation away and back.
final supportContactControllerProvider =
    NotifierProvider.autoDispose<SupportContactController, SupportContactState>(
      SupportContactController.new,
    );
