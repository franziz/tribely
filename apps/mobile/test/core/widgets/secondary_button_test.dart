import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/widgets/secondary_button.dart';

// Wraps the widget in a minimal MaterialApp so Theme and MediaQuery are
// available, matching the pattern used across the test suite.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('SecondaryButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(SecondaryButton(label: 'Maybe later', onPressed: () {})),
      );

      expect(find.text('Maybe later'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          SecondaryButton(
            label: 'Maybe later',
            onPressed: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(SecondaryButton));
      expect(tapped, isTrue);
    });

    testWidgets('shows CircularProgressIndicator when isLoading=true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SecondaryButton(
            label: 'Maybe later',
            onPressed: () {},
            isLoading: true,
          ),
        ),
      );

      // Allow AnimatedSwitcher to settle.
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Label text should not be visible while loading.
      expect(find.text('Maybe later'), findsNothing);
    });

    testWidgets('does not fire onPressed when isLoading=true', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          SecondaryButton(
            label: 'Maybe later',
            onPressed: () => tapped = true,
            isLoading: true,
          ),
        ),
      );

      await tester.tap(find.byType(SecondaryButton));
      expect(tapped, isFalse);
    });

    testWidgets('fullWidth=true wraps in SizedBox with infinite width', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SecondaryButton(
            label: 'Maybe later',
            onPressed: () {},
            // fullWidth defaults to true
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(OutlinedButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, equals(double.infinity));
    });

    testWidgets('fullWidth=false does not wrap in an infinite-width SizedBox', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SecondaryButton(
            label: 'Maybe later',
            onPressed: () {},
            fullWidth: false,
          ),
        ),
      );

      // The OutlinedButton's direct parent should NOT be an infinite-width
      // SizedBox (the widget itself returns the button unwrapped).
      final ancestorSizedBoxes = tester.widgetList<SizedBox>(
        find.ancestor(
          of: find.byType(OutlinedButton),
          matching: find.byType(SizedBox),
        ),
      );
      final hasInfiniteWidthParent = ancestorSizedBoxes.any(
        (box) => box.width == double.infinity,
      );
      expect(hasInfiniteWidthParent, isFalse);
    });

    testWidgets('tap target meets 48dp minimum when fullWidth=false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SecondaryButton(
            label: 'X',
            onPressed: () {},
            fullWidth: false,
          ),
        ),
      );

      final renderBox = tester.renderObject<RenderBox>(find.byType(SecondaryButton));
      expect(renderBox.size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('disabled when onPressed is null — tap does not throw', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SecondaryButton(
            label: 'Maybe later',
            onPressed: null,
          ),
        ),
      );

      // Tap on a disabled button must not throw or invoke any callback.
      await tester.tap(find.byType(SecondaryButton), warnIfMissed: false);
      await tester.pump();
      // Still renders the label after the tap.
      expect(find.text('Maybe later'), findsOneWidget);
    });
  });
}
