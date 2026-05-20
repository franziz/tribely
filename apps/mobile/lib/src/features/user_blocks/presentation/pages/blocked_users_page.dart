import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../domain/entities/blocked_user_summary.dart';
import '../providers/user_block_providers.dart';
import '../state/blocks_state.dart';
import '../string_assets/block_copy.dart';

/// Blocked Users page — route: /settings/blocked-users.
///
/// Displays a paginated list of users the authenticated user has blocked.
/// Each row shows avatar + display name + Unblock button.
/// Empty state, error state, and loading skeleton are all handled.
class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    final state = ref.watch(blocksControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Blocked Users', style: TribelyType.headline(ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: switch (state) {
        BlocksLoading() => const _LoadingBody(),
        BlocksEmpty() => _EmptyBody(inkSecondary: inkSecondary),
        BlocksFailure(:final message) => _ErrorBody(
          message: message,
          inkSecondary: inkSecondary,
          onRetry: () => ref.read(blocksControllerProvider.notifier).refresh(),
        ),
        BlocksLoaded(
          :final rows,
          :final isLoadingMore,
          :final paginationError,
          :final hasMore,
        ) =>
          _LoadedBody(
            rows: rows,
            isLoadingMore: isLoadingMore,
            paginationError: paginationError,
            hasMore: hasMore,
            ink: ink,
            inkSecondary: inkSecondary,
            onLoadMore: () =>
                ref.read(blocksControllerProvider.notifier).loadMore(),
            onUnblock: (userId, displayName) => _confirmUnblock(
              context,
              ref,
              userId: userId,
              displayName: displayName,
              ink: ink,
            ),
          ),
      },
    );
  }

  Future<void> _confirmUnblock(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
    required String displayName,
    required Color ink,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(BlockCopy.unblockDialogTitle(displayName)),
        content: const Text(BlockCopy.unblockDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(BlockCopy.unblockDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(BlockCopy.unblockDialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(blocksControllerProvider.notifier).unblock(userId);
    }
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SkeletonLoader(width: double.infinity, height: 64, borderRadius: 12),
          SizedBox(height: 12),
          SkeletonLoader(width: double.infinity, height: 64, borderRadius: 12),
          SizedBox(height: 12),
          SkeletonLoader(width: double.infinity, height: 64, borderRadius: 12),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.inkSecondary});
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              BlockCopy.emptyStateTitle,
              style: TribelyType.headline(inkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              BlockCopy.emptyStateSubtitle,
              style: TribelyType.bodyM(inkSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.inkSecondary,
    required this.onRetry,
  });
  final String message;
  final Color inkSecondary;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              style: TribelyType.bodyM(inkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.rows,
    required this.isLoadingMore,
    required this.paginationError,
    required this.hasMore,
    required this.ink,
    required this.inkSecondary,
    required this.onLoadMore,
    required this.onUnblock,
  });

  final List<BlockedUserSummary> rows;
  final bool isLoadingMore;
  final String? paginationError;
  final bool hasMore;
  final Color ink;
  final Color inkSecondary;
  final VoidCallback onLoadMore;
  final void Function(String userId, String displayName) onUnblock;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (hasMore &&
            n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: rows.length + (isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final row = rows[index];
          final displayName = row.displayName ?? BlockCopy.unknownUser;
          final avatarUrl = row.avatarUrl;
          final userId = row.blockedUserId;

          return _BlockedUserRow(
            displayName: displayName,
            avatarUrl: avatarUrl,
            ink: ink,
            inkSecondary: inkSecondary,
            onUnblock: () => onUnblock(userId, displayName),
          );
        },
      ),
    );
  }
}

class _BlockedUserRow extends StatelessWidget {
  const _BlockedUserRow({
    required this.displayName,
    required this.ink,
    required this.inkSecondary,
    required this.onUnblock,
    this.avatarUrl,
  });

  final String displayName;
  final String? avatarUrl;
  final Color ink;
  final Color inkSecondary;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final avatarBg = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarBg,
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TribelyType.bodyM(inkSecondary),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Display name
          Expanded(
            child: Text(
              displayName,
              style: TribelyType.bodyM(ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Unblock button
          OutlinedButton(
            onPressed: onUnblock,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Unblock', style: TribelyType.caption(ink)),
          ),
        ],
      ),
    );
  }
}
