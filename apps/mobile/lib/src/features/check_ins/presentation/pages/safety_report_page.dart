import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tribely_text_field.dart';
import '../providers/check_ins_providers.dart';
import '../state/check_ins_state.dart';
import '../string_assets/check_in_copy.dart';

/// Full-screen safety report form reached via "I need help" on [SafetyCheckInSheet].
///
/// The user enters a free-text report (max 2000 chars). On submit:
///   - Calls [CheckInsController.flagged] with the report body.
///   - On success: pushReplaces to [SafetyReportSubmittedPage].
///   - On failure: stays on this page and shows an inline error banner.
///
/// Back navigation cancels without confirmation. The controller state remains
/// [CheckInsShowing]; the check-in record stays `pending` server-side.
/// The next foreground-trigger will re-surface the prompt per M1's logic.
class SafetyReportPage extends ConsumerStatefulWidget {
  const SafetyReportPage({super.key});

  @override
  ConsumerState<SafetyReportPage> createState() => _SafetyReportPageState();
}

class _SafetyReportPageState extends ConsumerState<SafetyReportPage> {
  static const int _maxLength = 2000;
  static const int _warnThreshold = 1900;

  final _textController = TextEditingController();
  bool _submitting = false;
  Failure? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    final body = _textController.text.trim();
    if (body.isEmpty || body.length > _maxLength) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    // Drive the controller and observe the resulting state to determine
    // success vs. failure — the controller transitions to CheckInsError on
    // failure, and to CheckInsEmpty / CheckInsShowing(next) on success.
    await ref.read(checkInsControllerProvider.notifier).flagged(body);

    if (!mounted) return;

    final state = ref.read(checkInsControllerProvider);
    if (state is CheckInsError) {
      setState(() {
        _submitting = false;
        _error = state.failure;
      });
    } else {
      // Success — navigate to the terminal confirmation page.
      context.pushReplacement('/check-ins/safety-report/submitted');
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
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    return Scaffold(
      appBar: AppBar(
        title: Text(safetyReportPageTitle, style: TribelyType.headline(ink)),
      ),
      // Use a Column with an Expanded scroll area for the text field and a
      // pinned bottom button. This prevents layout overflow when the text
      // field grows with content.
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _textController,
          builder: (context, _) {
            final charCount = _textController.text.length;
            final isEmpty = charCount == 0;
            final isOverLimit = charCount > _maxLength;
            final isNearLimit = charCount >= _warnThreshold;
            final counterColor = isNearLimit ? accent : inkSecondary;
            final canSend = !isEmpty && !isOverLimit && !_submitting;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) ...[
                          BannerMessage(message: _error!.message),
                          const SizedBox(height: 16),
                        ],
                        TribelyTextField(
                          controller: _textController,
                          label: safetyReportPlaceholder,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 6,
                          maxLines: null,
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$charCount / $_maxLength',
                            style: TribelyType.caption(counterColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: PrimaryButton(
                    label: safetyReportSendCta,
                    onPressed: canSend ? _onSend : null,
                    state: _submitting
                        ? PrimaryButtonState.loading
                        : PrimaryButtonState.idle,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
