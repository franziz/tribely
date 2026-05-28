import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../string_assets/support_copy.dart';

/// Terminal screen shown after a support ticket is submitted successfully.
///
/// AC:
///   - Full-screen layout, centered icon ([Icons.check_circle_outline]).
///   - Heading: [supportSuccessHeading] ("Message sent").
///   - Body: [supportSuccessBody] (verbatim SLA copy).
///   - Sticky bottom [PrimaryButton] "Done" → `context.go('/settings')`.
///   - Reads `?id=<ticketId>` from [GoRouterState] but does NOT display it.
///
/// Reached via `context.pushReplacement('/support/contact/success?id=<id>')`
/// from [SupportContactPage] after a successful submission.
class SupportContactSuccessPage extends StatelessWidget {
  const SupportContactSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: accent),

                      const SizedBox(height: 24),

                      Text(
                        supportSuccessHeading,
                        style: TribelyType.headline(ink),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        supportSuccessBody,
                        style: TribelyType.bodyM(inkSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky bottom CTA.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: PrimaryButton(
                label: supportSuccessCta,
                onPressed: () => context.go('/settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
