import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../error/failures.dart';
import '../providers/get_user_profile_usecase_provider.dart';
import 'banner_message.dart';
import 'skeleton_loader.dart';
import '../../features/users/domain/entities/user_profile.dart';

/// Minimal profile bottom sheet shown when a host taps a requester's
/// avatar or name in the Pending or Attending section.
///
/// Lives in `core/widgets/` so any feature can import it without triggering
/// the cross-feature `presentation/`-to-`presentation/` A11 rule.
///
/// Sheet displays:
///   - Large avatar placeholder (96dp circle) — real avatar deferred to TRI-23.
///   - Display name (headline style).
///   - "Member since {Month YYYY}" derived from [UserProfile.createdAt].
///   - Close affordance (top-right X icon).
///
/// States:
///   - Loading: avatar placeholder + 2 shimmer text lines.
///   - Loaded: avatar + display name + member-since text.
///   - Error: banner with retry CTA.
///
/// Non-goals: bio, event history, mutual connections, follow/block, messaging.
/// No navigation to a full profile page.
class RequesterProfileSheet extends ConsumerWidget {
  const RequesterProfileSheet({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(userProfileByIdProvider(userId));

    return Container(
      decoration: const BoxDecoration(
        color: TribelyColors.paperSurfaceHigh,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle.
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: TribelyColors.paperBorderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Close button — top-right, always visible.
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.close),
                color: TribelyColors.paperInkSecondary,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              MediaQuery.paddingOf(context).bottom + 32,
            ),
            child: asyncProfile.when(
              loading: () => _LoadingBody(),
              error: (error, _) => _ErrorBody(
                message: _messageFor(error),
                onRetry: () => ref.invalidate(userProfileByIdProvider(userId)),
              ),
              data: (profile) => _LoadedBody(
                displayName: profile.displayName,
                createdAt: profile.createdAt,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _messageFor(Object error) {
    if (error is NetworkFailure)
      return "Couldn't reach Tribely. Check your connection.";
    if (error is ServerFailure && error.statusCode == 404)
      return 'User not found.';
    if (error is ServerFailure) return 'Something went wrong. Try again.';
    if (error is Failure) return error.message;
    return 'Something went wrong. Try again.';
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar placeholder circle — 96dp.
        const SkeletonLoader(width: 96, height: 96, borderRadius: 48.0),
        const SizedBox(height: 16),
        // Name shimmer line (~50% width).
        SkeletonLoader(
          width: MediaQuery.sizeOf(context).width * 0.5,
          height: 22,
          borderRadius: 6,
        ),
        const SizedBox(height: 10),
        // Member-since shimmer line (~35% width).
        SkeletonLoader(
          width: MediaQuery.sizeOf(context).width * 0.35,
          height: 14,
          borderRadius: 4,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error body
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return BannerMessage(
      message: message,
      action: BannerAction(label: 'Retry', onTap: onRetry),
    );
  }
}

// ---------------------------------------------------------------------------
// Loaded body
// ---------------------------------------------------------------------------

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.displayName, required this.createdAt});

  final String displayName;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    // "Member since January 2026" — English-only per PM AC.
    final memberSince = DateFormat.yMMMM('en').format(createdAt);

    return Column(
      children: [
        // Large avatar placeholder — 96dp circle.
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: TribelyColors.paperBorderSubtle,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person,
            size: 48,
            color: TribelyColors.paperInkSecondary,
          ),
        ),
        const SizedBox(height: 16),
        // Display name.
        Text(
          displayName,
          style: TribelyType.headline(TribelyColors.paperInkPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        // Member since copy.
        Text(
          'Member since $memberSince',
          style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Public show helper
// ---------------------------------------------------------------------------

/// Opens [RequesterProfileSheet] as a drag-dismissible modal bottom sheet.
Future<void> showRequesterProfileSheet(BuildContext context, String userId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => RequesterProfileSheet(userId: userId),
  );
}
