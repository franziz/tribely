import 'package:flutter/material.dart';

/// Equatorial Editorial — type tokens.
///
/// Display: Fraunces Italic (variable serif, SOFT axis). Body: General Sans.
/// Both fonts must be present in `apps/mobile/assets/fonts/` — see the
/// README in that directory.
///
/// Numbers in the comments are spec values from
/// `apps/mobile/design/login/spec.md`.
class TribelyType {
  const TribelyType._();

  static const String displayFamily = 'Fraunces';
  static const String bodyFamily = 'GeneralSans';

  static TextStyle displayL(Color color) => TextStyle(
        fontFamily: displayFamily,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        fontSize: 36,
        height: 42 / 36,
        color: color,
        letterSpacing: -0.4,
      );

  static TextStyle displayM(Color color) => TextStyle(
        fontFamily: displayFamily,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        fontSize: 28,
        height: 34 / 28,
        color: color,
        letterSpacing: -0.3,
      );

  static TextStyle wordmark(Color color) => TextStyle(
        fontFamily: displayFamily,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        fontSize: 24,
        height: 1.0,
        color: color,
        letterSpacing: 4.0, // wide-set wordmark reads as a logotype
      );

  static TextStyle headline(Color color) => TextStyle(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        height: 28 / 22,
        color: color,
      );

  static TextStyle bodyL(Color color) => TextStyle(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w400,
        fontSize: 17,
        height: 24 / 17,
        color: color,
      );

  static TextStyle bodyM(Color color) => TextStyle(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w400,
        fontSize: 15,
        height: 22 / 15,
        color: color,
      );

  static TextStyle caption(Color color) => TextStyle(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w500,
        fontSize: 13,
        height: 18 / 13,
        color: color,
      );

  static TextStyle button(Color color) => TextStyle(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 1.0,
        color: color,
        letterSpacing: 0.2,
      );

  static TextStyle italicCaption(Color color) => TextStyle(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        fontSize: 13,
        height: 18 / 13,
        color: color,
      );
}
