import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/design/colors.dart';
import 'package:tribely/src/core/widgets/banner_message.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('BannerMessage — accent variant (default)', () {
    testWidgets('default renders accent background (paperAccentSoft)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BannerMessage(message: 'Test error')),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasAccentBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperAccentSoft;
      });
      expect(hasAccentBg, isTrue);
    });

    testWidgets('default renders accent left border (paperAccent)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BannerMessage(message: 'Test error')),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasAccentBorder = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        final border = deco.border;
        if (border is! Border) return false;
        return border.left.color == TribelyColors.paperAccent;
      });
      expect(hasAccentBorder, isTrue);
    });

    testWidgets('explicit accent variant renders the same as default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BannerMessage(
            message: 'Test error',
            variant: BannerVariant.accent,
          ),
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasAccentBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperAccentSoft;
      });
      expect(hasAccentBg, isTrue);
    });
  });

  group('BannerMessage — neutral variant', () {
    testWidgets('neutral renders paperSurfaceHigh background', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BannerMessage(
            message: 'Informational note',
            variant: BannerVariant.neutral,
          ),
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasNeutralBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperSurfaceHigh;
      });
      expect(hasNeutralBg, isTrue);
    });

    testWidgets('neutral renders paperBorderSubtle left border', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BannerMessage(
            message: 'Informational note',
            variant: BannerVariant.neutral,
          ),
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasNeutralBorder = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        final border = deco.border;
        if (border is! Border) return false;
        return border.left.color == TribelyColors.paperBorderSubtle;
      });
      expect(hasNeutralBorder, isTrue);
    });

    testWidgets('neutral renders text in paperInkSecondary', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BannerMessage(
            message: 'Informational note',
            variant: BannerVariant.neutral,
          ),
        ),
      );
      await tester.pump();

      final textWidget = tester.widget<Text>(find.text('Informational note'));
      expect(textWidget.style?.color, TribelyColors.paperInkSecondary);
    });

    testWidgets('neutral does NOT render accent background', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BannerMessage(
            message: 'Informational note',
            variant: BannerVariant.neutral,
          ),
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasAccentBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperAccentSoft;
      });
      expect(hasAccentBg, isFalse);
    });

    testWidgets('neutral dark: nightSurfaceHigh background', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BannerMessage(
            message: 'Dark note',
            variant: BannerVariant.neutral,
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasNightBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.nightSurfaceHigh;
      });
      expect(hasNightBg, isTrue);
    });

    testWidgets('neutral dark: nightBorderSubtle left border', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BannerMessage(
            message: 'Dark note',
            variant: BannerVariant.neutral,
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasNightBorder = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        final border = deco.border;
        if (border is! Border) return false;
        return border.left.color == TribelyColors.nightBorderSubtle;
      });
      expect(hasNightBorder, isTrue);
    });

    testWidgets('neutral dark: text in nightInkSecondary', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BannerMessage(
            message: 'Dark note',
            variant: BannerVariant.neutral,
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      final textWidget = tester.widget<Text>(find.text('Dark note'));
      expect(textWidget.style?.color, TribelyColors.nightInkSecondary);
    });
  });
}
