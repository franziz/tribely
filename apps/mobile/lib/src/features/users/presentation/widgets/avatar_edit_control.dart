import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../string_assets/avatar_copy.dart';

/// Tappable avatar affordance for the Edit Profile page.
///
/// Design spec:
///   - 80dp circle. Has-avatar state: [NetworkImage]. No-avatar state:
///     initial-letter fallback (matches [profile_body.dart] `_buildAvatar`).
///   - Camera-badge overlay: 24dp circle, bottom-right, camera icon.
///   - Upload-in-progress: semi-transparent dark scrim + [CircularProgressIndicator]
///     layered OVER the existing avatar — the avatar image never disappears.
///   - [onTap] is nulled (pointer events blocked) while [isUploading] is true.
///
/// No Riverpod — purely presentational.
class AvatarEditControl extends StatelessWidget {
  const AvatarEditControl({
    required this.avatarUrl,
    required this.isUploading,
    required this.onTap,
    required this.displayName,
    super.key,
  });

  /// Current avatar URL (nullable — triggers initial-letter fallback when null
  /// or empty).
  final String? avatarUrl;

  /// True while the upload use case is in progress. Disables [onTap] and shows
  /// the scrim+spinner overlay.
  final bool isUploading;

  /// Called when the user taps the control (nulled while [isUploading]).
  final VoidCallback? onTap;

  /// Display name used for the initial-letter fallback when no avatar is set.
  final String displayName;

  static const double _size = 80;
  static const double _badgeSize = 24;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: kAvatarEditSemanticLabel,
      button: true,
      child: GestureDetector(
        onTap: isUploading ? null : onTap,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Base avatar circle.
              _buildAvatar(dark),
              // Upload scrim + spinner (layered over avatar, never replaces).
              if (isUploading) _buildUploadOverlay(),
              // Camera badge (bottom-right) — hidden during upload.
              if (!isUploading) _buildCameraBadge(dark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool dark) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    if (hasAvatar) {
      return CircleAvatar(
        radius: _size / 2,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }

    // Initial-letter fallback — mirrors profile_body.dart `_buildAvatar`.
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperBorderSubtle;
    return CircleAvatar(
      radius: _size / 2,
      backgroundColor: surface,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 32,
          color: dark
              ? TribelyColors.nightInkSecondary
              : TribelyColors.paperInkSecondary,
        ),
      ),
    );
  }

  /// Semi-transparent dark scrim with a centred spinner, overlaid on the avatar.
  Widget _buildUploadOverlay() {
    return ClipOval(
      child: Container(
        width: _size,
        height: _size,
        color: Colors.black54,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 24dp camera-badge circle positioned at the bottom-right of the avatar.
  Widget _buildCameraBadge(bool dark) {
    final badgeBg = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: _badgeSize,
        height: _badgeSize,
        decoration: BoxDecoration(
          color: badgeBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: dark
                ? TribelyColors.nightSurface
                : TribelyColors.paperSurface,
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
      ),
    );
  }
}
