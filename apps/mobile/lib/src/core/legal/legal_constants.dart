// Legal copy constants. Single source of truth for entity name + PDPA strings.
// Re-used across Privacy Policy, ToS, receipts, email footers, account-deletion
// confirmations, and the phone-OTP flow.

// ignore_for_file: lines_longer_than_80_chars

/// The registered legal entity name.
///
/// TODO(TRI-???): replace with ACRA-registered SG entity name once CEO provides it.
const String kLegalEntityName = 'Tribely (legal entity TBD)';

/// PDPA consent body copy used on the phone-OTP entry screen.
///
/// LEGAL-COMPLIANCE LOCKED — do not paraphrase, reformat line breaks, or alter
/// punctuation. Use [resolveLegalCopy] to substitute {{COMPANY_NAME}}.
const String kPdpaConsentBodyTemplate =
    '''Why we ask: We use your phone number to verify your identity and help hosts
and guests trust each other on Tribely. We won't share it with other users
or use it for marketing.

How it's sent: Your code is delivered by SMS via our verification partner,
Twilio. At launch the message arrives from sender ID "TWVerify" — that's
us. Standard carrier message and data rates may apply.

By tapping Send code, you confirm you've read our Privacy Policy and
consent to {{COMPANY_NAME}} collecting and using your phone number for
verification.''';

/// Bridging copy displayed on the phone-OTP screen while the Tribely-branded
/// Twilio sender ID is pending approval.
///
/// LEGAL-COMPLIANCE LOCKED — do not paraphrase, reformat line breaks, or alter
/// punctuation.
const String kSenderIdBridgeCopy =
    'Code arrives from sender ID "TWVerify" — that\'s us. We\'ll switch to a Tribely-branded sender soon.';

/// Banner copy shown when the user's phone number is already verified on a
/// different account.
///
/// LEGAL-COMPLIANCE LOCKED — do not paraphrase, reformat line breaks, or alter
/// punctuation.
const String kContestedPhoneBannerCopy =
    'This phone is now verified on another account. Verify a phone number to create or join events.';

/// Feature flag: whether to render [kSenderIdBridgeCopy] in the phone-OTP UI.
/// Set to false once the Tribely-branded Twilio sender ID is live.
const bool kPhoneVerificationBridgeCopyEnabled = true;

/// Substitutes {{COMPANY_NAME}} in a legal copy template with [kLegalEntityName].
String resolveLegalCopy(String template) =>
    template.replaceAll('{{COMPANY_NAME}}', kLegalEntityName);
