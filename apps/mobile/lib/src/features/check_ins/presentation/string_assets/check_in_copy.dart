/// Post-event check-in copy bank — verbatim from the Designer spec and policy SoT.
///
/// SPF 999 disclaimer ([safetyReportSubmittedSpf999Disclaimer]) is sourced
/// verbatim from [docs/policies/post-event-check-in.md] (§ "SPF 999 disclaimer",
/// commit D0 / 8e29997). Any change to that string requires a corresponding
/// update to the policy document first — the policy doc is the SoT.
///
/// Copy changes require Designer sign-off. Do NOT paraphrase; do NOT reorder.
library;

// ---------------------------------------------------------------------------
// Check-in prompt sheet
// ---------------------------------------------------------------------------

/// Title shown on the check-in prompt sheet.
/// Use the `{event_title}` token as a placeholder; substitute client-side.
const String checkInPromptTitle = 'Did you get home okay from {event_title}?';

/// Label for the affirmative "all is well" CTA.
const String checkInPromptAllGoodCta = 'All good';

/// Label for the "I need help" CTA.
const String checkInPromptNeedHelpCta = 'I need help';

/// Confirmation chip text shown after "All good" is tapped.
const String checkInAcknowledgedConfirmation = 'Glad you\'re safe.';

// ---------------------------------------------------------------------------
// Safety report page
// ---------------------------------------------------------------------------

/// AppBar title for the full-screen safety report page.
const String safetyReportPageTitle = 'Tell us what happened';

/// Placeholder (hint) text inside the safety report text area.
const String safetyReportPlaceholder = 'Tell us what happened…';

/// Label for the submit CTA on the safety report page.
const String safetyReportSendCta = 'Send report';

// ---------------------------------------------------------------------------
// Safety report submitted page (terminal state)
// ---------------------------------------------------------------------------

/// AppBar title for the terminal-state confirmation page.
const String safetyReportSubmittedTitle = 'Report received';

/// Body copy on the confirmation page.
const String safetyReportSubmittedBody =
    'Our team will reach out within 24 hours at the email address on your account.';

/// SPF 999 disclaimer — VERBATIM from docs/policies/post-event-check-in.md §
/// "SPF 999 disclaimer". The policy document is the SoT; changes here must
/// match the policy doc.
const String safetyReportSubmittedSpf999Disclaimer =
    'If you\'re in immediate danger, call the Singapore Police at 999. '
    'We are not an emergency service.';

/// Label for the "Done" CTA on the confirmation page.
const String safetyReportSubmittedDoneCta = 'Done';

// ---------------------------------------------------------------------------
// One-time intro sheet
// ---------------------------------------------------------------------------

/// Title of the one-time intro sheet.
const String introSheetTitle = 'A quick check-in after events';

/// Body copy of the one-time intro sheet.
const String introSheetBody =
    'We\'ll ask after events how things went — voluntary, takes 5 seconds, '
    'helps keep Tribely safe.';

/// CTA label for the one-time intro sheet.
const String introSheetCta = 'Got it';
