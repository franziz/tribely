import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/user_profile.dart';
import 'profile_empty_field.dart';
import 'profile_picklists.dart';

/// Shared presentational widget for all three profile routes.
/// [isOwn] controls whether the "Edit" affordance is shown.
///
/// Slot for TRI-32 verification badge: see [_buildDisplayName].
class ProfileBody extends StatelessWidget {
  const ProfileBody({required this.profile, required this.isOwn, super.key});

  final UserProfile profile;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, ink, inkSecondary, dark),
          const SizedBox(height: 24),
          _buildSection(
            context,
            label: 'Bio',
            ink: ink,
            inkSecondary: inkSecondary,
            child: profile.bio != null && profile.bio!.isNotEmpty
                ? Text(profile.bio!, style: TribelyType.bodyM(ink))
                : const ProfileEmptyField(type: ProfileEmptyFieldType.bio),
          ),
          const SizedBox(height: 20),
          _buildSection(
            context,
            label: 'City',
            ink: ink,
            inkSecondary: inkSecondary,
            child:
                profile.currentCity != null && profile.currentCity!.isNotEmpty
                ? Text(profile.currentCity!, style: TribelyType.bodyM(ink))
                : const ProfileEmptyField(type: ProfileEmptyFieldType.city),
          ),
          const SizedBox(height: 20),
          _buildSection(
            context,
            label: 'Languages',
            ink: ink,
            inkSecondary: inkSecondary,
            child: profile.languages.isNotEmpty
                ? _buildChips(profile.languages, kLanguageLabels, dark)
                : const ProfileEmptyField(
                    type: ProfileEmptyFieldType.languages,
                  ),
          ),
          const SizedBox(height: 20),
          _buildSection(
            context,
            label: 'Interests',
            ink: ink,
            inkSecondary: inkSecondary,
            child: profile.interests.isNotEmpty
                ? _buildChips(profile.interests, kInterestLabels, dark)
                : const ProfileEmptyField(
                    type: ProfileEmptyFieldType.interests,
                  ),
          ),
          if (profile.travelerType != null) ...[
            const SizedBox(height: 20),
            _buildSection(
              context,
              label: 'Currently',
              ink: ink,
              inkSecondary: inkSecondary,
              child: Text(
                kTravelerTypeLabels[profile.travelerType] ??
                    profile.travelerType!,
                style: TribelyType.bodyM(ink),
              ),
            ),
          ],
          // TRI-32: verification badge slot — add here when implemented.
          if (isOwn) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/profile/edit'),
                child: const Text('Edit profile'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color ink,
    Color inkSecondary,
    bool dark,
  ) {
    return Row(
      children: [
        _buildAvatar(dark),
        const SizedBox(width: 16),
        Expanded(child: _buildDisplayName(ink, inkSecondary)),
      ],
    );
  }

  Widget _buildAvatar(bool dark) {
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperBorderSubtle;
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: NetworkImage(profile.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 36,
      backgroundColor: surface,
      child: Text(
        profile.displayName.isNotEmpty
            ? profile.displayName[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontFamily: TribelyType.displayFamily,
          fontStyle: FontStyle.italic,
          fontSize: 28,
          color: dark
              ? TribelyColors.nightInkSecondary
              : TribelyColors.paperInkSecondary,
        ),
      ),
    );
  }

  Widget _buildDisplayName(Color ink, Color inkSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TRI-32: insert verification badge next to displayName here.
        Text(profile.displayName, style: TribelyType.headline(ink)),
        if (profile.email.isNotEmpty)
          Text(profile.email, style: TribelyType.caption(inkSecondary)),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String label,
    required Color ink,
    required Color inkSecondary,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TribelyType.caption(inkSecondary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildChips(
    List<String> codes,
    Map<String, String> labels,
    bool dark,
  ) {
    final chipBg = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperBorderSubtle;
    final chipInk = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: codes
          .map(
            (code) => Chip(
              label: Text(
                labels[code] ?? code,
                style: TribelyType.caption(chipInk),
              ),
              backgroundColor: chipBg,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
          .toList(),
    );
  }
}
