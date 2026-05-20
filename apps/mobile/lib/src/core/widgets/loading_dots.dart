import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/typography.dart';

/// Three-dot pulsing animation. Replaces the standard CircularProgressIndicator
/// so buttons don't suddenly switch idiom mid-flow.
///
/// Respects [MediaQuery.disableAnimations]: degrades to a static "•••" when
/// the user has enabled reduced motion.
class LoadingDots extends StatefulWidget {
  const LoadingDots({required this.color, super.key});
  final Color color;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) {
      // Static "•••" — no animation.
      return Text('•••', style: TribelyType.button(widget.color));
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i / 3) % 1.0;
            final scale = 0.7 + 0.3 * (0.5 - (phase - 0.5).abs()) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
