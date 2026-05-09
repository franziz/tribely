import 'package:flutter/material.dart';

/// Motion tokens.
///
/// Most things take 200–300ms. Slower than 300ms feels broken; faster than
/// 200ms feels jittery. The splash ink draw is the one place we let an
/// animation run long (~800ms) — it's the brand signature.
class TribelyMotion {
  const TribelyMotion._();

  static const Duration micro = Duration(milliseconds: 80);
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration long = Duration(milliseconds: 400);
  static const Duration brand = Duration(milliseconds: 800);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
}

/// Helper: respects MediaQuery.disableAnimations / accessibilityFeatures.
extension TribelyMotionContext on BuildContext {
  bool get reduceMotion => MediaQuery.of(this).disableAnimations;

  Duration motion(Duration normal, {Duration? reduced}) =>
      reduceMotion ? (reduced ?? Duration.zero) : normal;
}
