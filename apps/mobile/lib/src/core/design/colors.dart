import 'package:flutter/material.dart';

/// Equatorial Editorial — palette tokens.
///
/// Light mode is the default daytime theme; dark mode is the equatorial-
/// evening counterpart. Both have warm undertones throughout — pure white
/// and pure black are deliberately avoided.
///
/// Sourcing reference (rationale): see apps/mobile/design/login/spec.md.
class TribelyColors {
  const TribelyColors._();

  // Light — Equatorial Paper
  static const Color paperSurface = Color(0xFFFAF6EF);
  static const Color paperSurfaceHigh = Color(0xFFFFFFFF);
  static const Color paperInkPrimary = Color(0xFF1A1714);
  static const Color paperInkSecondary = Color(0xFF5C544A);
  static const Color paperBorderSubtle = Color(0xFFE8DFD0);
  static const Color paperPrimary = Color(0xFF1B3D3A); // teak teal
  static const Color paperPrimaryHover = Color(0xFF163331);
  static const Color paperAccent = Color(0xFFD85730); // ember coral
  static const Color paperAccentSoft = Color(0xFFFCE4DC); // banner backdrop
  static const Color paperSuccess = Color(0xFF4A7C59);
  static const Color paperSuccessSoft = Color(
    0xFFE6F2EA,
  ); // approved pill backdrop

  // Dark — Equatorial Night
  static const Color nightSurface = Color(0xFF131110);
  static const Color nightSurfaceHigh = Color(0xFF1B1816);
  static const Color nightInkPrimary = Color(0xFFF4EEDF);
  static const Color nightInkSecondary = Color(0xFFA39B8A);
  static const Color nightBorderSubtle = Color(0xFF2A2522);
  static const Color nightPrimary = Color(0xFFD5A86F); // burnished brass
  static const Color nightPrimaryHover = Color(0xFFBE9156);
  static const Color nightAccent = Color(0xFFE07F5F);
  static const Color nightAccentSoft = Color(0xFF2E1F1A);
  static const Color nightSuccess = Color(0xFF82B091);
  static const Color nightSuccessSoft = Color(0xFF1F3D2A);
}
