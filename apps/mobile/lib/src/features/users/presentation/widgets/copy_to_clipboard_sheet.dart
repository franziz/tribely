import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';

/// Fallback sheet shown when url_launcher cannot open a mail client
/// (e.g. some Android setups have no email app installed).
///
/// Copies the pre-composed mailto body to the clipboard and shows a
/// confirmation so the user can paste it manually into any email client.
///
/// Present with [showModalBottomSheet] from the ROOT navigator context.
class CopyToClipboardSheet extends StatefulWidget {
  const CopyToClipboardSheet({required this.content, super.key});

  /// The pre-formatted mailto body to copy to the clipboard.
  final String content;

  @override
  State<CopyToClipboardSheet> createState() => _CopyToClipboardSheetState();
}

class _CopyToClipboardSheetState extends State<CopyToClipboardSheet> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle.
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: dark
                    ? TribelyColors.nightBorderSubtle
                    : TribelyColors.paperBorderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No email app found',
            style: TribelyType.headline(ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "We couldn't open an email app on this device. Copy the message "
            'below and paste it into your preferred email client, then send '
            'it to support@gotribely.com.',
            style: TribelyType.bodyM(inkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _copied ? 'Copied!' : 'Copy message',
            onPressed: _copied ? null : _copy,
            state: PrimaryButtonState.idle,
          ),
          if (_copied) ...[
            const SizedBox(height: 8),
            Text(
              'Message copied to clipboard.',
              style: TribelyType.caption(inkSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
