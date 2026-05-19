import 'package:flutter/material.dart';

import '../../../../core/widgets/banner_message.dart';
import '../string_assets/review_copy.dart';

/// Client-side banner shown on the review composer when in edit mode
/// and the 24-hour edit window has elapsed.
///
/// The banner is purely decorative/informational — the submit button is
/// also disabled in this state. The server still enforces the window as
/// defense-in-depth.
///
/// Renders the [BannerVariant.neutral] style (informational, not error).
class EditWindowExpiryBanner extends StatelessWidget {
  const EditWindowExpiryBanner({super.key});

  /// Returns true when the edit window for [review.createdAt] has closed.
  static bool isExpired(DateTime createdAt) =>
      DateTime.now().difference(createdAt).inHours >= 24;

  @override
  Widget build(BuildContext context) {
    return const BannerMessage(
      message: ReviewCopy.editWindowExpired,
      variant: BannerVariant.neutral,
    );
  }
}
