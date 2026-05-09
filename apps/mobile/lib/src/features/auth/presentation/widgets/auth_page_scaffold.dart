import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/grain_overlay.dart';

/// Shared chrome for the auth pages (sign-in / sign-up). Wraps a back arrow,
/// a Fraunces-italic display headline, a body-L supportive subtitle, the
/// grain overlay, and a scroll-when-needed body.
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
    final ink =
        dark ? TribelyColors.nightInkPrimary : TribelyColors.paperInkPrimary;
    final inkSecondary =
        dark ? TribelyColors.nightInkSecondary : TribelyColors.paperInkSecondary;

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
                  IconButton(
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
