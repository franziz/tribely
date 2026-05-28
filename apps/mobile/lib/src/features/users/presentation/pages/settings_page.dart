import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Settings page — route: /settings.
///
/// Sections:
///   ACCOUNT: Edit profile, Notifications (Coming soon stub).
///   PRIVACY & SAFETY: Blocked users.
///   Sign out (destructive-tertiary, confirms with AlertDialog).
///   Footer: app version (italic caption, centred).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TribelyType.headline(ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        children: [
          // ── ACCOUNT ──────────────────────────────────────────────────────
          _SectionHeader(label: 'ACCOUNT', inkSecondary: inkSecondary),
          _SettingsTile(
            title: 'Edit profile',
            ink: ink,
            onTap: () => context.push('/profile/edit'),
          ),
          _SettingsTile(
            title: 'Notifications',
            subtitle: 'Coming soon',
            ink: ink,
            inkSecondary: inkSecondary,
            enabled: false,
          ),

          // ── PRIVACY & SAFETY ─────────────────────────────────────────────
          _SectionHeader(label: 'PRIVACY & SAFETY', inkSecondary: inkSecondary),
          _SettingsTile(
            title: 'Blocked users',
            ink: ink,
            onTap: () => context.push('/settings/blocked-users'),
          ),

          // ── SUPPORT ──────────────────────────────────────────────────────
          _SectionHeader(label: 'SUPPORT', inkSecondary: inkSecondary),
          _SettingsTile(
            title: 'Help & Support',
            ink: ink,
            onTap: () => context.push('/support/contact'),
          ),

          const SizedBox(height: 32),

          // ── Sign out ─────────────────────────────────────────────────────
          Center(
            child: TextButton(
              onPressed: () => _confirmSignOut(context, ref),
              child: Text('Sign out', style: TribelyType.bodyM(accent)),
            ),
          ),

          const SizedBox(height: 24),

          // ── Footer ───────────────────────────────────────────────────────
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '—';
              final build = snapshot.data?.buildNumber ?? '';
              final label = build.isNotEmpty
                  ? 'v$version ($build)'
                  : 'v$version';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Text(
                    label,
                    style: TribelyType.italicCaption(inkSecondary),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of Tribely?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionControllerProvider.notifier).signOut();
    }
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.inkSecondary});
  final String label;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      child: Text(label, style: TribelyType.caption(inkSecondary)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.ink,
    this.subtitle,
    this.inkSecondary,
    this.enabled = true,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Color ink;
  final Color? inkSecondary;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        title,
        style: TribelyType.bodyM(enabled ? ink : (inkSecondary ?? ink)),
      ),
      subtitle: subtitle != null && inkSecondary != null
          ? Text(subtitle!, style: TribelyType.caption(inkSecondary!))
          : null,
      trailing: enabled
          ? Icon(Icons.chevron_right, color: ink, size: 20)
          : null,
      onTap: enabled ? onTap : null,
    );
  }
}
