import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/check_ins_providers.dart';
import '../state/check_ins_state.dart';
import 'safety_check_in_intro_sheet.dart';
import 'safety_check_in_sheet.dart';

/// Invisible overlay widget that watches [checkInsControllerProvider] state
/// and imperatively presents the check-in sheets when a pending check-in
/// becomes [CheckInsShowing].
///
/// Mounted ABOVE [StatefulShellRoute.indexedStack] in [app_router.dart] so
/// sheet presentation survives tab switches and branch navigation.
///
/// Flow when state becomes [CheckInsShowing]:
///   1. If the one-time intro hasn't been seen: show [SafetyCheckInIntroSheet],
///      mark it seen.
///   2. Show [SafetyCheckInSheet] with the pending check-in data.
///
/// The intro flag check + mark is driven here (not inside the sheet) so that
/// the intro sheet is guaranteed to appear before the prompt sheet even if the
/// sheets are shown in quick succession on first launch.
class CheckInsOverlay extends ConsumerStatefulWidget {
  const CheckInsOverlay({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CheckInsOverlay> createState() => _CheckInsOverlayState();
}

class _CheckInsOverlayState extends ConsumerState<CheckInsOverlay> {
  /// Guards against re-entrant sheet presentation if the state somehow emits
  /// [CheckInsShowing] while a sheet is already being presented.
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    // Listen after the first frame so the BuildContext has a valid Navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachListener());
  }

  void _attachListener() {
    if (!mounted) return;
    ref.listenManual<CheckInsState>(checkInsControllerProvider, (
      previous,
      next,
    ) {
      if (next is CheckInsShowing) {
        _maybePresent(next);
      }
    }, fireImmediately: false);
  }

  Future<void> _maybePresent(CheckInsShowing state) async {
    if (_presenting || !mounted) return;
    _presenting = true;

    try {
      final introStorage = ref.read(introFlagStorageProvider);
      const introKey = 'safety_check_in_intro';

      // Show the one-time intro sheet if the user hasn't seen it yet.
      if (!await introStorage.hasSeen(introKey)) {
        if (!mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => SafetyCheckInIntroSheet(
            onDismiss: () => Navigator.of(context).pop(),
          ),
        );
        await introStorage.markSeen(introKey);
      }

      if (!mounted) return;

      // Present the actual check-in prompt sheet.
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => SafetyCheckInSheet(
          checkInId: state.item.id,
          eventTitle: state.item.eventTitle,
        ),
      );

      // If the sheet was dismissed via back/drag without acting (the user
      // neither tapped "All good" nor "I need help"), the controller is still
      // in CheckInsShowing. Dismiss it client-side so the record stays pending
      // server-side and will be re-surfaced on next foreground resume.
      if (!mounted) return;
      final currentState = ref.read(checkInsControllerProvider);
      if (currentState is CheckInsShowing) {
        ref.read(checkInsControllerProvider.notifier).dismissShown();
      }
    } finally {
      _presenting = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
