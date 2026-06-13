// ignore_for_file: prefer_single_quotes
// zero imports — compile-time constants only

/// Copy SoT for [SignInGateSheet].
///
/// All strings are verbatim from the designer's revised spec.
/// Do NOT inline copy in the widget; reference these constants instead.
abstract final class SignInGateCopy {
  // Headlines ---------------------------------------------------------------

  /// First line of the JOIN headline (intent = requestJoin).
  static const String joinHeadlineLine1 = 'Sign in to request to join';

  // joinHeadlineLine2 is dynamically built from the eventTitle at the
  // call site: '"$eventTitle"' — maxLines 2, TextOverflow.ellipsis.

  /// Headline for CREATE intent (single line).
  static const String createHeadline = 'Sign in to create an event';

  // Review headline — reserved for future use, NOT wired.
  // static const String reviewHeadline = 'Sign in to post a review';

  // Fields ------------------------------------------------------------------

  static const String emailLabel = 'Email';
  static const String passwordLabel = 'Password';

  // Actions -----------------------------------------------------------------

  static const String primaryCta = 'Sign in';
  static const String forgotPasswordLink = 'Forgot password?';

  // "New here?" RichText — see widget for split rendering:
  //   "New here?" in inkSecondary, "Create account" in accent w600.
  static const String createAccountPrefix = 'New here?  ';
  static const String createAccountAction = 'Create account';

  // Error banners -----------------------------------------------------------

  /// Generic wrong-credentials error — does NOT reveal whether the email
  /// is registered (security requirement per spec).
  static const String authErrorBanner =
      'Incorrect email or password. Please try again.';

  /// Network-level or unknown-server error.
  static const String networkErrorBanner =
      'Something went wrong. Please try again.';
}
