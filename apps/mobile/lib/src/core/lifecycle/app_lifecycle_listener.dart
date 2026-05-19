import 'package:flutter/widgets.dart';

/// Listens to the host OS app-lifecycle and fires [onResumed] whenever the
/// application transitions back into the foreground (i.e. any
/// paused/inactive/hidden → [AppLifecycleState.resumed] transition).
///
/// Mount this widget ABOVE [StatefulShellRoute.indexedStack] in the router
/// tree so the observer is registered once for the whole authenticated branch,
/// rather than per-tab.  Mounting inside an indexed-stack branch would result
/// in duplicate or missed callbacks when tabs are swapped.
///
/// Usage:
/// ```dart
/// AppLifecycleListener(
///   onResumed: () { /* invalidate stale data, e.g. refetch pending check-ins */ },
///   child: AppShell(navigationShell: navigationShell),
/// )
/// ```
class AppLifecycleListener extends StatefulWidget {
  const AppLifecycleListener({
    required this.onResumed,
    required this.child,
    super.key,
  });

  /// Called every time the app transitions into [AppLifecycleState.resumed].
  /// Fired for EVERY paused→resumed cycle, not just the first.
  final VoidCallback onResumed;

  final Widget child;

  @override
  State<AppLifecycleListener> createState() => _AppLifecycleListenerState();
}

class _AppLifecycleListenerState extends State<AppLifecycleListener>
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
