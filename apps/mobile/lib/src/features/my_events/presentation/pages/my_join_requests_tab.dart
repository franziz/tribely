import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/ink_mark.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../join_requests/domain/entities/join_request.dart';
import '../../../join_requests/domain/entities/join_request_with_event.dart';
import '../../../join_requests/presentation/controllers/my_join_requests_controller.dart';
import '../../../join_requests/presentation/providers/join_requests_providers.dart';
import '../../../join_requests/presentation/state/my_join_requests_state.dart';
import '../../../join_requests/presentation/widgets/my_join_request_row.dart';

/// Content for the "Requested" tab in [MyEventsPage].
///
/// Displays a pull-to-refresh list of the current user's join requests,
/// showing event thumb + title + datetime + status pill. Pending rows get a
/// "Withdraw request" link at row bottom-right.
///
/// States:
///   - Loading: CircularProgressIndicator centred.
///   - Error: BannerMessage with retry button.
///   - Empty: InkMark glyph + copy + "Find something on Discover" button.
///   - Loaded: RefreshIndicator-wrapped ListView.
class MyJoinRequestsTab extends ConsumerWidget {
  const MyJoinRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // null eventId = all my requests.
    final state = ref.watch(myJoinRequestsControllerProvider(null));
    final controller = ref.read(
      myJoinRequestsControllerProvider(null).notifier,
    );

    return switch (state) {
      MyJoinRequestsLoading() => const _LoadingBody(),
      MyJoinRequestsError(:final failure) => _ErrorBody(
        message: failure.message,
        onRetry: controller.retry,
      ),
      MyJoinRequestsLoaded(:final items) when items.isEmpty => _EmptyBody(),
      MyJoinRequestsLoaded(:final items) => _LoadedBody(
        items: items,
        controller: controller,
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BannerMessage(
            message: message,
            action: BannerAction(label: 'Retry', onTap: onRetry),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const InkMark(
              size: 64,
              color: TribelyColors.paperInkSecondary,
              animate: false,
            ),
            const SizedBox(height: 16),
            Text(
              "You haven't requested any events yet.",
              textAlign: TextAlign.center,
              style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              child: PrimaryButton(
                label: 'Find something on Discover',
                onPressed: () => context.go('/events'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loaded list with pull-to-refresh
// ---------------------------------------------------------------------------

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.items, required this.controller});

  final List<JoinRequestWithEvent> items;
  final MyJoinRequestsController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: TribelyColors.paperBorderSubtle,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return _WithdrawableRow(item: item, controller: controller);
        },
      ),
    );
  }
}

/// Wraps [MyJoinRequestRow] with the withdraw dialog and local withdrawing state.
class _WithdrawableRow extends StatefulWidget {
  const _WithdrawableRow({required this.item, required this.controller});

  final JoinRequestWithEvent item;
  final MyJoinRequestsController controller;

  @override
  State<_WithdrawableRow> createState() => _WithdrawableRowState();
}

class _WithdrawableRowState extends State<_WithdrawableRow> {
  bool _isWithdrawing = false;

  Future<void> _handleWithdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw your request?'),
        content: const Text(
          'You can request again later if you change your mind.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isWithdrawing = true);
    await widget.controller.withdraw(widget.item.joinRequest.id);
    if (mounted) setState(() => _isWithdrawing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isPending =
        widget.item.joinRequest.status == JoinRequestStatus.pending;
    return MyJoinRequestRow(
      item: widget.item,
      onWithdraw: isPending ? _handleWithdraw : null,
      isWithdrawing: _isWithdrawing,
    );
  }
}
