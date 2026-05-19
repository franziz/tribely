import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/core/lifecycle/app_lifecycle_listener.dart';

void main() {
  group('AppLifecycleListener', () {
    testWidgets('calls onResumed when AppLifecycleState.resumed is signalled',
        (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        AppLifecycleListener(
          onResumed: () => callCount++,
          child: const SizedBox(),
        ),
      );

      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(callCount, 1);
    });

    testWidgets('does NOT call onResumed for paused state', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        AppLifecycleListener(
          onResumed: () => callCount++,
          child: const SizedBox(),
        ),
      );

      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);

      expect(callCount, 0);
    });

    testWidgets('does NOT call onResumed for inactive state', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        AppLifecycleListener(
          onResumed: () => callCount++,
          child: const SizedBox(),
        ),
      );

      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      expect(callCount, 0);
    });

    testWidgets('does NOT call onResumed for hidden state', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        AppLifecycleListener(
          onResumed: () => callCount++,
          child: const SizedBox(),
        ),
      );

      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.hidden);

      expect(callCount, 0);
    });

    testWidgets('calls onResumed on every paused→resumed transition',
        (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        AppLifecycleListener(
          onResumed: () => callCount++,
          child: const SizedBox(),
        ),
      );

      // First cycle.
      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(callCount, 1);

      // Second cycle.
      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(callCount, 2);

      // Third cycle.
      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(callCount, 3);
    });

    testWidgets('does NOT call onResumed after widget is disposed',
        (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        AppLifecycleListener(
          onResumed: () => callCount++,
          child: const SizedBox(),
        ),
      );

      // Unmount the widget.
      await tester.pumpWidget(const SizedBox());

      // Signal resumed after disposal — should be a no-op.
      await tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(callCount, 0);
    });

    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        AppLifecycleListener(
          onResumed: () {},
          child: const Text('hello', textDirection: TextDirection.ltr),
        ),
      );

      expect(find.text('hello'), findsOneWidget);
    });
  });
}
