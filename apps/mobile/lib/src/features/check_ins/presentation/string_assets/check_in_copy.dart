/// Post-event check-in copy bank — verbatim from the Designer spec and policy SoT.
///
/// SG business-hours boilerplate (used in [safetyReportSubmittedBody],
/// [safetyReportSubmittedSpf999Disclaimer], [safetyReportGateDisclaimerBody],
/// and [safetyCheckInReminderBody]) is SoT-aligned with
/// [docs/runbooks/safety-reports.md] and
/// [docs/policies/post-event-check-in.in-app-excerpt.md] (updated in TRI-238
/// Brief A2). Any change to that boilerplate requires a corresponding update to
/// both policy documents first — those documents are the SoT.
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
    'We aim to review safety reports during Singapore business hours (Monday to Friday, 9am to 9pm SGT, excluding public holidays). We\'ll reach out at the email address on your account.';

/// SPF 999 disclaimer — VERBATIM from docs/policies/post-event-check-in.md §
/// "SPF 999 disclaimer". The policy document is the SoT; changes here must
/// match the policy doc (updated in TRI-238 Brief A2).
const String safetyReportSubmittedSpf999Disclaimer =
    'If you or someone else is in immediate danger, or a crime is in progress, call the Police on 999 now.\n\n'
    'This form is for non-emergency safety reports. It is not monitored in real time and is not a substitute for emergency services. We aim to review reports during Singapore business hours (Monday to Friday, 9am to 9pm SGT, excluding public holidays).';

/// Label for the "Done" CTA on the confirmation page.
const String safetyReportSubmittedDoneCta = 'Done';

// ---------------------------------------------------------------------------
// Safety report — hard pre-submit 999 gate
// ---------------------------------------------------------------------------

/// Heading for the hard pre-submit 999 disclaimer block on SafetyReportPage.
/// Verbatim per TRI-238 legal-compliance ruling.
const String safetyReportGateHeading = 'Emergency? Call 999 first.';

/// Disclaimer body shown above the acknowledgement checkbox on SafetyReportPage.
/// "999" appears twice; both render bolded; the FIRST occurrence renders as a
/// `tel:999` launchable link. Renderer is responsible for the rich-text composition;
/// this constant is the raw paragraph text for accessibility / screen-reader output.
const String safetyReportGateDisclaimerBody =
    'If you or someone else is in immediate danger, or a crime is in progress, call the Police on 999 now.\n\n'
    'This form is for non-emergency safety reports. It is not monitored in real time and is not a substitute for emergency services. We aim to review reports during Singapore business hours (Monday to Friday, 9am to 9pm SGT, excluding public holidays).';

/// Checkbox label for the hard pre-submit acknowledgement gate.
const String safetyReportGateCheckboxLabel =
    'I understand this form is not for emergencies and I will call 999 if there is immediate danger.';

/// Helper text shown beneath the disabled submit CTA when the checkbox is unticked.
const String safetyReportGateDisabledHelperText =
    'Tick the box above to submit your report.';

/// Tap-target label for the inline tel:999 link inside the disclaimer body.
const String safetyReportGateTel999LinkLabel = '999';

// ---------------------------------------------------------------------------
// Safety check-in reminder (Surface B)
// ---------------------------------------------------------------------------

/// Surface B — post-event safety reminder body shown on the check-in prompt sheet.
/// "999" renders bolded + tel:999 link; "file a safety report" renders as the CTA
/// into Surface A (the safety report form).
const String safetyCheckInReminderBody =
    'If you or someone else is in immediate danger, call the Police on 999.\n\n'
    'For non-emergency concerns about an event or another member, you can file a safety report. We aim to review reports during Singapore business hours (Monday to Friday, 9am to 9pm SGT, excluding public holidays).';

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
