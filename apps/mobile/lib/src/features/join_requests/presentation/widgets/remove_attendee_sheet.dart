import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../string_assets/remove_attendee_copy.dart';

/// 65%-height keyboard-aware bottom sheet for the host to write a removal
/// reason before removing an approved attendee from an event.
///
/// Design spec mirrors [DeclineReasonSheet] (EL Decision 6: duplicate at N=2,
/// revisit shared abstraction at N=3).
///
///   - Drag handle: 32×4dp centred.
///   - Title: "Remove {firstName}?" (headline/22 semibold).
///   - Sub-head: "This will remove them from {eventTitle}. You cannot undo this."
///     (bodyM/15, paperInkSecondary).
///   - Multi-line text field (4 lines min), 200 char limit.
///   - Char counter right-aligned caption; turns paperAccent at ≥180.
///   - Live region announces remaining chars at 50 and 20 thresholds.
///   - Submit button: "Remove {firstName}". Disabled until non-empty (trimmed).
///   - Cancel text button.
///   - Dismiss protection: once input is non-empty, prevents swipe-to-dismiss
///     and shows a confirmation AlertDialog on Cancel / back tap.
///   - On submit: button enters loading. Sheet auto-dismisses on success.
///   - On failure: inline BannerMessage above button; sheet stays open.
///
/// [eventTitle]: the event's display title — interpolated in the sub-head.
/// [requesterDisplayName]: full display name — first token used in the title.
/// [onSubmit]: async callback that performs the remove API call. Return null
///   on success; return a non-null error message string on failure.
class RemoveAttendeeSheet extends StatefulWidget {
  const RemoveAttendeeSheet({
    required this.eventTitle,
    required this.requesterDisplayName,
    required this.onSubmit,
    super.key,
  });

  final String eventTitle;
  final String requesterDisplayName;

  /// Called with the trimmed reason text. Return null on success; return an
  /// error message string if the operation failed.
  final Future<String?> Function(String reason) onSubmit;

  @override
  State<RemoveAttendeeSheet> createState() => _RemoveAttendeeSheetState();
}

