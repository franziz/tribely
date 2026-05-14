import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/design/colors.dart';
import 'package:tribely/src/core/widgets/verified_pill.dart';

/// Wraps the widget in a MaterialApp+Scaffold so Theme/MediaQuery are present.
Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('VerifiedPill — rendering', () {
    testWidgets('renders Icons.verified glyph at size 14 when isVerified=true',
        (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedPill(isVerified: true)));
      await tester.pump();

      expect(find.byIcon(Icons.verified), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.verified));
      expect(icon.size, 14);
    });

    testWidgets('renders "Verified" label when isVerified=true', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const VerifiedPill(isVerified: true)));
      await tester.pump();

      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('light: foreground uses paperSuccess', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedPill(isVerified: true)));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.verified));
      expect(icon.color, TribelyColors.paperSuccess);
    });

    testWidgets('light: background uses paperSuccessSoft', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedPill(isVerified: true)));
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperSuccessSoft;
      });
      expect(hasBg, isTrue);
    });

    testWidgets('pill has 99dp border-radius', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedPill(isVerified: true)));
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasPillRadius = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        final br = deco.borderRadius;
        if (br is! BorderRadius) return false;
        return br.topLeft == const Radius.circular(99);
      });
      expect(hasPillRadius, isTrue);
    });

    testWidgets('container height is 20dp', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedPill(isVerified: true)));
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final has20dp = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return c.constraints?.maxHeight == 20 ||
            tester
                    .renderObject<RenderBox>(
                      find.byWidgetPredicate((w) => w == c),
                    )
                    .size
                    .height ==
                20;
      });
      expect(has20dp, isTrue);
    });

    testWidgets('isVerified=false renders SizedBox.shrink (zero size)',
        (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedPill(isVerified: false)));
      await tester.pump();

      final box = tester.renderObject<RenderBox>(
        find.byType(VerifiedPill),
      );
      expect(box.size, Size.zero);
    });

    testWidgets('isVerified=false renders nothing visible', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedPill(isVerified: false)));
      await tester.pump();

      expect(find.byIcon(Icons.verified), findsNothing);
      expect(find.text('Verified'), findsNothing);
    });
  });

  group('VerifiedPill — semantics', () {
    testWidgets('isVerified=true exposes "Verified" semantics label',
        (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedPill(isVerified: true)));
      await tester.pump();

      expect(find.bySemanticsLabel('Verified'), findsOneWidget);
    });

    testWidgets('isVerified=false contributes nothing to semantics tree',
        (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedPill(isVerified: false)));
      await tester.pump();

      expect(find.bySemanticsLabel('Verified'), findsNothing);
    });
  });

  group('VerifiedPill — dark mode', () {
    testWidgets('dark: foreground uses nightSuccess', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VerifiedPill(isVerified: true),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.verified));
      expect(icon.color, TribelyColors.nightSuccess);
    });

    testWidgets('dark: background uses nightSuccessSoft', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VerifiedPill(isVerified: true),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.nightSuccessSoft;
      });
      expect(hasBg, isTrue);
    });
  });

  group('VerifiedPill — golden', () {
    testWidgets('verified state renders correctly (light)', (tester) async {
      await tester.pumpWidget(
        _wrap(const VerifiedPill(isVerified: true)),
      );
      await tester.pump();

      await expectLater(
        find.byType(VerifiedPill),
        matchesGoldenFile('goldens/verified_pill_true_light.png'),
      );
    }, skip: Platform.isLinux);
  });
}
