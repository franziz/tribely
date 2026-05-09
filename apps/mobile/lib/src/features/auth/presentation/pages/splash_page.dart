import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/grain_overlay.dart';
import '../../../../core/widgets/ink_mark.dart';
import '../../../../core/widgets/wordmark.dart';

/// Cold-start screen.
///
/// Note: this widget does NOT trigger the silent refresh — `SessionController`
/// self-initializes via its `build()` method (Riverpod 3 convention). This
/// page is purely visual, listening to the session state via the router's
/// redirect logic.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  /// Show "Restoring your session…" caption only if the boot exceeds this.
  /// Tuned to overlap with `SessionController._minSplashHold` so it surfaces
  /// only on genuinely slow boots, not on the deliberate 1s brand hold.
  static const _slowThreshold = Duration(milliseconds: 1500);

  bool _showSlowCopy = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(_slowThreshold, () {
      if (mounted) setState(() => _showSlowCopy = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
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

    return Scaffold(
      body: Stack(
        children: [
          GrainOverlay(opacity: dark ? 0.04 : 0.03),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkMark(size: 96, color: ink),
                const SizedBox(height: 24),
                Wordmark(color: ink, size: 22),
                const SizedBox(height: 56),
                AnimatedOpacity(
                  duration: TribelyMotion.medium,
                  opacity: _showSlowCopy ? 1.0 : 0.0,
                  child: Text(
                    'Restoring your session…',
                    style: TribelyType.caption(inkSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
