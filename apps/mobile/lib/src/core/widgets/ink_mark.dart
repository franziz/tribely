import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/typography.dart';

/// The Tribely ink mark — italic "Tr" set in Fraunces, the brand's display
/// face. Revealed via a soft left-to-right ink-wash using [ShaderMask].
///
/// Performance considerations:
///   - Wrapped in [RepaintBoundary] so its layer doesn't invalidate when
///     siblings (parallax, button pulses, focus glows) repaint.
///   - The [ShaderMask] is only used while the animation is in progress.
///     Once complete, the plain [Text] renders without a saveLayer — Flutter
///     can short-circuit straight to a glyph atlas blit.
class InkMark extends StatefulWidget {
  const InkMark({
    this.size = 80,
    this.color,
    this.animate = true,
    super.key,
  });

  final double size;
  final Color? color;
  final bool animate;

  @override
  State<InkMark> createState() => _InkMarkState();
}

class _InkMarkState extends State<InkMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: TribelyMotion.brand,
    );
    if (widget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? IconTheme.of(context).color ?? Colors.black;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final text = Text(
      'Tr',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: TribelyType.displayFamily,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        fontSize: widget.size * 0.92,
        color: color,
        height: 1.0,
        letterSpacing: -widget.size * 0.04,
      ),
    );

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(
            child: reduceMotion
                ? text
                : AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, child) {
                      final progress =
                          Curves.easeOutCubic.transform(_ctrl.value);
                      // Once revealed, render plain text — no saveLayer.
                      if (progress >= 0.999) return child!;
                      return ShaderMask(
                        shaderCallback: (rect) {
                          const feather = 0.18;
                          final start = (progress * (1 + feather)) - feather;
                          final end = progress * (1 + feather);
                          return LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: const [
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: [
                              start.clamp(0.0, 1.0),
                              end.clamp(0.0, 1.0),
                            ],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: child,
                      );
                    },
                    child: text,
                  ),
          ),
        ),
      ),
    );
  }
}
