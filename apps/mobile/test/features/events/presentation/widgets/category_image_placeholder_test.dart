// Widget tests for CategoryImagePlaceholder.
//
// Covers:
//   1. Renders a ColoredBox with the category's background color.
//   2. Renders the category's icon.
//   3. All 7 EventCategory values produce a widget (smoke pass).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/features/events/presentation/category_visuals.dart';
import 'package:tribely/src/features/events/presentation/widgets/category_image_placeholder.dart';

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpPlaceholder(
  WidgetTester tester,
  EventCategory category,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 200,
          child: CategoryImagePlaceholder(category: category),
        ),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CategoryImagePlaceholder', () {
    // -----------------------------------------------------------------------
    // 1. Background color matches categoryColor for each category.
    // -----------------------------------------------------------------------
    for (final category in EventCategory.values) {
      testWidgets('renders correct background color for ${category.name}', (
        tester,
      ) async {
        await _pumpPlaceholder(tester, category);

        // Find the ColoredBox and verify its color.
        final coloredBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
        expect(coloredBox.color, equals(categoryColor(category)));
      });
    }

    // -----------------------------------------------------------------------
    // 2. Icon matches categoryIcon for each category.
    // -----------------------------------------------------------------------
    for (final category in EventCategory.values) {
      testWidgets('renders correct icon for ${category.name}', (tester) async {
        await _pumpPlaceholder(tester, category);

        expect(find.byIcon(categoryIcon(category)), findsOneWidget);
      });
    }

    // -----------------------------------------------------------------------
    // 3. Smoke pass — all 7 values render without error.
    // -----------------------------------------------------------------------
    testWidgets('renders all 7 EventCategory values without error', (
      tester,
    ) async {
      for (final category in EventCategory.values) {
        await _pumpPlaceholder(tester, category);
        expect(find.byType(CategoryImagePlaceholder), findsOneWidget);
      }
    });

    // -----------------------------------------------------------------------
    // 4. Verify distinct colors — each category has a unique color.
    // -----------------------------------------------------------------------
    test('all 7 categories produce distinct colors', () {
      final colors = EventCategory.values.map(categoryColor).toList();
      final uniqueColors = colors.toSet();
      expect(uniqueColors.length, equals(EventCategory.values.length));
    });
  });
}
