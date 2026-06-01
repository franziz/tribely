import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely_mobile/src/core/design/colors.dart';
import 'package:tribely_mobile/src/core/design/typography.dart';
import 'package:tribely_mobile/src/core/widgets/grain_overlay.dart';

/// Shared layout container for auth-style page surfaces (phone gate, OTP, sign-in).
/// Lives in core/widgets/ because it has no auth-domain knowledge.
///
/// The form body itself is provided by the caller via [child] — this widget
/// is intentionally a dumb container with no knowledge of validation, state,
/// or controllers. That keeps the auth pages composable without coupling
/// the scaffold to any one page's controllers.
class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.backFallback = '/welcome',
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Where to navigate if the back button is tapped and the navigator can't pop.
  final String backFallback;

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
      body: SafeArea(
        child: Stack(
          children: [
            GrainOverlay(opacity: dark ? 0.04 : 0.03),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Two things going on here:
                  // 1) `Align` opts this single child out of the parent
                  //    Column's `crossAxisAlignment: stretch` so the button
                  //    keeps a fixed 48x48 size (instead of the tap ripple
                  //    spanning the full row width).
                  // 2) `padding: EdgeInsets.zero` + `alignment: centerLeft`
                  //    on IconButton anchors the arrow to the LEFT edge of
                  //    its 48x48 tap area, so the icon's visual position
                  //    aligns with the title text's left edge below — both
                  //    sit at the SingleChildScrollView's 24px left padding.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: ink),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go(backFallback);
                        }
                      },
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(title, style: TribelyType.displayL(ink)),
                  const SizedBox(height: 12),
                  Text(subtitle, style: TribelyType.bodyL(inkSecondary)),
                  const SizedBox(height: 32),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
