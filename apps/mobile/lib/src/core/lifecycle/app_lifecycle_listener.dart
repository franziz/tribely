import 'package:flutter/widgets.dart';

/// Listens to the host OS app-lifecycle and fires [onResumed] whenever the
/// application transitions back into the foreground (i.e. any
/// paused/inactive/hidden → [AppLifecycleState.resumed] transition).
///
/// Named [OnResumedListener] (not `AppLifecycleListener`) to avoid collision
/// with the identically-named built-in widget shipped in `package:flutter/widgets.dart`
/// since Flutter 3.13.
///
/// Mount this widget ABOVE [StatefulShellRoute.indexedStack] in the router
/// tree so the observer is registered once for the whole authenticated branch,
/// rather than per-tab.  Mounting inside an indexed-stack branch would result
/// in duplicate or missed callbacks when tabs are swapped.
///
/// Usage:
/// ```dart
/// OnResumedListener(
///   onResumed: () { /* invalidate stale data, e.g. refetch pending check-ins */ },
///   child: AppShell(navigationShell: navigationShell),
/// )
/// ```
class OnResumedListener extends StatefulWidget {
  const OnResumedListener({
    required this.onResumed,
    required this.child,
    super.key,
  });

  /// Called every time the app transitions into [AppLifecycleState.resumed].
  /// Fired for EVERY paused→resumed cycle, not just the first.
  final VoidCallback onResumed;

  final Widget child;

  @override
  State<OnResumedListener> createState() => _OnResumedListenerState();
}

class _OnResumedListenerState extends State<OnResumedListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
