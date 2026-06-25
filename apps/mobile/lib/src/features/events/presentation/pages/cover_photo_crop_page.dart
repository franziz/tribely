import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';

/// Full-screen 16:9 crop screen for event cover photos.
///
/// Route: `/events/create/crop-photo`
/// Entry:  `context.push('/events/create/crop-photo', extra: imageBytes)`
///         where [extra] is the raw [Uint8List] of the picked image.
///
/// Exit:   `context.pop(croppedImage)` on success — the caller (Brief 5
///         wizard integration) receives the cropped [Uint8List] via the
///         `GoRouter.push` future.
///
/// Design spec:
///   - `crop_your_image` [Crop] widget: 16:9, fixCropRect, interactive.
///   - Tribely-branded baseColor / maskColor / cornerDotBuilder.
///   - "Crop" CTA calls [CropController.crop()]; [onCropped] pops with bytes.
///   - [CropResult.error] → shows inline error banner; retry re-invokes crop.
class CoverPhotoCropPage extends ConsumerStatefulWidget {
  const CoverPhotoCropPage({required this.imageBytes, super.key});

  /// Raw bytes of the image to crop (loaded from the picked file by the
  /// source-sheet caller).
  final Uint8List imageBytes;

  @override
  ConsumerState<CoverPhotoCropPage> createState() => _CoverPhotoCropPageState();
}

class _CoverPhotoCropPageState extends ConsumerState<CoverPhotoCropPage> {
  final CropController _cropController = CropController();

  /// True while [CropController.crop] has been called and [onCropped] has
  /// not yet fired. Drives the button loading state.
  bool _isCropping = false;

  /// Non-null when [CropResult.error] fires. Cleared on next crop attempt.
  String? _errorMessage;

  @override
  void dispose() {
    // CropController has no explicit dispose — but dispose the state cleanly.
    super.dispose();
  }

  void _onCropPressed() {
    setState(() {
      _isCropping = true;
      _errorMessage = null;
    });
    _cropController.crop();
  }

  void _onCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        if (!mounted) return;
        // Return cropped bytes to the caller via GoRouter pop.
        context.pop<Uint8List>(croppedImage);
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() {
          _isCropping = false;
          _errorMessage = 'Could not crop image: ${cause.runtimeType}';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TribelyColors.paperInkPrimary,
      appBar: AppBar(
        backgroundColor: TribelyColors.paperInkPrimary,
        foregroundColor: TribelyColors.paperSurfaceHigh,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Adjust photo',
          style: TribelyType.bodyL(TribelyColors.paperSurfaceHigh),
        ),
      ),
      body: Column(
        children: [
          // Crop area — flex-fills the available space.
          Expanded(
            child: Crop(
              image: widget.imageBytes,
              controller: _cropController,
              aspectRatio: 16 / 9,
              fixCropRect: true,
              interactive: true,
              baseColor: TribelyColors.paperInkPrimary,
              maskColor: TribelyColors.paperInkPrimary.withValues(alpha: 0.6),
              cornerDotBuilder: (size, edgeAlignment) =>
                  const DotControl(color: TribelyColors.paperPrimary),
              progressIndicator: const CircularProgressIndicator(
                color: TribelyColors.paperSurfaceHigh,
              ),
              onCropped: _onCropped,
            ),
          ),
          // Bottom control area: error banner (if any) + Crop CTA.
          _BottomControls(
            isCropping: _isCropping,
            errorMessage: _errorMessage,
            onCropPressed: _onCropPressed,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom controls (CTA + optional error message)
// ---------------------------------------------------------------------------

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.isCropping,
    required this.errorMessage,
    required this.onCropPressed,
  });

  final bool isCropping;
  final String? errorMessage;
  final VoidCallback onCropPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TribelyColors.paperInkPrimary,
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (errorMessage != null) ...[
            Text(
              errorMessage!,
              style: TribelyType.caption(TribelyColors.paperAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
          PrimaryButton(
            label: 'Crop',
            state: isCropping
                ? PrimaryButtonState.loading
                : PrimaryButtonState.idle,
            onPressed: isCropping ? null : onCropPressed,
          ),
        ],
      ),
    );
  }
}
