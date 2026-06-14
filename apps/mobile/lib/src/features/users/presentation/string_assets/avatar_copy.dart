/// Avatar upload copy bank — verbatim from the Designer spec.
///
/// String constants are pure compile-time values. NO imports.
library;

// ---------------------------------------------------------------------------
// Permission-denied banner messages
// ---------------------------------------------------------------------------

/// Shown when camera permission is denied (permanently) — includes Open
/// Settings prompt.
const String kAvatarCameraPermissionDeniedMessage =
    'Camera access is needed to take a photo. Open Settings to allow it.';

/// Shown when photo-library permission is denied (permanently) — includes
/// Open Settings prompt.
const String kAvatarLibraryPermissionDeniedMessage =
    'Photo library access is needed. Open Settings to allow it.';

// ---------------------------------------------------------------------------
// Upload error banner message
// ---------------------------------------------------------------------------

/// Shown in the edit-profile error banner when the avatar upload fails.
const String kAvatarUploadErrorMessage =
    "Couldn't update your photo. Try again.";

// ---------------------------------------------------------------------------
// Accessibility labels
// ---------------------------------------------------------------------------

/// Semantic label for the tappable avatar control.
const String kAvatarEditSemanticLabel = 'Change profile photo';

/// Label for the "Open Settings" text link in the permission-denied banner.
const String kOpenSettingsLabel = 'Open Settings';
