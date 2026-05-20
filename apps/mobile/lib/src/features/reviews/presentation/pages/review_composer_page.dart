import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/review.dart';
import '../providers/review_providers.dart';
import '../state/review_composer_state.dart';
import '../string_assets/review_copy.dart';
import '../widgets/edit_window_expiry_banner.dart';

/// Full-screen review composer route.
///
/// Used for both new submissions and edits:
/// - New review: [eventId] + [ratedUserId] required; [reviewId] null.
/// - Edit mode:  all three params required; prefills [prefillRating] and
///   [prefillComment]. Shows [EditWindowExpiryBanner] when the 24h window
///   has elapsed.
///
/// Route path: /reviews/write
/// Query params: eventId, ratedUserId, reviewId (optional), ratedUserName
class ReviewComposerPage extends ConsumerStatefulWidget {
  const ReviewComposerPage({
    required this.eventId,
    required this.ratedUserId,
    this.reviewId,
    this.ratedUserName,
    this.prefillRating,
    this.prefillComment,
    this.reviewCreatedAt,
    super.key,
  });

  final String eventId;
  final String ratedUserId;
  final String? reviewId;
  final String? ratedUserName;
  final int? prefillRating;
  final String? prefillComment;
  final DateTime? reviewCreatedAt;

  bool get isEditMode => reviewId != null;

  bool get isWindowExpired =>
      isEditMode &&
      reviewCreatedAt != null &&
      EditWindowExpiryBanner.isExpired(reviewCreatedAt!);

  @override
  ConsumerState<ReviewComposerPage> createState() => _ReviewComposerPageState();
}

