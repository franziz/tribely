import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod [StreamProvider] that emits [AppLifecycleState] changes.
///
/// Backed by a [WidgetsBindingObserver]; the stream is closed (and the
/// observer deregistered) when the last listener disposes.
///
/// Usage:
/// ```dart
/// ref.listen(appLifecycleProvider, (_, next) {
///   next.whenData((state) {
///     if (state == AppLifecycleState.resumed) { /* re-fetch */ }
///   });
/// });
/// ```
final appLifecycleProvider = StreamProvider<AppLifecycleState>((ref) {
  final controller = StreamController<AppLifecycleState>.broadcast();
  final observer = _LifecycleObserver(controller);

  WidgetsBinding.instance.addObserver(observer);

  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    controller.close();
  });

  return controller.stream;
});

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this._controller);

  final StreamController<AppLifecycleState> _controller;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.isClosed) {
      _controller.add(state);
    }
  }
}
