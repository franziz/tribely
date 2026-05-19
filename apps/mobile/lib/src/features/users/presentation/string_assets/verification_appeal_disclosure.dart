/// Pre-mailto disclosure copy — verbatim from the canonical SoT:
/// docs/policies/verification-appeal-disclosure.in-app-excerpt.md
///
/// PDPA s14 consent sheet shown immediately BEFORE the device mail client
/// opens on the "Contact support" tap from the verification-lockout screen.
///
/// DO NOT edit this copy without updating the SoT file and obtaining a fresh
/// legal/PM sign-off.
library;

const String kDisclosureSheetTitle = 'Before we open your email app';

const String kDisclosureSheetBody =
    "We'll open your email app with a message to support@gotribely.com already "
    'filled in. The message will include:\n\n'
    '- Your Tribely user ID\n'
    '- The number of selfie attempts on your account\n'
    '- The reason your most recent selfie did not pass review\n'
    '- Your app version and device type\n\n'
    'We include this so our support team can find your account quickly and '
    'respond within 3 business days.\n\n'
    'You can edit or delete any part of the message in your email app before '
    'sending. The message is sent through your own email provider (for example, '
    'Gmail or Apple Mail), not through Tribely — your email provider\'s privacy '
    'terms apply to that step.';

const String kDisclosurePrimaryAction = 'Open email app';
const String kDisclosureSecondaryAction = 'Cancel';