class _ReviewComposerPageState extends ConsumerState<ReviewComposerPage> {
  late int? _selectedRating;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.prefillRating;
    _commentController = TextEditingController(
      text: widget.prefillComment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onStarTap(int star) {
    HapticFeedback.lightImpact();
    setState(() {
      // Tapping currently-selected star deselects it.
      _selectedRating = _selectedRating == star ? null : star;
    });
  }

  Future<void> _onSubmit() async {
    final rating = _selectedRating;
    if (rating == null) return;
    final controller = ref.read(reviewComposerControllerProvider.notifier);
    final comment = _commentController.text.trim().isEmpty
        ? null
        : _commentController.text.trim();

    if (widget.isEditMode) {
      // Build a stub Review for success state since the server returns 204.
      final original = Review(
        id: widget.reviewId!,
        eventId: widget.eventId,
        raterUserId: '',
        ratedUserId: widget.ratedUserId,
        rating: widget.prefillRating ?? rating,
        comment: widget.prefillComment,
        createdAt: widget.reviewCreatedAt ?? DateTime.now(),
        hidden: false,
      );
      await controller.edit(
        reviewId: widget.reviewId!,
        rating: rating,
        comment: comment,
        originalReview: original,
      );
    } else {
      await controller.submit(
        eventId: widget.eventId,
        ratedUserId: widget.ratedUserId,
        rating: rating,
        comment: comment,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    final composerState = ref.watch(reviewComposerControllerProvider);
    final isSubmitting = composerState is ReviewComposerSubmitting;
    final isSuccess = composerState is ReviewComposerSuccess;
    final isWindowExpired = widget.isWindowExpired;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode ? 'Edit Review' : 'Write a Review',
          style: TribelyType.headline(ink),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: isSuccess
            ? _SuccessBody(ink: ink, inkSecondary: inkSecondary)
            : _ComposerBody(
                widget: widget,
                selectedRating: _selectedRating,
                commentController: _commentController,
                onStarTap: _onStarTap,
                onSubmit: _onSubmit,
                isSubmitting: isSubmitting,
                isWindowExpired: isWindowExpired,
                composerState: composerState,
                ink: ink,
                inkSecondary: inkSecondary,
                primary: primary,
                border: border,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composer body
// ---------------------------------------------------------------------------

class _ComposerBody extends StatelessWidget {
  const _ComposerBody({
    required this.widget,
    required this.selectedRating,
    required this.commentController,
    required this.onStarTap,
    required this.onSubmit,
    required this.isSubmitting,
    required this.isWindowExpired,
    required this.composerState,
    required this.ink,
    required this.inkSecondary,
    required this.primary,
    required this.border,
  });

  final ReviewComposerPage widget;
  final int? selectedRating;
  final TextEditingController commentController;
  final ValueChanged<int> onStarTap;
  final VoidCallback onSubmit;
  final bool isSubmitting;
  final bool isWindowExpired;
  final ReviewComposerState composerState;
  final Color ink;
  final Color inkSecondary;
  final Color primary;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final remaining = 500 - commentController.text.length;
    final isNearLimit = remaining < 20;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Whom you're reviewing
          if (widget.ratedUserName != null) ...[
            Text(
              'Reviewing ${widget.ratedUserName}',
              style: TribelyType.bodyL(ink),
            ),
            const SizedBox(height: 20),
          ],

          // Edit window expired banner
          if (isWindowExpired) ...[
            const EditWindowExpiryBanner(),
            const SizedBox(height: 16),
          ],

          // Error banner
          if (composerState is ReviewComposerFailure) ...[
            BannerMessage(
              message: (composerState as ReviewComposerFailure).message,
            ),
            const SizedBox(height: 16),
          ],

          // Star input
          Text('Your rating', style: TribelyType.bodyM(inkSecondary)),
          const SizedBox(height: 8),
          _StarInput(
            selectedRating: selectedRating,
            onTap: onStarTap,
            primary: primary,
            inkSecondary: inkSecondary,
            enabled: !isWindowExpired,
          ),
          if (selectedRating != null) ...[
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                ReviewCopy.ratingLabel(selectedRating!),
                key: ValueKey(selectedRating),
                style: TribelyType.caption(primary),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Composer notice (above comment field per spec)
          Text(
            ReviewCopy.composerNotice,
            style: TribelyType.caption(inkSecondary),
          ),
          const SizedBox(height: 12),

          // Comment field
          _CommentField(
            controller: commentController,
            enabled: !isWindowExpired,
            border: border,
            ink: ink,
            inkSecondary: inkSecondary,
            isNearLimit: isNearLimit,
            remaining: remaining,
          ),
          const SizedBox(height: 24),

          // Submit / Save button
          PrimaryButton(
            label: widget.isEditMode ? 'Save Changes' : 'Submit Review',
            onPressed:
                (selectedRating == null || isWindowExpired || isSubmitting)
                ? null
                : onSubmit,
            state: isSubmitting
                ? PrimaryButtonState.loading
                : PrimaryButtonState.idle,
          ),
          const SizedBox(height: 12),

          // Privacy link (below submit per spec)
          Center(
            child: Text(
              ReviewCopy.composerPrivacyLink,
              style: TribelyType.caption(inkSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Star input
// ---------------------------------------------------------------------------

class _StarInput extends StatelessWidget {
  const _StarInput({
    required this.selectedRating,
    required this.onTap,
    required this.primary,
    required this.inkSecondary,
    required this.enabled,
  });

  final int? selectedRating;
  final ValueChanged<int> onTap;
  final Color primary;
  final Color inkSecondary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final star = index + 1;
        final isFilled = selectedRating != null && star <= selectedRating!;
        return GestureDetector(
          onTap: enabled ? () => onTap(star) : null,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              isFilled ? Icons.star : Icons.star_border,
              size: 36,
              color: enabled
                  ? (isFilled ? primary : inkSecondary)
                  : inkSecondary.withValues(alpha: 0.4),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Comment field
// ---------------------------------------------------------------------------

class _CommentField extends StatefulWidget {
  const _CommentField({
    required this.controller,
    required this.enabled,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.isNearLimit,
    required this.remaining,
  });

  final TextEditingController controller;
  final bool enabled;
  final Color border;
  final Color ink;
  final Color inkSecondary;
  final bool isNearLimit;
  final int remaining;

  @override
  State<_CommentField> createState() => _CommentFieldState();
}

class _CommentFieldState extends State<_CommentField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final remaining = 500 - widget.controller.text.length;
    final isNearLimit = remaining < 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.border, width: 1.5),
          ),
          child: TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            maxLines: 5,
            maxLength: 500,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null, // hide built-in counter; we render our own
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TribelyType.bodyM(widget.ink),
            decoration: InputDecoration(
              hintText: 'Share your experience (optional)',
              hintStyle: TribelyType.bodyM(widget.inkSecondary),
              contentPadding: const EdgeInsets.all(14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$remaining remaining',
          style: TribelyType.caption(
            isNearLimit ? accent : widget.inkSecondary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Post-submit success state
// ---------------------------------------------------------------------------

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.ink, required this.inkSecondary});
  final Color ink;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: ink),
            const SizedBox(height: 20),
            Text(
              'Review submitted',
              style: TribelyType.headline(ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Thanks for sharing your experience.',
              style: TribelyType.bodyM(inkSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
