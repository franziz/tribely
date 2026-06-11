import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';

/// Selfie capture overlay — CustomPainter per Designer spec (TRI-23 Brief E).
///
/// Paints:
///   - Black scrim at 40% opacity outside the oval cutout.
///   - Oval cutout ~68% viewport width, 4:5 aspect ratio, centered.
///   - 2dp stroke: [TribelyColors.paperSurfaceHigh] at 70% opacity (idle) →
///     success-green ([TribelyColors.paperSuccess]) on [OverlayFeedback.pass] →
///     accent-coral ([TribelyColors.paperAccent]) on [OverlayFeedback.block].
///   - 250ms easeInOutCubic tween between stroke states.
///   - Respects [MediaQuery.disableAnimations] (reduceMotion) — jumps instantly
///     instead of tweening when reduce-motion is enabled.
///
/// Placement is feature-scoped (YAGNI — EL ruling): do NOT move to core/widgets/.
class CameraOverlayWidget extends StatefulWidget {
  const CameraOverlayWidget({
    required this.feedback,
    super.key,
  });

  /// Current face-guidance feedback driving the stroke colour.
  final OverlayFeedback feedback;

  @override
  State<CameraOverlayWidget> createState() => _CameraOverlayWidgetState();
}

/// Feedback state that drives the oval stroke colour.
enum OverlayFeedback {
  /// No conclusive face data yet — neutral white stroke.
  idle,

  /// Face detected and all guidance checks pass — green stroke.
  pass,

  /// Face detected but a guidance check is failing — coral stroke.
  block,
}

class _CameraOverlayWidgetState extends State<CameraOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  OverlayFeedback _prevFeedback = OverlayFeedback.idle;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(CameraOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedback != widget.feedback) {
      _prevFeedback = oldWidget.feedback;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion) {
        _ctrl.value = 1.0;
      } else {
        _ctrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final strokeColor = _interpolatedStrokeColor(
          from: _prevFeedback,
          to: widget.feedback,
          t: _animation.value,
          dark: Theme.of(context).brightness == Brightness.dark,
        );
        return CustomPaint(
          painter: _OverlayPainter(strokeColor: strokeColor),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  /// Linearly interpolates between the stroke colors for [from] and [to]
  /// feedback states.
  static Color _interpolatedStrokeColor({
    required OverlayFeedback from,
    required OverlayFeedback to,
    required double t,
    required bool dark,
  }) {
    return Color.lerp(
          _strokeColor(from, dark: dark),
          _strokeColor(to, dark: dark),
          t,
        ) ??
        _strokeColor(to, dark: dark);
  }

  static Color _strokeColor(OverlayFeedback feedback, {required bool dark}) =>
      switch (feedback) {
        OverlayFeedback.idle => (dark
            ? TribelyColors.nightInkPrimary
            : TribelyColors.paperSurfaceHigh)
            .withValues(alpha: 0.7),
        OverlayFeedback.pass => dark
            ? TribelyColors.nightSuccess
            : TribelyColors.paperSuccess,
        OverlayFeedback.block => dark
            ? TribelyColors.nightAccent
            : TribelyColors.paperAccent,
      };
}

/// CustomPainter that draws the scrim + oval cutout + stroke.
class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.strokeColor});

  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Oval dimensions: ~68% viewport width, 4:5 aspect ratio, centered.
    final ovalWidth = size.width * 0.68;
    final ovalHeight = ovalWidth * (5 / 4);
    final left = (size.width - ovalWidth) / 2;
    final top = (size.height - ovalHeight) / 2;
    final ovalRect = Rect.fromLTWH(left, top, ovalWidth, ovalHeight);
    final ovalPath = Path()..addOval(ovalRect);

    // Scrim — full canvas minus the oval cutout.
    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      scrimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    // Oval stroke.
    canvas.drawPath(
      ovalPath,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor;
}