class _RemoveAttendeeSheetState extends State<RemoveAttendeeSheet> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  // Live-region a11y tracking — announce at 50 and 20 remaining chars.
  // We track the last threshold to avoid repeated announcements on every keystroke.
  int _lastAnnouncedThreshold = -1;
  String _liveAnnouncement = '';

  static const int _maxLength = RemoveAttendeeCopy.maxLength;
  static const int _warnThreshold = 180;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() => _error = null); // clear error when user edits
    _maybeAnnounceRemaining();
  }

  void _maybeAnnounceRemaining() {
    final remaining = _maxLength - _controller.text.length;
    if (remaining == RemoveAttendeeCopy.announceAt50 &&
        _lastAnnouncedThreshold != RemoveAttendeeCopy.announceAt50) {
      _lastAnnouncedThreshold = RemoveAttendeeCopy.announceAt50;
      setState(() => _liveAnnouncement = '$remaining characters remaining');
    } else if (remaining == RemoveAttendeeCopy.announceAt20 &&
        _lastAnnouncedThreshold != RemoveAttendeeCopy.announceAt20) {
      _lastAnnouncedThreshold = RemoveAttendeeCopy.announceAt20;
      setState(() => _liveAnnouncement = '$remaining characters remaining');
    }
  }

  String get _firstNameOnly {
    final parts = widget.requesterDisplayName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : widget.requesterDisplayName;
  }

  bool get _hasInput => _controller.text.trim().isNotEmpty;

  Future<void> _handleSubmit() async {
    final reason = _controller.text.trim();
    if (reason.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final errorMessage = await widget.onSubmit(reason);

    if (!mounted) return;

    if (errorMessage != null) {
      setState(() {
        _isSubmitting = false;
        _error = errorMessage;
      });
    } else {
      // Success — sheet auto-dismisses.
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasInput) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(RemoveAttendeeCopy.discardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(RemoveAttendeeCopy.discardKeepWriting),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(RemoveAttendeeCopy.discardConfirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _controller.text.length;
    final counterColor = charCount >= _warnThreshold
        ? TribelyColors.paperAccent
        : TribelyColors.paperInkSecondary;

    final firstName = _firstNameOnly;
    final submitLabel = RemoveAttendeeCopy.submitLabel.replaceAll(
      '{firstName}',
      firstName,
    );
    final subhead = RemoveAttendeeCopy.subhead.replaceAll(
      '{eventTitle}',
      widget.eventTitle,
    );
    final fieldHint = RemoveAttendeeCopy.fieldHint.replaceAll(
      '{firstName}',
      firstName,
    );

    return PopScope(
      // Block back-gesture when input is non-empty.
      canPop: !_hasInput,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _hasInput) {
          final shouldDiscard = await _confirmDiscard();
          if (shouldDiscard && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Container(
        // 65% height + keyboard-aware padding.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        decoration: const BoxDecoration(
          color: TribelyColors.paperSurfaceHigh,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle.
                Center(
                  child: Padding(
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Headline.
                      Text(
                        RemoveAttendeeCopy.title.replaceAll(
                          '{firstName}',
                          firstName,
                        ),
                        style: TribelyType.headline(
                          TribelyColors.paperInkPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Sub-copy.
                      Text(
                        subhead,
                        style: TribelyType.bodyM(
                          TribelyColors.paperInkSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Text field — multiline, 4 lines min.
                      _RemoveReasonTextField(
                        controller: _controller,
                        enabled: !_isSubmitting,
                        maxLength: _maxLength,
                        hintText: fieldHint,
                      ),
                      const SizedBox(height: 4),
                      // Char counter — right-aligned.
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$charCount / $_maxLength',
                          style: TribelyType.caption(counterColor),
                        ),
                      ),
                      // Live-region for a11y char-limit announcements at 50/20.
                      // Zero-size — purely semantic. Excluded from visual layout.
                      if (_liveAnnouncement.isNotEmpty)
                        Semantics(
                          liveRegion: true,
                          child: SizedBox(
                            height: 0,
                            child: Text(
                              _liveAnnouncement,
                              style: const TextStyle(fontSize: 0),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Error banner.
                      if (_error != null) ...[
                        BannerMessage(message: _error!),
                        const SizedBox(height: 16),
                      ],
                      // Submit button — primary style (designer: destructive
                      // intent acceptable with existing primary variant at N=1).
                      PrimaryButton(
                        label: submitLabel,
                        state: _isSubmitting
                            ? PrimaryButtonState.loading
                            : PrimaryButtonState.idle,
                        onPressed:
                            (_hasInput &&
                                !_isSubmitting &&
                                charCount <= _maxLength)
                            ? _handleSubmit
                            : null,
                      ),
                      const SizedBox(height: 12),
                      // Cancel text link.
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  if (!_hasInput) {
                                    Navigator.of(context).pop();
                                    return;
                                  }
                                  final shouldDiscard = await _confirmDiscard();
                                  if (shouldDiscard && context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          child: Text(
                            RemoveAttendeeCopy.cancelLabel,
                            style: TribelyType.button(
                              TribelyColors.paperInkSecondary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-line reason text field
// ---------------------------------------------------------------------------

class _RemoveReasonTextField extends StatelessWidget {
  const _RemoveReasonTextField({
    required this.controller,
    required this.enabled,
    required this.maxLength,
    required this.hintText,
  });

  final TextEditingController controller;
  final bool enabled;
  final int maxLength;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TribelyColors.paperBorderSubtle, width: 1.5),
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: TextField(
          controller: controller,
          enabled: enabled,
          maxLength: maxLength,
          maxLines: null, // unlimited height
          minLines: 4,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null, // hide built-in counter; we draw our own
          style: TribelyType.bodyM(TribelyColors.paperInkPrimary),
          cursorColor: TribelyColors.paperAccent,
          cursorWidth: 1.5,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TribelyType.bodyM(
              TribelyColors.paperInkSecondary.withValues(alpha: 0.7),
            ),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

/// Shows [RemoveAttendeeSheet] as a 65%-height drag-protected modal bottom sheet.
///
/// [isDismissible] is forced to false so the outer sheet framework doesn't
/// dismiss while typing. Dismiss-on-empty and back-gesture protection are
/// handled inside [RemoveAttendeeSheet] itself via [PopScope].
Future<void> showRemoveAttendeeSheet(
  BuildContext context, {
  required String eventTitle,
  required String requesterDisplayName,
  required Future<String?> Function(String reason) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false, // dismiss-protection is managed inside the sheet
    enableDrag: false, // same: drag-dismiss blocked when input is non-empty
    builder: (_) => RemoveAttendeeSheet(
      eventTitle: eventTitle,
      requesterDisplayName: requesterDisplayName,
      onSubmit: onSubmit,
    ),
  );
}
