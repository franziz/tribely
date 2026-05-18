// DEPRECATED — replaced by VerificationRequiredBanner(type: VerificationType.email).
// Kept as a forwarding shim so any import that survived refactoring
// compiles without change. All new code should use VerificationRequiredBanner directly.
// This file will be deleted once the last reference is removed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/verification_required_banner.dart';

/// @deprecated Use [VerificationRequiredBanner] with
/// [VerificationType.email] instead.
@Deprecated('Use VerificationRequiredBanner(type: VerificationType.email)')
class EmailNotVerifiedBanner extends ConsumerWidget {
  const EmailNotVerifiedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const VerificationRequiredBanner(type: VerificationType.email);
  }
}
