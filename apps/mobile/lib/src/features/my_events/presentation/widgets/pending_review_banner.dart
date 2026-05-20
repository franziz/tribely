import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../reviews/domain/entities/pending_review_prompt.dart';
import '../controllers/pending_review_banner_controller.dart';
import '../state/pending_review_banner_state.dart';
import '../string_assets/pending_review_banner_copy.dart';

/// Foreground review-prompt banner shown at the top of My Events.
///
/// Renders only when [PendingReviewBannerController] is in the
/// [PendingReviewBannerVisible] state. All other states render [SizedBox.shrink].
///
/// Interactions:
///   - Tap card body OR "Write review" button → navigates to the review
///     composer (`/reviews/write?eventId=…&ratedUserId=…`) AND calls
///     [PendingReviewBannerController.onComposerNavigated] so the banner
///     dismisses for the remainder of the session.
///   - Tap × (top-right) → [PendingReviewBannerController.dismiss].
///
/// Session-only — no persistence across app restarts.
class PendingReviewBanner extends ConsumerWidget {
  const PendingReviewBanner({super.key});

  static final _dateFormat = DateFormat('d MMM');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pendingReviewBannerControllerProvider);

    return switch (state) {
      PendingReviewBannerVisible(:final prompt) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: _BannerCard(
          prompt: prompt,
          onTapCard: () {
            ref
                .read(pendingReviewBannerControllerProvider.notifier)
                .onComposerNavigated();
            context.push(
              '/reviews/write'
              '?eventId=${prompt.eventId}'
              '&ratedUserId=${prompt.ratedUserId}',
            );
          },
          onDismiss: () {
            ref.read(pendingReviewBannerControllerProvider.notifier).dismiss();
          },
          dateFormat: _dateFormat,
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ---------------------------------------------------------------------------
// Internal card widget — keeps PendingReviewBanner readable at a glance.
// ---------------------------------------------------------------------------

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.prompt,
    required this.onTapCard,
    required this.onDismiss,
    required this.dateFormat,
  });

  final PendingReviewPrompt prompt;
  final VoidCallback onTapCard;
  final VoidCallback onDismiss;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final p = prompt;

    final formattedDate = dateFormat.format(p.eventEndedAt);

    return Material(
      color: TribelyColors.paperAccentSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTapCard,
        borderRadius: BorderRadius.circular(12),
        splashColor: TribelyColors.paperPrimary.withValues(alpha: 0.06),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Counterpart avatar (32r = 64dp diameter).
                  _CounterpartAvatar(
                    avatarUrl: p.ratedUserAvatarUrl,
                    displayName: p.ratedUserDisplayName,
                  ),
                  const SizedBox(width: 12),
                  // Headline + caption.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            PendingReviewBannerCopy.headline(
                              p.ratedUserDisplayName,
                            ),
                            style: TribelyType.caption(
                              TribelyColors.paperInkPrimary,
                            ).copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            PendingReviewBannerCopy.caption(
                              p.eventTitle,
                              formattedDate,
                            ),
                            style: TribelyType.caption(
                              TribelyColors.paperInkSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Dismiss button — 24dp touch target.
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      iconSize: 16,
                      icon: const Icon(
                        Icons.close,
                        color: TribelyColors.paperInkSecondary,
                      ),
                      tooltip: 'Dismiss',
                      onPressed: onDismiss,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Primary action button — full-width inside the card.
              PrimaryButton(
                label: PendingReviewBannerCopy.buttonLabel,
                onPressed: onTapCard,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counterpart avatar
// ---------------------------------------------------------------------------

class _CounterpartAvatar extends StatelessWidget {
  const _CounterpartAvatar({required this.displayName, this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 32,
      backgroundColor: TribelyColors.paperBorderSubtle,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(
              initials,
              style: TribelyType.caption(
                TribelyColors.paperInkSecondary,
              ).copyWith(fontWeight: FontWeight.w600),
            )
          : null,
    );
  }
}
