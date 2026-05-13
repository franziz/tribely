import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';

/// 65%-height keyboard-aware bottom sheet for the host to write a decline
/// reason before rejecting a join request.
///
/// Design spec:
///   - Drag handle: 32×4dp centred.
///   - Title: "Let [FirstName] know why" (headline/22 semibold).
///   - Sub-copy: "A brief, kind note goes a long way. They'll appreciate the
///     honesty." (bodyM/15, paperInkSecondary).
///   - Multi-line text field (4 lines min), 200 char limit.
///   - Char counter right-aligned caption; turns paperAccent at ≥180.
///   - Live region announces remaining chars at 150 and 180 thresholds.
///   - Submit button: "Send rejection". Disabled until non-empty (trimmed).
///   - Cancel text button.
///   - Dismiss protection: once input is non-empty, prevents swipe-to-dismiss
///     and shows a confirmation AlertDialog on Cancel / back tap.
///   - On submit: button enters loading. Sheet auto-dismisses on success.
///   - On failure: inline BannerMessage above button; sheet stays open.
///
/// [requesterDisplayName]: full display name — first token used in the title.
/// [onSubmit]: async callback that performs the decline API call. Return null
///   on success; return a non-null error message string on failure.
class DeclineReasonSheet extends StatefulWidget {
  const DeclineReasonSheet({
    required this.requesterDisplayName,
    required this.onSubmit,
    super.key,
  });

  final String requesterDisplayName;

  /// Called with the trimmed reason text. Return null on success; return an
  /// error message string if the operation failed.
  final Future<String?> Function(String reason) onSubmit;

  @override
  State<DeclineReasonSheet> createState() => _DeclineReasonSheetState();
}

class _DeclineReasonSheetState extends State<DeclineReasonSheet> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  // Live-region a11y tracking — announce at 150 and 180 remaining chars.
  // We track the last threshold to avoid repeated announcements on every keystroke.
  int _lastAnnouncedThreshold = -1;
  String _liveAnnouncement = '';

  static const int _maxLength = 200;
  static const int _warnThreshold = 180;
  static const int _announceAt150 = 150;
  static const int _announceAt180 = 180;

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
    if (remaining == _announceAt150 && _lastAnnouncedThreshold != 150) {
      _lastAnnouncedThreshold = 150;
      setState(() => _liveAnnouncement = '$remaining characters remaining');
    } else if (remaining == _announceAt180 && _lastAnnouncedThreshold != 180) {
      _lastAnnouncedThreshold = 180;
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
        title: const Text('Abandon this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Writing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
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
                        'Let $_firstNameOnly know why',
                        style: TribelyType.headline(
                          TribelyColors.paperInkPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Sub-copy.
                      Text(
                        "A brief, kind note goes a long way. They'll appreciate the honesty.",
                        style: TribelyType.bodyM(
                          TribelyColors.paperInkSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Text field — multiline, 4 lines min.
                      _ReasonTextField(
                        controller: _controller,
                        enabled: !_isSubmitting,
                        maxLength: _maxLength,
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
                      // Live-region for a11y char-limit announcements at 150/180.
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
                      // Submit button.
                      PrimaryButton(
                        label: 'Send rejection',
                        state: _isSubmitting
                            ? PrimaryButtonState.loading
                            : PrimaryButtonState.idle,
                        onPressed: (_hasInput && !_isSubmitting)
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
                            'Cancel',
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

class _ReasonTextField extends StatelessWidget {
  const _ReasonTextField({
    required this.controller,
    required this.enabled,
    required this.maxLength,
  });

  final TextEditingController controller;
  final bool enabled;
  final int maxLength;

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
                  null, // hide the built-in counter; we draw our own above
          style: TribelyType.bodyM(TribelyColors.paperInkPrimary),
          cursorColor: TribelyColors.paperAccent,
          cursorWidth: 1.5,
          decoration: InputDecoration(
            hintText:
                'e.g. "I\'ve already got a full group for this one — hope to cross paths at another event!"',
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

/// Shows [DeclineReasonSheet] as a 65%-height drag-protected modal bottom sheet.
///
/// [isDismissible] is forced to false so the outer sheet framework doesn't
/// dismiss while typing. Dismiss-on-empty and back-gesture protection are
/// handled inside [DeclineReasonSheet] itself via [PopScope].
Future<void> showDeclineReasonSheet(
  BuildContext context, {
  required String requesterDisplayName,
  required Future<String?> Function(String reason) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false, // dismiss-protection is managed inside the sheet
    enableDrag: false, // same: drag-dismiss blocked when input is non-empty
    builder: (_) => DeclineReasonSheet(
      requesterDisplayName: requesterDisplayName,
      onSubmit: onSubmit,
    ),
  );
}
