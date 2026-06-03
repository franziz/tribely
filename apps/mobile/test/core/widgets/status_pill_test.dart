import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/design/colors.dart';
import 'package:tribely/src/core/widgets/status_pill.dart';

/// Wraps the widget in a MaterialApp+Scaffold so Theme/MediaQuery are present.
Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('StatusPill — rendering', () {
    for (final state in StatusPillState.values) {
      testWidgets('renders label text for state $state', (tester) async {
        await tester.pumpWidget(_wrap(StatusPill(state: state)));
        await tester.pump();

        final expected = switch (state) {
          StatusPillState.pending => 'Pending',
          StatusPillState.approved => 'Approved',
          StatusPillState.declined => 'Declined',
          StatusPillState.withdrawn => 'Withdrawn',
          StatusPillState.removedByHost => 'Removed',
          StatusPillState.cancelled => 'Cancelled',
        };
        expect(find.text(expected), findsOneWidget);
      });
    }

    testWidgets('pending: light background is paperAccentSoft', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.pending)),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperAccentSoft;
      });
      expect(hasBg, isTrue);
    });

    testWidgets('approved: light background is paperSuccessSoft', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.approved)),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperSuccessSoft;
      });
      expect(hasBg, isTrue);
    });

    testWidgets('declined: light background is paperBorderSubtle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.declined)),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperBorderSubtle;
      });
      expect(hasBg, isTrue);
    });

    testWidgets('withdrawn: light background is paperBorderSubtle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.withdrawn)),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperBorderSubtle;
      });
      expect(hasBg, isTrue);
    });

    testWidgets('removedByHost: light background is paperBorderSubtle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.removedByHost)),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperBorderSubtle;
      });
      expect(hasBg, isTrue);
    });

    testWidgets('removedByHost: light foreground dot is paperAccent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.removedByHost)),
      );
      await tester.pump();

      // The leading dot is a DecoratedBox with BoxShape.circle; its color must
      // be paperAccent in light mode.
      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasDot = decoratedBoxes.any((db) {
        final deco = db.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.shape == BoxShape.circle &&
            deco.color == TribelyColors.paperAccent;
      });
      expect(hasDot, isTrue);
    });

    testWidgets('cancelled: light background is paperBorderSubtle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.cancelled)),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.paperBorderSubtle;
      });
      expect(hasBg, isTrue);
    });

    testWidgets('cancelled: light foreground dot is paperInkSecondary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.cancelled)),
      );
      await tester.pump();

      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasDot = decoratedBoxes.any((db) {
        final deco = db.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.shape == BoxShape.circle &&
            deco.color == TribelyColors.paperInkSecondary;
      });
      expect(hasDot, isTrue);
    });

    testWidgets('pill has 99dp border-radius', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.pending)),
      );
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

    testWidgets('has a leading 6dp dot (DecoratedBox with BoxShape.circle)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.approved)),
      );
      await tester.pump();

      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasDot = decoratedBoxes.any((db) {
        final deco = db.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.shape == BoxShape.circle;
      });
      expect(hasDot, isTrue);
    });

    testWidgets('touch target is at least 48dp tall', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.pending)),
      );
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byType(StatusPill));
      expect(box.size.height, greaterThanOrEqualTo(48));
    });
  });

  group('StatusPill — semantics', () {
    testWidgets('pending exposes "Request status: Pending"', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.pending)),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Request status: Pending'), findsOneWidget);
    });

    testWidgets('approved exposes "Request status: Approved"', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.approved)),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Request status: Approved'), findsOneWidget);
    });

    testWidgets('declined exposes "Request status: Declined"', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.declined)),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Request status: Declined'), findsOneWidget);
    });

    testWidgets('withdrawn exposes "Request status: Withdrawn"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.withdrawn)),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('Request status: Withdrawn'),
        findsOneWidget,
      );
    });

    testWidgets(
      'with semanticsContext, label becomes "Request status: [State], for [context]"',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const StatusPill(
              state: StatusPillState.approved,
              semanticsContext: 'Sunrise hike',
            ),
          ),
        );
        await tester.pump();

        expect(
          find.bySemanticsLabel('Request status: Approved, for Sunrise hike'),
          findsOneWidget,
        );
      },
    );

    testWidgets('removedByHost exposes "Request status: Removed"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.removedByHost)),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Request status: Removed'), findsOneWidget);
    });

    testWidgets('cancelled exposes "Request status: Cancelled"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusPill(state: StatusPillState.cancelled)),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('Request status: Cancelled'),
        findsOneWidget,
      );
    });

    testWidgets(
      'semanticsPrefix overrides leading portion of semantics label',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const StatusPill(
              state: StatusPillState.cancelled,
              semanticsPrefix: 'Event status',
            ),
          ),
        );
        await tester.pump();

        expect(
          find.bySemanticsLabel('Event status: Cancelled'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'semanticsPrefix with semanticsContext produces full composite label',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const StatusPill(
              state: StatusPillState.cancelled,
              semanticsPrefix: 'Event status',
              semanticsContext: 'Morning jog',
            ),
          ),
        );
        await tester.pump();

        expect(
          find.bySemanticsLabel('Event status: Cancelled, for Morning jog'),
          findsOneWidget,
        );
      },
    );

    testWidgets('null semanticsPrefix falls back to "Request status" default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatusPill(
            state: StatusPillState.approved,
            // semanticsPrefix not set — should use the default
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Request status: Approved'), findsOneWidget);
    });

    testWidgets(
      'without semanticsContext, label does NOT contain "for" suffix',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const StatusPill(state: StatusPillState.declined)),
        );
        await tester.pump();

        // Verify the clean label exists and no unintended suffix is appended.
        expect(
          find.bySemanticsLabel('Request status: Declined'),
          findsOneWidget,
        );
      },
    );
  });

  group('StatusPill — dark mode', () {
    testWidgets('pending dark: background is nightAccentSoft', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatusPill(state: StatusPillState.pending),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.nightAccentSoft;
      });
      expect(hasBg, isTrue);
    });

    testWidgets('approved dark: background is nightSuccessSoft', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatusPill(state: StatusPillState.approved),
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

    testWidgets('removedByHost dark: background is nightBorderSubtle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatusPill(state: StatusPillState.removedByHost),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.nightBorderSubtle;
      });
      expect(hasBg, isTrue);
    });

    testWidgets('removedByHost dark: foreground dot is nightAccent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatusPill(state: StatusPillState.removedByHost),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasDot = decoratedBoxes.any((db) {
        final deco = db.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.shape == BoxShape.circle &&
            deco.color == TribelyColors.nightAccent;
      });
      expect(hasDot, isTrue);
    });

    testWidgets('cancelled dark: background is nightBorderSubtle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatusPill(state: StatusPillState.cancelled),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBg = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.color == TribelyColors.nightBorderSubtle;
      });
      expect(hasBg, isTrue);
    });

    testWidgets('cancelled dark: foreground dot is nightInkSecondary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatusPill(state: StatusPillState.cancelled),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasDot = decoratedBoxes.any((db) {
        final deco = db.decoration;
        if (deco is! BoxDecoration) return false;
        return deco.shape == BoxShape.circle &&
            deco.color == TribelyColors.nightInkSecondary;
      });
      expect(hasDot, isTrue);
    });
  });

  group('StatusPill — golden', () {
    testWidgets('all four states render correctly (light)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusPill(state: StatusPillState.pending),
                StatusPill(state: StatusPillState.approved),
                StatusPill(state: StatusPillState.declined),
                StatusPill(state: StatusPillState.withdrawn),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(Column),
        matchesGoldenFile('goldens/status_pill_all_states_light.png'),
      );
    }, skip: Platform.isLinux);
  });
}
