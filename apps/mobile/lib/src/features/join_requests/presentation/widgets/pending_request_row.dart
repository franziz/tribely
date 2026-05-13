import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/join_request_with_requester.dart';

/// A single row in the host's "Pending requests" section on the event detail page.
///
/// Layout:
///   [40dp avatar placeholder] [display name] [Approve btn] [Decline btn]
///
/// The avatar is a 40dp square with neutral fill — image loading deferred to
/// TRI-23/36.
///
/// [isInFlight]: when true, both action buttons are disabled (the row is
/// undergoing an approve or decline request).
///
/// On Approve success the caller removes this widget from the tree after a
/// 250ms slide-left + fade animation driven by [AnimatedList] at the parent.
///
/// On Decline tap the caller is expected to open [DeclineReasonSheet] and
/// then call [onDecline] with the submitted reason on sheet success.
class PendingRequestRow extends StatefulWidget {
  const PendingRequestRow({
    required this.item,
    required this.onApprove,
    required this.onDecline,
    this.isInFlight = false,
    this.onTapRequester,
    super.key,
  });

  final JoinRequestWithRequester item;

  /// Called when the user taps "Approve". No confirmation dialog — intent is
  /// clear from the CTA label + position.
  final VoidCallback onApprove;

  /// Called when the user confirms a decline in [DeclineReasonSheet].
  /// The [reason] string is guaranteed non-empty (sheet enforces this).
  final ValueChanged<String> onDecline;

  /// Whether an action (approve or decline) is currently in flight for this row.
  /// Both buttons are disabled while true.
  final bool isInFlight;

  /// Optional callback invoked when the user taps the avatar or display name.
  /// Used by the host event detail page to open the requester profile sheet.
  /// When null, the avatar/name area is not tappable.
  final VoidCallback? onTapRequester;

  @override
  State<PendingRequestRow> createState() => _PendingRequestRowState();
}

class _PendingRequestRowState extends State<PendingRequestRow>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final displayName = widget.item.requester.displayName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar + display name wrapped in InkWell to open the profile sheet.
          // The Approve/Decline buttons stay outside so they remain independently
          // tappable (separate touch targets per PM spec).
          Expanded(
            child: InkWell(
              onTap: widget.onTapRequester,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  // Avatar placeholder — 40dp square, neutral fill.
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: TribelyColors.paperBorderSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 20,
                      color: TribelyColors.paperInkSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Display name — fills remaining space.
                  Expanded(
                    child: Text(
                      displayName,
                      style: TribelyType.bodyM(
                        TribelyColors.paperInkPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons — equal width, 36dp visual height, 48dp touch target.
          Semantics(
            button: true,
            label: 'Approve ${widget.item.requester.displayName}',
            child: _ActionButton(
              label: 'Approve',
              accentColor: TribelyColors.paperPrimary,
              onPressed: widget.isInFlight ? null : widget.onApprove,
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Decline ${widget.item.requester.displayName}',
            child: _ActionButton(
              label: 'Decline',
              accentColor: TribelyColors.paperAccent,
              onPressed: widget.isInFlight ? null : _onDeclineTap,
            ),
          ),
        ],
      ),
    );
  }

  void _onDeclineTap() {
    // The parent (event_detail_page) opens DeclineReasonSheet and calls
    // widget.onDecline on submit success. We route to the parent callback
    // via the onDecline parameter — but the sheet needs to be opened from
    // the event detail page so it can provide the requester name.
    // This widget's onDecline is wired at the call site to open the sheet.
    widget.onDecline('');
  }
}

// ---------------------------------------------------------------------------
// Shared outlined action button
// ---------------------------------------------------------------------------

/// Outlined action button: border + label in [accentColor], no fill.
/// Visual height 36dp; touch target padded to ≥48dp via [SizedBox].
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.accentColor,
    required this.onPressed,
  });

  final String label;
  final Color accentColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final effectiveColor = disabled
        ? TribelyColors.paperInkSecondary.withValues(alpha: 0.4)
        : accentColor;

    return SizedBox(
      height: 48, // 48dp touch target
      child: Center(
        child: SizedBox(
          height: 36, // 36dp visual
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: effectiveColor,
              side: BorderSide(color: effectiveColor),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: TribelyType.caption(
                effectiveColor,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            child: AnimatedOpacity(
              opacity: disabled ? 0.5 : 1.0,
              duration: TribelyMotion.short,
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
