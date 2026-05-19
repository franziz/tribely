import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// Equatorial Editorial — Material 3 ThemeData for light + dark.
///
/// We override the core ColorScheme rather than seeding from a single color
/// so the warm/cool relationships in the spec are preserved exactly. Anything
/// we don't override falls back to Material 3 defaults, but the auth flow
/// uses bespoke widgets that consume our color/type tokens directly rather
/// than relying on Material's defaults — so the theme is mostly a safety net
/// for any future Material widgets that slip in.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme.light(
      surface: TribelyColors.paperSurface,
      onSurface: TribelyColors.paperInkPrimary,
      surfaceContainerHighest: TribelyColors.paperSurfaceHigh,
      primary: TribelyColors.paperPrimary,
      onPrimary: TribelyColors.paperSurfaceHigh,
      secondary: TribelyColors.paperAccent,
      onSecondary: TribelyColors.paperSurfaceHigh,
      error: TribelyColors.paperAccent,
      onError: TribelyColors.paperSurfaceHigh,
      outline: TribelyColors.paperBorderSubtle,
    );
    return _build(
      brightness: Brightness.light,
      scheme: scheme,
      surface: TribelyColors.paperSurface,
      ink: TribelyColors.paperInkPrimary,
      inkSecondary: TribelyColors.paperInkSecondary,
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      surface: TribelyColors.nightSurface,
      onSurface: TribelyColors.nightInkPrimary,
      surfaceContainerHighest: TribelyColors.nightSurfaceHigh,
      primary: TribelyColors.nightPrimary,
      onPrimary: TribelyColors.nightSurface,
      secondary: TribelyColors.nightAccent,
      onSecondary: TribelyColors.nightSurface,
      error: TribelyColors.nightAccent,
      onError: TribelyColors.nightSurface,
      outline: TribelyColors.nightBorderSubtle,
    );
    return _build(
      brightness: Brightness.dark,
      scheme: scheme,
      surface: TribelyColors.nightSurface,
      ink: TribelyColors.nightInkPrimary,
      inkSecondary: TribelyColors.nightInkSecondary,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color surface,
    required Color ink,
    required Color inkSecondary,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: TribelyType.bodyFamily,
      textTheme: TextTheme(
        displayLarge: TribelyType.displayL(ink),
        displayMedium: TribelyType.displayM(ink),
        headlineMedium: TribelyType.headline(ink),
        bodyLarge: TribelyType.bodyL(ink),
        bodyMedium: TribelyType.bodyM(ink),
        labelLarge: TribelyType.button(scheme.onPrimary),
        labelMedium: TribelyType.caption(inkSecondary),
        labelSmall: TribelyType.caption(inkSecondary),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: scheme.outline,
      iconTheme: IconThemeData(color: ink, size: 24),
      // Outlined buttons: 56dp tall, 12dp corners, 1.5dp border in the
      // scheme.primary colour (teak-teal / burnished-brass depending on
      // brightness). This makes OutlinedButton the visual partner to
      // PrimaryButton without requiring a bespoke wrapper widget.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: TribelyType.bodyFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            height: 1.0,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
