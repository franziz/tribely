import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:tribely/src/core/widgets/skeleton_loader.dart';

/// Wraps the widget in a MaterialApp + Scaffold so Theme / MediaQuery are
/// available — mirrors the pattern used in [secondary_button_test.dart].
Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// Wraps inside a constrained box to simulate a realistic viewport column
/// width (e.g., 375dp or 414dp) when testing full-width children.
Widget _wrapConstrained(Widget child, {required double width}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  group('SkeletonLoader', () {
    testWidgets('renders with explicit width and height', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonLoader(width: 200, height: 60)),
      );

      final box = tester.renderObject<RenderBox>(find.byType(SkeletonLoader));
      expect(box.size.width, equals(200));
      expect(box.size.height, equals(60));
    });

    testWidgets('uses Shimmer.fromColors as its shimmer driver', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SkeletonLoader(width: 100, height: 40)),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('default borderRadius is 8', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonLoader(width: 100, height: 40)),
      );

      // The inner Container's BoxDecoration carries the BorderRadius.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasRadius8 = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        final br = deco.borderRadius;
        if (br is! BorderRadius) return false;
        return br.topLeft == const Radius.circular(8);
      });
      expect(hasRadius8, isTrue);
    });

    testWidgets('custom borderRadius is applied', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonLoader(width: 100, height: 40, borderRadius: 16)),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasRadius16 = containers.any((c) {
        final deco = c.decoration;
        if (deco is! BoxDecoration) return false;
        final br = deco.borderRadius;
        if (br is! BorderRadius) return false;
        return br.topLeft == const Radius.circular(16);
      });
      expect(hasRadius16, isTrue);
    });

    testWidgets('does not overflow at 375dp width', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapConstrained(
          const SkeletonLoader(width: double.infinity, height: 40),
          width: 375,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('SkeletonEventCard', () {
    testWidgets('renders without overflow at 375dp viewport', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapConstrained(const SkeletonEventCard(), width: 375),
      );

      // Shimmer.fromColors runs a repeating AnimationController — pumpAndSettle
      // deadlocks on it. A single pump is sufficient to trigger layout and
      // detect any RenderFlex overflow exceptions.
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow at 414dp viewport', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapConstrained(const SkeletonEventCard(), width: 414),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses Shimmer.fromColors as its shimmer driver', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapConstrained(const SkeletonEventCard(), width: 375),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('card height is at least 160dp (image + text + padding)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapConstrained(const SkeletonEventCard(), width: 375),
      );

      await tester.pump();

      final box = tester.renderObject<RenderBox>(
        find.byType(SkeletonEventCard),
      );
      // image (120) + top-pad (12) + title (16) + gap (8) + subtitle (12) +
      // gap (12) + meta (12) + bottom-pad (12) = 204dp minimum.
      expect(box.size.height, greaterThanOrEqualTo(160));
    });
  });
}
