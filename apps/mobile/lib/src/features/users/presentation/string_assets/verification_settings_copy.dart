/// Verification settings page copy bank — verbatim from the Designer spec.
///
/// Do NOT paraphrase; do NOT reorder. Copy changes require Designer sign-off.
library;

// ---------------------------------------------------------------------------
// Page title
// ---------------------------------------------------------------------------

const String kVerificationSettingsTitle = 'Verification';

// ---------------------------------------------------------------------------
// Banner copy
// ---------------------------------------------------------------------------

/// Banner copy when the user is NOT fully verified (not_started, pending,
/// failed states). CEO LOCKED — do not change without CEO sign-off.
const String kVerificationBannerPartial = 'Required to request to join events.';

/// Banner copy when the user is fully verified (all three signals approved).
const String kVerificationBannerFullyVerified =
    "You're verified — go meet someone.";

// ---------------------------------------------------------------------------
// Row signal labels
// ---------------------------------------------------------------------------

const String kVerificationLabelEmail = 'Email';
const String kVerificationLabelPhone = 'Phone';
const String kVerificationLabelSelfie = 'Selfie';

// ---------------------------------------------------------------------------
// State labels
// ---------------------------------------------------------------------------

const String kVerificationStateVerified = 'Verified';
const String kVerificationStatePending = 'Pending';
const String kVerificationStateFailed = 'Failed';
const String kVerificationStateNotStarted = 'Not started';

/// Selfie-specific pending label override — avoids an implicit SLA promise.
const String kVerificationStateSelfiePending = 'Photo under review';

// ---------------------------------------------------------------------------
// CTA labels
// ---------------------------------------------------------------------------

const String kVerificationCtaVerifyNow = 'Verify now';
const String kVerificationCtaResend = 'Resend';
const String kVerificationCtaCheckStatus = 'Check status';
const String kVerificationCtaRetry = 'Retry';

// ---------------------------------------------------------------------------
// Offline caption
// ---------------------------------------------------------------------------

const String kVerificationOfflineCaption =
    'Offline — showing last known status';
