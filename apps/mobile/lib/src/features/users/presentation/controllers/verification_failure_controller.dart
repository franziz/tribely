import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../state/verification_failure_state.dart';
import '../state/selfie_gating_state.dart';
import '../../domain/value_objects/selfie_failure_category.dart';
import '../providers/capability_providers.dart';

/// Controls the "Contact support" mailto flow on the verification failure /
/// lockout screen.
///
/// Lifecycle:
///   1. Caller invokes [openMailClient].
///   2. Controller builds the mailto URL and calls url_launcher.
///   3. On success → [VerificationFailureLaunchSuccess].
///   4. On [PlatformException] (no mail client) → [VerificationFailureShowClipboardFallback].
///
/// Usage: pair with [NotifierProvider.autoDispose] per project conventions
/// (see capability_providers.dart gotcha in CLAUDE.md).
class VerificationFailureController extends Notifier<VerificationFailureState> {
  @override
  VerificationFailureState build() => const VerificationFailureIdle();

  /// Builds and launches the mailto URL.
  ///
  /// On [PlatformException] or any launch failure, transitions to
  /// [VerificationFailureShowClipboardFallback] with the pre-formatted body so
  /// the user can paste it manually.
  Future<void> openMailClient() async {
    if (state is VerificationFailureLaunching) return; // prevent double-tap
    state = const VerificationFailureLaunching();

    final session = ref.read(sessionControllerProvider);
    final userId = switch (session) {
      SessionAuthenticated(:final session) => session.user.id,
      _ => 'unknown',
    };
    // Short ID: first 8 chars for privacy-friendly display in the mailto.
    final userIdShort = userId.length > 8 ? userId.substring(0, 8) : userId;

    final gatingState = ref.read(selfieGatingStateProvider);
    final int attemptsUsed = switch (gatingState) {
      SelfieGatingFailed(:final attemptCount) => attemptCount,
      SelfieGatingLocked() => 3,
      _ => 0,
    };
    final SelfieFailureCategory? lastCategory = switch (gatingState) {
      SelfieGatingFailed(:final category) => category,
      SelfieGatingLocked(:final category) => category,
      _ => null,
    };
    final reasonString = lastCategory?.toJson() ?? 'unknown';

    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      // Gracefully degrade — version info is nice-to-have.
    }
    final version = packageInfo != null
        ? '${packageInfo.version}+${packageInfo.buildNumber}'
        : 'unknown';

    final osName = Platform.isIOS
        ? 'iOS'
        : Platform.isAndroid
        ? 'Android'
        : Platform.isMacOS
        ? 'macOS'
        : Platform.isLinux
        ? 'Linux'
        : Platform.isWindows
        ? 'Windows'
        : 'unknown';

    final body = _buildMailtoBody(
      userIdShort: userIdShort,
      attemptsUsed: attemptsUsed,
      reasonCategory: reasonString,
      version: version,
      os: osName,
    );

    final subject = '[Tribely] Selfie review appeal — $userIdShort';
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: 'support@gotribely.com',
      queryParameters: {'subject': subject, 'body': body},
    );

    try {
      final launched = await launchUrl(mailtoUri);
      if (!ref.mounted) return;
      if (launched) {
        state = const VerificationFailureLaunchSuccess();
      } else {
        // launchUrl returned false — no app available.
        state = VerificationFailureShowClipboardFallback(
          clipboardContent: body,
        );
      }
    } on Exception {
      // PlatformException or any other exception from url_launcher.
      if (!ref.mounted) return;
      state = VerificationFailureShowClipboardFallback(clipboardContent: body);
    }
  }

  /// Resets back to idle (e.g. after the clipboard sheet is dismissed).
  void reset() => state = const VerificationFailureIdle();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _buildMailtoBody({
    required String userIdShort,
    required int attemptsUsed,
    required String reasonCategory,
    required String version,
    required String os,
  }) => buildMailtoBodyForTest(
    userIdShort: userIdShort,
    attemptsUsed: attemptsUsed,
    reasonCategory: reasonCategory,
    version: version,
    os: os,
  );

  /// Exposed for testing — builds the mailto body string.
  /// Production code calls [_buildMailtoBody]; tests call this directly.
  static String buildMailtoBodyForTest({
    required String userIdShort,
    required int attemptsUsed,
    required String reasonCategory,
    required String version,
    required String os,
  }) =>
      'Hi Tribely support,\n\n'
      "I'd like to appeal my selfie review result.\n\n"
      'User ID: $userIdShort\n'
      'Attempts used: $attemptsUsed of 3\n'
      'Last rejection reason: $reasonCategory\n'
      'App version: $version\n'
      'OS: $os\n\n'
      '[You can add more context here — the more detail, the faster we can help.]';
}

/// Stable provider — autoDispose so state resets when the failure page leaves
/// the widget tree. `Notifier<T>` + `NotifierProvider.autoDispose` per project
/// convention (CLAUDE.md gotcha: do NOT use `AutoDisposeNotifier<T>`).
final verificationFailureControllerProvider =
    NotifierProvider.autoDispose<
      VerificationFailureController,
      VerificationFailureState
    >(VerificationFailureController.new);
