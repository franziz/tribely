import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../providers/capability_providers.dart';
import '../state/selfie_gating_state.dart';
import '../string_assets/verification_settings_copy.dart';
import '../widgets/verification_banner.dart';
import '../widgets/verification_signal_row.dart';

/// Verification settings page — route: /settings/verification (Brief C).
///
/// Composes three verification signals (email, phone, selfie) from
/// [sessionControllerProvider] + [selfieGatingStateProvider] and renders a
/// [VerificationBanner] + three [VerificationSignalRow] widgets inside a
/// single contained card.
///
/// This page is a [ConsumerStatefulWidget] (not [ConsumerWidget]) solely
/// because of the [_isCheckingSelfie] flag that drives the in-place spinner
/// during selfie-status re-fetch. No controller is introduced.
class VerificationSettingsPage extends ConsumerStatefulWidget {
  const VerificationSettingsPage({super.key});

  @override
  ConsumerState<VerificationSettingsPage> createState() =>
      _VerificationSettingsPageState();
}

class _VerificationSettingsPageState
    extends ConsumerState<VerificationSettingsPage> {
  /// True while the selfie status re-fetch is in flight.
  /// Only relevant when the selfie state is [SelfieGatingPending].
  bool _isCheckingSelfie = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final surfaceHigh = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final borderSubtle = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    final sessionState = ref.watch(sessionControllerProvider);
    final selfieState = ref.watch(selfieGatingStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          kVerificationSettingsTitle,
          style: TribelyType.headline(ink),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: sessionState is! SessionAuthenticated
            ? _buildSkeleton()
            : _buildBody(
                context: context,
                dark: dark,
                inkSecondary: inkSecondary,
                surfaceHigh: surfaceHigh,
                borderSubtle: borderSubtle,
                user: sessionState.session.user,
                selfieState: selfieState,
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Skeleton placeholder — shown while session is restoring or has errored.
  // ---------------------------------------------------------------------------

  Widget _buildSkeleton() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 16),
          SkeletonLoader(width: double.infinity, height: 72),
          SizedBox(height: 24),
          SkeletonLoader(width: double.infinity, height: 64),
          SizedBox(height: 1),
          SkeletonLoader(width: double.infinity, height: 64),
          SizedBox(height: 1),
          SkeletonLoader(width: double.infinity, height: 64),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main body — shown when the session is authenticated.
  // ---------------------------------------------------------------------------

  Widget _buildBody({
    required BuildContext context,
    required bool dark,
    required Color inkSecondary,
    required Color surfaceHigh,
    required Color borderSubtle,
    required User user,
    required SelfieGatingState selfieState,
  }) {
    final isFullyVerified =
        user.isEmailVerified &&
        user.isPhoneVerified &&
        selfieState is SelfieGatingApproved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner — 16dp padding on all sides.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: VerificationBanner(isFullyVerified: isFullyVerified),
        ),

        const SizedBox(height: 24),

        // Signal card — 16dp horizontal padding.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderSubtle, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEmailRow(context, dark: dark, user: user),
                _buildPhoneRow(context, dark: dark, user: user),
                _buildSelfieRow(context, dark: dark, selfieState: selfieState),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Email row
  // ---------------------------------------------------------------------------

  Widget _buildEmailRow(
    BuildContext context, {
    required bool dark,
    required User user,
  }) {
    final isVerified = user.isEmailVerified;

    return VerificationSignalRow(
      label: kVerificationLabelEmail,
      icon: isVerified ? Icons.check_circle : Icons.radio_button_unchecked,
      iconColor: isVerified
          ? (dark ? TribelyColors.nightSuccess : TribelyColors.paperSuccess)
          : (dark
                ? TribelyColors.nightInkSecondary
                : TribelyColors.paperInkSecondary),
      stateLabel: isVerified
          ? kVerificationStateVerified
          : kVerificationStateNotStarted,
      ctaLabel: isVerified ? null : kVerificationCtaVerifyNow,
      onCtaTap: isVerified ? null : () => context.push('/verify-email'),
      isLastRow: false,
      isCheckingStatus: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Phone row
  // ---------------------------------------------------------------------------

  Widget _buildPhoneRow(
    BuildContext context, {
    required bool dark,
    required User user,
  }) {
    final isVerified = user.isPhoneVerified;

    return VerificationSignalRow(
      label: kVerificationLabelPhone,
      icon: isVerified ? Icons.check_circle : Icons.radio_button_unchecked,
      iconColor: isVerified
          ? (dark ? TribelyColors.nightSuccess : TribelyColors.paperSuccess)
          : (dark
                ? TribelyColors.nightInkSecondary
                : TribelyColors.paperInkSecondary),
      stateLabel: isVerified
          ? kVerificationStateVerified
          : kVerificationStateNotStarted,
      ctaLabel: isVerified ? null : kVerificationCtaVerifyNow,
      onCtaTap: isVerified ? null : () => context.push('/auth/phone/entry'),
      isLastRow: false,
      isCheckingStatus: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Selfie row — driven by [SelfieGatingState] sealed-class exhaustive switch.
  // ---------------------------------------------------------------------------

  Widget _buildSelfieRow(
    BuildContext context, {
    required bool dark,
    required SelfieGatingState selfieState,
  }) {
    return switch (selfieState) {
      SelfieGatingApproved() => VerificationSignalRow(
        label: kVerificationLabelSelfie,
        icon: Icons.check_circle,
        iconColor: dark
            ? TribelyColors.nightSuccess
            : TribelyColors.paperSuccess,
        stateLabel: kVerificationStateVerified,
        ctaLabel: null,
        onCtaTap: null,
        isLastRow: true,
        isCheckingStatus: false,
      ),
      SelfieGatingNotStarted() => VerificationSignalRow(
        label: kVerificationLabelSelfie,
        icon: Icons.radio_button_unchecked,
        iconColor: dark
            ? TribelyColors.nightInkSecondary
            : TribelyColors.paperInkSecondary,
        stateLabel: kVerificationStateNotStarted,
        ctaLabel: kVerificationCtaVerifyNow,
        onCtaTap: () => context.push('/selfie/consent'),
        isLastRow: true,
        isCheckingStatus: false,
      ),
      SelfieGatingPending() => VerificationSignalRow(
        label: kVerificationLabelSelfie,
        icon: Icons.schedule,
        iconColor: dark
            ? TribelyColors.nightInkSecondary
            : TribelyColors.paperInkSecondary,
        stateLabel: kVerificationStateSelfiePending,
        ctaLabel: kVerificationCtaCheckStatus,
        onCtaTap: _onCheckSelfieStatus,
        isLastRow: true,
        isCheckingStatus: _isCheckingSelfie,
      ),
      SelfieGatingFailed() || SelfieGatingLocked() => VerificationSignalRow(
        label: kVerificationLabelSelfie,
        icon: Icons.warning_amber,
        iconColor: dark ? TribelyColors.nightAccent : TribelyColors.paperAccent,
        stateLabel: kVerificationStateFailed,
        ctaLabel: kVerificationCtaRetry,
        onCtaTap: () => context.push('/verification/failure'),
        isLastRow: true,
        isCheckingStatus: false,
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Check selfie status — invalidates session then waits ≥600ms.
  //
  // [sessionControllerProvider] is a synchronous NotifierProvider<SessionController,
  // SessionState>, NOT an AsyncNotifier — there is no .future to await.
  // We invalidate (triggers SessionController.build() re-run) and observe a
  // 600ms minimum delay so the user perceives feedback before the spinner clears.
  // ---------------------------------------------------------------------------

  Future<void> _onCheckSelfieStatus() async {
    if (_isCheckingSelfie) return;
    setState(() => _isCheckingSelfie = true);

    ref.invalidate(sessionControllerProvider);

    // Minimum perceived-feedback window.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() => _isCheckingSelfie = false);
    }
  }
}
