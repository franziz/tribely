/// Support feature copy bank — verbatim from the product spec.
///
/// Display-string ↔ [SupportCategory] mapping is the single source of truth
/// here; [CategorySelectorSheet] and any other rendering surface must derive
/// their display strings from [supportCategoryDisplayName].
///
/// Copy changes require Designer sign-off. Do NOT paraphrase; do NOT reorder.
library;

import '../../domain/entities/support_ticket_draft.dart';

// ---------------------------------------------------------------------------
// Page chrome
// ---------------------------------------------------------------------------

/// AppBar title for the support contact form page.
const String supportContactPageTitle = 'Help & Support';

/// Label for the subject tap-target row when no category is selected.
const String supportSubjectPlaceholder = 'Subject';

// ---------------------------------------------------------------------------
// Form field labels and captions
// ---------------------------------------------------------------------------

/// Label for the message text area.
const String supportMessageLabel = 'Message';

/// Helper caption shown below the message field.
const String supportMessageCaption = 'Required';

/// Label for the Report ID field.
const String supportReportIdLabel = 'Report ID';

/// Helper caption shown below the Report ID field.
const String supportReportIdCaption =
    'Optional — pre-filled if you arrived from a report follow-up link';

// ---------------------------------------------------------------------------
// Privacy microcopy
// ---------------------------------------------------------------------------

/// Privacy disclosure block beneath the form fields.
const String supportPrivacyMicrocopy =
    'We\'ll attach the email on your account so we can reply to you. '
    'No other account details are sent.';

// ---------------------------------------------------------------------------
// Submit CTA
// ---------------------------------------------------------------------------

/// Label for the submit button.
const String supportSubmitCta = 'Send message';

/// Caption shown beneath the disabled submit button when the form is incomplete.
const String supportSubmitDisabledHint =
    'Choose a subject and enter a message to send.';

// ---------------------------------------------------------------------------
// Error banners
// ---------------------------------------------------------------------------

/// Banner copy for [RateLimitedFailure].
const String supportRateLimitedBannerCopy =
    'You\'ve sent several support messages recently. Please try again later.';

/// Fallback banner copy for any other failure.
const String supportGenericErrorBannerCopy =
    'Something went wrong. Please try again.';

// ---------------------------------------------------------------------------
// Category selector sheet
// ---------------------------------------------------------------------------

/// Sheet title for the category selector.
const String supportCategorySheetTitle = 'Choose a subject';

/// Accessibility label on the sheet container.
const String supportCategorySheetSemanticLabel = 'Choose a subject';

// ---------------------------------------------------------------------------
// Success screen copy
// ---------------------------------------------------------------------------

/// AppBar / heading on the post-submit success screen.
const String supportSuccessHeading = 'Message sent';

/// Body copy on the post-submit success screen.
const String supportSuccessBody =
    'We\'ve received your message.\n\n'
    'We aim to reply within 3 business days to the email on your account.';

/// CTA label on the post-submit success screen.
const String supportSuccessCta = 'Done';

// ---------------------------------------------------------------------------
// Display-string ↔ [SupportCategory] mapping — single source of truth.
///
/// Returns the exact string shown in [CategorySelectorSheet] and in the
/// subject tap-target row once a category is selected. Canonical order matches
/// the product spec:
///   1. reportFollowup7d
///   2. accountSignin
///   3. eventOrHost
///   4. appBroken
///   5. feedback
///   6. other
String supportCategoryDisplayName(SupportCategory category) {
  switch (category) {
    case SupportCategory.reportFollowup7d:
      return 'Report follow-up (after 7 days)';
    case SupportCategory.accountSignin:
      return 'Account or sign-in issue';
    case SupportCategory.eventOrHost:
      return 'Event or host concern';
    case SupportCategory.appBroken:
      return 'App not working';
    case SupportCategory.feedback:
      return 'Feedback or suggestion';
    case SupportCategory.other:
      return 'Other';
  }
}
