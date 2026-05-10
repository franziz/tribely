import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/grain_overlay.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../../auth/presentation/widgets/email_not_verified_banner.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _greetingVisible = true;
  Timer? _greetingTimer;

  @override
  void initState() {
    super.initState();
    _greetingTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _greetingVisible = false);
    });
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
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

    final session = ref.watch(sessionControllerProvider);
    final user = session is SessionAuthenticated ? session.session.user : null;
    final firstName = user?.displayName.split(' ').first ?? '';

    return Scaffold(
      body: Stack(
        children: [
          GrainOverlay(opacity: dark ? 0.04 : 0.03),
          SafeArea(
            child: Column(
              children: [
                const EmailNotVerifiedBanner(),
                // Greeting overlay — auto-dismisses after 3s.
                AnimatedSwitcher(
                  duration: TribelyMotion.medium,
                  child: _greetingVisible && user != null
                      ? Padding(
                          key: const ValueKey('greeting'),
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Welcome, $firstName.',
                              style: TribelyType.displayM(ink),
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('greeting-empty')),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('You\'re in.', style: TribelyType.displayL(ink)),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'The rest of Tribely will live here.',
                            style: TribelyType.bodyL(inkSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextButton(
                    onPressed: () async {
                      await ref
                          .read(sessionControllerProvider.notifier)
                          .signOut();
                      if (context.mounted) context.go('/welcome');
                    },
                    child: Text(
                      'Sign out',
                      style: TribelyType.bodyM(inkSecondary),
                    ),
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
