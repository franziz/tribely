// Widget tests for DisabledCTAHint.
//
// Covers:
//   1. Renders full text.
//   2. Tap invokes onTap when provided.
//   3. Bi-color: accentSpan text renders with accent style; rest in secondary.
//   4. No accentSpan — single color (inkSecondary) rendered.
//   5. No onTap — widget is not tappable (no InkWell hit area).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/design/colors.dart';
import 'package:tribely/src/core/widgets/disabled_cta_hint.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('DisabledCTAHint', () {
    testWidgets('1. Renders full text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DisabledCTAHint(
            text:
                'Verify your selfie to join events. Tap to see what happened.',
          ),
        ),
      );

      expect(
        find.textContaining('Verify your selfie to join events.'),
        findsOneWidget,
      );
    });

    testWidgets('2. Tap invokes onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DisabledCTAHint(
            text: 'Tap to see what happened.',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(DisabledCTAHint));
      expect(tapped, isTrue);
    });

    testWidgets('3. Bi-color: accentSpan renders with accent color', (
      tester,
    ) async {
      const full =
          'Verify your selfie to join events. Tap to see what happened.';
      const accentPart = 'Tap to see what happened.';

      await tester.pumpWidget(
        _wrap(const DisabledCTAHint(text: full, accentSpan: accentPart)),
      );

      // The widget uses RichText with TextSpan children.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final found = richTexts.any((rt) {
        bool hasAccentSpan = false;
        rt.text.visitChildren((span) {
          if (span is TextSpan &&
              span.text == accentPart &&
              span.style?.color == TribelyColors.paperAccent) {
            hasAccentSpan = true;
          }
          return true;
        });
        return hasAccentSpan;
      });

      expect(found, isTrue, reason: 'accentSpan should render in paperAccent');
    });

    testWidgets('4. No accentSpan — single Text widget (not RichText)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DisabledCTAHint(
            text: 'Your photo is under review — check back soon.',
          ),
        ),
      );

      // No accentSpan → plain Text widget, not RichText.
      expect(
        find.text('Your photo is under review — check back soon.'),
        findsOneWidget,
      );
    });

    testWidgets('5. No onTap — no InkWell', (tester) async {
      await tester.pumpWidget(
        _wrap(const DisabledCTAHint(text: 'Read only hint.')),
      );

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('dark mode: accentSpan renders in nightAccent', (tester) async {
      const full = 'Verify your selfie. Tap to see what happened.';
      const accentPart = 'Tap to see what happened.';

      await tester.pumpWidget(
        _wrap(
          const DisabledCTAHint(text: full, accentSpan: accentPart),
          brightness: Brightness.dark,
        ),
      );

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final found = richTexts.any((rt) {
        bool hasAccentSpan = false;
        rt.text.visitChildren((span) {
          if (span is TextSpan &&
              span.text == accentPart &&
              span.style?.color == TribelyColors.nightAccent) {
            hasAccentSpan = true;
          }
          return true;
        });
        return hasAccentSpan;
      });

      expect(
        found,
        isTrue,
        reason: 'dark mode accentSpan should use nightAccent',
      );
    });
  });
}
