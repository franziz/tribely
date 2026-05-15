// Widget tests for VenueTypeChip.
//
// Covers:
//   1. Renders label text.
//   2. Selected chip has check icon — verifies via background-color change
//      (AnimatedContainer) is not directly testable; we test via semantics
//      and the [isSelected] property.
//   3. Unselected chip has no selection indicator.
//   4. Tapping calls the onTap callback.
//   5. Semantics label contains "selected" / "not selected" appropriately.
//
// Golden tests are skipped on Linux (macOS-baseline golden files would cause
// ~1–2% pixel-diff failures due to FreeType font hinting on CI).

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/events/presentation/widgets/venue_type_chip.dart';

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

Future<void> _pumpChip(
  WidgetTester tester, {
  required String value,
  required String label,
  required bool isSelected,
  required VoidCallback onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: VenueTypeChip(
            value: value,
            label: label,
            isSelected: isSelected,
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('VenueTypeChip', () {
    // -------------------------------------------------------------------------
    // 1. Renders label text
    // -------------------------------------------------------------------------
    testWidgets('renders the label text', (tester) async {
      await _pumpChip(
        tester,
        value: 'cafe',
        label: 'Cafe',
        isSelected: false,
        onTap: () {},
      );

      expect(find.text('Cafe'), findsOneWidget);
    });

    testWidgets('renders label text for multi-word labels', (tester) async {
      await _pumpChip(
        tester,
        value: 'hawker_centre',
        label: 'Hawker centre',
        isSelected: false,
        onTap: () {},
      );

      expect(find.text('Hawker centre'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. Tap callback fires
    // -------------------------------------------------------------------------
    testWidgets('tapping the chip calls onTap', (tester) async {
      var tapped = false;

      await _pumpChip(
        tester,
        value: 'park',
        label: 'Park',
        isSelected: false,
        onTap: () => tapped = true,
      );

      await tester.tap(find.byType(VenueTypeChip));
      expect(tapped, isTrue);
    });

    testWidgets('tapping the selected chip also calls onTap', (tester) async {
      var tapped = false;

      await _pumpChip(
        tester,
        value: 'cafe',
        label: 'Cafe',
        isSelected: true,
        onTap: () => tapped = true,
      );

      await tester.tap(find.byType(VenueTypeChip));
      expect(tapped, isTrue);
    });

    // -------------------------------------------------------------------------
    // 3. Semantics — selected state
    // -------------------------------------------------------------------------
    testWidgets(
      'selected chip has semantics label containing "selected"',
      (tester) async {
        await _pumpChip(
          tester,
          value: 'cafe',
          label: 'Cafe',
          isSelected: true,
          onTap: () {},
        );

        expect(
          find.bySemanticsLabel(RegExp('Cafe venue type.*selected')),
          findsOneWidget,
          reason: 'Selected chip must have "selected" in its semantics label',
        );
      },
    );

    testWidgets(
      'unselected chip has semantics label containing "not selected"',
      (tester) async {
        await _pumpChip(
          tester,
          value: 'park',
          label: 'Park',
          isSelected: false,
          onTap: () {},
        );

        expect(
          find.bySemanticsLabel(RegExp('Park venue type.*not selected')),
          findsOneWidget,
          reason:
              'Unselected chip must have "not selected" in its semantics label',
        );
      },
    );

    // -------------------------------------------------------------------------
    // 4. Tap target height ≥ 44pt
    // -------------------------------------------------------------------------
    testWidgets('chip render height is at least 44pt', (tester) async {
      await _pumpChip(
        tester,
        value: 'cafe',
        label: 'Cafe',
        isSelected: false,
        onTap: () {},
      );

      final size = tester.getSize(find.byType(VenueTypeChip));
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason: 'Tap target must be at least 44pt tall (WCAG 2.5.5)',
      );
    });

    // -------------------------------------------------------------------------
    // 5. Golden — skipped on Linux (macOS-baseline)
    // -------------------------------------------------------------------------
    testWidgets(
      'VenueTypeChip — unselected golden',
      skip: Platform.isLinux,
      (tester) async {
        await _pumpChip(
          tester,
          value: 'cafe',
          label: 'Cafe',
          isSelected: false,
          onTap: () {},
        );

        await expectLater(
          find.byType(VenueTypeChip),
          matchesGoldenFile('goldens/venue_type_chip_unselected.png'),
        );
      },
    );

    testWidgets(
      'VenueTypeChip — selected golden',
      skip: Platform.isLinux,
      (tester) async {
        await _pumpChip(
          tester,
          value: 'cafe',
          label: 'Cafe',
          isSelected: true,
          onTap: () {},
        );

        await expectLater(
          find.byType(VenueTypeChip),
          matchesGoldenFile('goldens/venue_type_chip_selected.png'),
        );
      },
    );
  });
}
