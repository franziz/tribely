import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/users_providers.dart';
import '../state/user_profile_state.dart';
import '../widgets/profile_body.dart';

class OwnProfilePage extends ConsumerWidget {
  const OwnProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    final state = ref.watch(myProfileControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: TribelyType.headline(ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign out of Tribely?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref
                    .read(sessionControllerProvider.notifier)
                    .signOut();
              }
            },
          ),
        ],
      ),
      body: switch (state) {
        UserProfileLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        UserProfileLoaded(:final profile) => ProfileBody(
          profile: profile,
          isOwn: true,
        ),
        UserProfileError(:final message) => _ErrorView(
          message: message,
          onRetry: () => ref.read(myProfileControllerProvider.notifier).retry(),
          inkSecondary: inkSecondary,
        ),
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.inkSecondary,
  });

  final String message;
  final VoidCallback onRetry;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              style: TribelyType.bodyM(inkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
