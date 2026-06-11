/// Selfie capture + consent copy bank — verbatim from the Designer spec
/// and legal-blessed v1.1 consent body.
///
/// String constants are pure compile-time values. NO imports.
/// Do NOT paraphrase; do NOT reorder. Legal-locked lines are annotated.
/// Copy changes to legal-locked lines require legal + Designer sign-off.
library;

// ignore_for_file: lines_longer_than_80_chars

// ---------------------------------------------------------------------------
// Consent screen — legal-locked body (v1.1)
// ---------------------------------------------------------------------------

/// First paragraph of the consent body.
///
/// LEGAL-COMPLIANCE LOCKED — do not paraphrase, reformat line breaks, or alter
/// punctuation without legal + Designer sign-off.
const String kConsentBodyParagraph1 =
    'We need a quick selfie to confirm you\'re a real person — it helps keep '
    'Tribely safe for everyone.';

/// Second paragraph of the consent body.
///
/// LEGAL-COMPLIANCE LOCKED — do not paraphrase, reformat line breaks, or alter
/// punctuation without legal + Designer sign-off.
const String kConsentBodyParagraph2 =
    'Your photo is reviewed once by our team and is never used for advertising, '
    'never shared with other users, and never used to train any model. '
    'It is stored only in Singapore.';

/// Third paragraph of the consent body.
///
/// LEGAL-COMPLIANCE LOCKED — do not paraphrase, reformat line breaks, or alter
/// punctuation without legal + Designer sign-off.
const String kConsentBodyParagraph3 =
    'Your selfie is deleted within 30 days of review, whether or not it\'s '
    'approved. Deleting your account deletes your selfie immediately.';

/// Affirmative-act consent sentence.
///
/// PLACEHOLDER — PENDING legal re-bless. Do NOT finalize this line until
/// team-lead confirms the approved wording.
///
/// TODO(TRI-23): replace with the final legal-blessed affirmative-act sentence
/// once team-lead relays the re-blessed wording.
// ignore: constant_identifier_names
const String kConsentAffirmativeActSentence =
    '[PENDING LEGAL RE-BLESS] By tapping Take my photo, you agree to Tribely '
    'collecting and reviewing this photo for identity verification.';

/// Privacy policy link label shown in the consent body.
const String kConsentPolicyLinkLabel = 'Read the full policy';

/// Privacy policy URL for the selfie consent screen.
///
/// Resolved from [kPrivacyPolicyUrl] in core/legal/legal_constants.dart.
/// TODO(TRI-152): confirm this URL is live before App Store submission.
/// See also TRI-78 (privacy-policy page launch gate).
// NOTE: We use the established kPrivacyPolicyUrl constant from legal_constants
// rather than the %POLICY_URL% token — that token has no resolver in the
// current codebase. A TODO(TRI-152) is recorded here for the live-URL gate.
// The literal '%POLICY_URL%' token is NOT shipped to the user.
const String kConsentPolicyUrl = 'https://gotribely.com/privacy';

/// Micro-detail copy shown beneath the consent body.
/// Do NOT paraphrase without Designer sign-off.
const String kConsentMicroDetail =
    'Your photo is never shared on your public profile.';

// ---------------------------------------------------------------------------
// Consent screen — standard-intake CTAs
// ---------------------------------------------------------------------------

/// Headline for the consent screen.
const String kConsentHeadline = 'One photo so people know you\'re real';

/// Primary CTA label on the consent screen.
const String kConsentPrimaryCtaLabel = 'Take my photo';

/// Secondary (dismiss) CTA label on the consent screen.
const String kConsentSecondaryCtaLabel = 'Not now';

// ---------------------------------------------------------------------------
// Consent screen — intake-disabled variant
// ---------------------------------------------------------------------------

/// Headline when SELFIE_INTAKE_DISABLED is active.
const String kIntakeDisabledHeadline = 'Verification temporarily unavailable';

/// Body copy when SELFIE_INTAKE_DISABLED is active.
const String kIntakeDisabledBody =
    'We\'re not accepting new photos right now. Check back soon — we\'ll have '
    'this sorted quickly.';

/// CTA label when SELFIE_INTAKE_DISABLED is active.
const String kIntakeDisabledCtaLabel = 'Got it';

// ---------------------------------------------------------------------------
// Capture screen — live guidance state→string table
//
// These strings drive the AnimatedSwitcher guidance text on Screen 2.
// Sourced from the designer spec guidance state machine.
// ---------------------------------------------------------------------------

/// Guidance: user must center their face in the oval.
const String kGuidanceCenterFace = 'Center your face';

/// Guidance: more than one face detected.
const String kGuidanceOnePerson = 'One person only';

/// Guidance: insufficient lighting detected.
const String kGuidanceBetterLight = 'Move to better light';

/// Guidance: face detected and centered — instruct user to hold still.
const String kGuidanceHoldSteady = 'Hold steady…';

/// Guidance: face is too far from the camera.
const String kGuidanceCloser = 'Move a little closer';

/// Guidance: face is too close / head tilted too far back.
const String kGuidanceBack = 'Move back a little';

/// Guidance: all checks passed — capture is enabled.
const String kGuidancePass = 'Looking good!';

// ---------------------------------------------------------------------------
// Capture screen — state copy
// ---------------------------------------------------------------------------

/// Capture button semantic label (a11y).
const String kCaptureButtonSemanticLabel = 'Take photo';

/// Banner copy when the device is offline at submit time.
const String kCaptureOfflineBanner =
    'No connection — check your network and try again.';

/// Banner action label for retrying after an offline/server error.
const String kCaptureRetryAction = 'Try again';

/// Banner copy when the server returns an error at submit time.
const String kCaptureServerErrorBanner =
    'Something went wrong — your photo wasn\'t lost. Tap to try again.';

// ---------------------------------------------------------------------------
// Camera permission-denied state
// ---------------------------------------------------------------------------

/// Headline shown on the capture page when camera access is denied.
const String kPermissionDeniedHeadline = 'Camera access needed';

/// Body copy when camera access is denied.
const String kPermissionDeniedBody =
    'Tribely needs camera access to take your verification photo. '
    'Open Settings and allow camera access to continue.';

/// CTA label to open device settings from the permission-denied state.
const String kPermissionDeniedCtaLabel = 'Open Settings';

// ---------------------------------------------------------------------------
// Defensive guard copy (already-approved / already-pending states
// reached via direct navigation — these should not surface in normal flow)
// ---------------------------------------------------------------------------

/// Body copy when the user navigates to the selfie flow but is already approved.
const String kAlreadyApprovedBody =
    'You\'re already verified — nothing to do here.';

/// Body copy when the user navigates to the selfie flow but is already pending review.
const String kAlreadyPendingBody =
    'Your photo is already under review. We\'ll let you know when it\'s done.';
