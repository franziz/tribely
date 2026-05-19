/// Verification failure copy bank — verbatim from the Designer spec.
///
/// String constants are keyed by [SelfieFailureCategory] enum values.
/// Do NOT paraphrase; do NOT reorder. Copy changes require Designer sign-off.
library;

import '../../domain/value_objects/selfie_failure_category.dart';

// ---------------------------------------------------------------------------
// Per-category title (all share the same title per spec)
// ---------------------------------------------------------------------------

/// Returns the title for the rejection screen regardless of category.
/// All categories share the same title per the Designer copy bank.
String verificationFailureTitle(SelfieFailureCategory? category) =>
    'Your photo didn\'t pass review';

// ---------------------------------------------------------------------------
// Per-category body copy
// ---------------------------------------------------------------------------

/// Returns the body copy for a [SelfieFailureCategory].
/// Falls back to [SelfieFailureCategory.other] for null/unknown categories.
String verificationFailureBody(
  SelfieFailureCategory? category,
) => switch (category ?? SelfieFailureCategory.other) {
  SelfieFailureCategory.poorLighting =>
    'The photo was a bit dark and hard to make out. Try again somewhere '
        'bright — facing a window works great.',
  SelfieFailureCategory.faceNotVisible =>
    "We couldn't clearly see your face. Make sure nothing is covering it — "
        'no sunglasses, hats, or hands in the way.',
  SelfieFailureCategory.qualityTooLow =>
    'The photo came out too blurry or pixelated. Try holding your phone '
        'still and making sure the lens is clean.',
  SelfieFailureCategory.other =>
    "Something about the photo wasn't quite right — it could be lighting, "
        'angle, or something in the background. Give it another go and we\'ll '
        'take another look.',
};

// ---------------------------------------------------------------------------
// Locked-state (attempt 3) body override
// ---------------------------------------------------------------------------

const String kVerificationLockedBody =
    'Take a break and try again in 24 hours — or reach out and we\'ll sort it '
    'together.';

// ---------------------------------------------------------------------------
// SLA line shown below the "Contact support" CTA at lockout
// ---------------------------------------------------------------------------

const String kSlaLine = 'We\'ll respond within 3 business days.';

// ---------------------------------------------------------------------------
// Pending status card row copy
// ---------------------------------------------------------------------------

const String kPendingRowLabel = 'Under review';
const String kPendingRowSupporting =
    'Usually a day or two — we\'ll let you know.';

// ---------------------------------------------------------------------------
// Disabled-CTA hints — failed/locked state (bi-color: accentSpan in paperAccent)
// ---------------------------------------------------------------------------

/// Full text for the Request-to-Join disabled hint (failed/locked state).
const String kDisabledHintJoinEvents =
    'Verify your selfie to join events. Tap to see what happened.';

/// The accent-coloured span within [kDisabledHintJoinEvents].
const String kDisabledHintJoinEventsAccentSpan = 'Tap to see what happened.';

/// Full text for the Create-Event disabled hint (failed/locked state).
const String kDisabledHintCreateEvent =
    'Verify your selfie to create events. Tap to see what happened.';

/// The accent-coloured span within [kDisabledHintCreateEvent].
const String kDisabledHintCreateEventAccentSpan = 'Tap to see what happened.';

// ---------------------------------------------------------------------------
// Disabled-CTA hints — pending state (single-colour inkSecondary)
// ---------------------------------------------------------------------------

/// Pending hint text used for both Request-to-Join and Create-Event consumers.
const String kDisabledHintPending =
    'Your photo is under review — check back soon.';
