import 'package:equatable/equatable.dart';

/// State for [VerificationFailureController].
///
/// Tracks the lifecycle of the "Contact support" mailto flow:
/// idle → (user taps) → disclosure shown → (user confirms) →
///   mailingInProgress → success OR showClipboardFallback (no mail client).
sealed class VerificationFailureState extends Equatable {
  const VerificationFailureState();

  @override
  List<Object?> get props => [];
}

/// Default idle state — no in-flight action.
class VerificationFailureIdle extends VerificationFailureState {
  const VerificationFailureIdle();
}

/// mailto launch is in progress (url_launcher is about to open the mail app).
class VerificationFailureLaunching extends VerificationFailureState {
  const VerificationFailureLaunching();
}

/// mailto launched successfully — mail client opened.
class VerificationFailureLaunchSuccess extends VerificationFailureState {
  const VerificationFailureLaunchSuccess();
}

/// Mail client not available (PlatformException from url_launcher) —
/// present the clipboard fallback sheet with [clipboardContent].
class VerificationFailureShowClipboardFallback
    extends VerificationFailureState {
  const VerificationFailureShowClipboardFallback({
    required this.clipboardContent,
  });

  /// The pre-formatted mailto body the user can paste into their email client.
  final String clipboardContent;

  @override
  List<Object?> get props => [clipboardContent];
}
