import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/motion.dart';
import '../design/typography.dart';

/// Primary CTA. 56dp tall, full-width, soft rounded corners.
///
/// States: idle (active or disabled), loading (••• pulse), success (✓ + label).
/// Width stays constant across states so the button doesn't jump.
enum PrimaryButtonState { idle, loading, success }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.state = PrimaryButtonState.idle,
    this.successLabel = "You're in.",
    super.key,
  });

  final String label;
  final VoidCallback? onPressed; // null = disabled
  final PrimaryButtonState state;
  final String successLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final onPrimary = dark
        ? TribelyColors.nightSurface
        : TribelyColors.paperSurfaceHigh;
    final disabledBg = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final disabledFg = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    final disabled = onPressed == null && state == PrimaryButtonState.idle;
    final bg = disabled ? disabledBg : primary;
    final fg = disabled ? disabledFg : onPrimary;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: state == PrimaryButtonState.idle ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          splashColor: fg.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Center(
            child: AnimatedSwitcher(
              duration: TribelyMotion.short,
              child: switch (state) {
                PrimaryButtonState.idle => Text(
                  label,
                  key: const ValueKey('idle'),
                  style: TribelyType.button(fg),
                ),
                PrimaryButtonState.loading => _LoadingDots(
                  key: const ValueKey('loading'),
                  color: fg,
                ),
                PrimaryButtonState.success => Row(
                  key: const ValueKey('success'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(successLabel, style: TribelyType.button(fg)),
                    const SizedBox(width: 8),
                    Icon(Icons.check, color: fg, size: 18),
                  ],
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Three-dot pulsing animation. Replaces the standard CircularProgressIndicator
/// so the button doesn't suddenly switch idiom mid-flow.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots({required this.color, super.key});
  final Color color;

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
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
      builder: (_, __) {
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
