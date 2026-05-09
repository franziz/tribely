import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 3-4% noise grain overlay — felt, not seen.
///
/// Performance notes:
///   - The dot positions + alphas are computed ONCE at first paint and
///     baked into a `ui.Picture` keyed by canvas size. Subsequent paints
///     just replay the picture (one cheap GPU call), so layout passes
///     during animations don't re-do the math.
///   - Wrapped in [RepaintBoundary] so adjacent animated siblings (parallax,
///     button pulses, focus glows) don't invalidate the grain layer. Without
///     this, the grain re-paints on every frame and turns the whole UI laggy.
///   - Cell size 6dp at density ~0.18 keeps the visual feel without the
///     ~600k-iteration paint of a denser sampling.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({required this.opacity, super.key});

  /// Recommended: 0.03 light, 0.04 dark (per spec).
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Opacity(
          opacity: opacity,
          child: CustomPaint(painter: _GrainPainter(), size: Size.infinite),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  static const _seed = 1337;
  static const _cellSize = 6.0;
  static const _density = 0.18;

  ui.Picture? _cached;
  Size? _cachedSize;

  ui.Picture _buildPicture(Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rng = Random(_seed);
    final paint = Paint()..color = const Color(0xFF000000);
    for (double y = 0; y < size.height; y += _cellSize) {
      for (double x = 0; x < size.width; x += _cellSize) {
        if (rng.nextDouble() < _density) {
          paint.color = Color.fromRGBO(0, 0, 0, rng.nextDouble() * 0.6 + 0.2);
          canvas.drawCircle(Offset(x, y), 0.6, paint);
        }
      }
    }
    return recorder.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_cached == null || _cachedSize != size) {
      _cached = _buildPicture(size);
      _cachedSize = size;
    }
    canvas.drawPicture(_cached!);
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => false;
}
