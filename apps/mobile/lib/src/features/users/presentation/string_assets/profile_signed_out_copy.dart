// ignore_for_file: prefer_single_quotes
// zero imports — compile-time constants only

/// Copy SoT for the Profile signed-out empty state.
///
/// All strings are verbatim from the brief spec.
/// Do NOT inline copy in the widget; reference these constants instead.
abstract final class ProfileSignedOutCopy {
  static const String headline = 'Sign in to set up your profile';

  static const String body =
      "Add your photo and bio so hosts know who's joining.";

  static const String cta = 'Sign in';
}
