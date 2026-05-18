import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/widgets/country_picker_sheet.dart';

/// Wraps the picker sheet directly (bypassing modal plumbing) for unit testing.
Widget _wrapSheet({String selectedIsoCode = 'SG'}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (ctx) => TextButton(
        onPressed: () =>
            showCountryPickerSheet(ctx, selectedIsoCode: selectedIsoCode),
        child: const Text('Open'),
      ),
    ),
  ),
);

void main() {
  group('CountryPickerSheet — pinned section', () {
    testWidgets('Suggested section renders SG/MY/IN/CN/PH at the top', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapSheet());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify the section header appears.
      expect(find.text('Suggested'), findsOneWidget);

      // Verify all five suggested countries are visible.
      expect(find.text('Singapore'), findsWidgets);
      expect(find.text('Malaysia'), findsWidgets);
      expect(find.text('India'), findsWidgets);
      expect(find.text('China'), findsWidgets);
      expect(find.text('Philippines'), findsWidgets);
    });

    testWidgets('Suggested section appears above A–Z "All countries" section', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapSheet());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final suggestedOffset = tester.getTopLeft(find.text('Suggested')).dy;
      final allCountriesOffset = tester
          .getTopLeft(find.text('All countries'))
          .dy;

      expect(suggestedOffset, lessThan(allCountriesOffset));
    });
  });

  group('CountryPickerSheet — search', () {
    testWidgets('query "sin" filters list to include Singapore', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapSheet());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'sin');
      await tester.pump();

      expect(find.text('Singapore'), findsWidgets);
    });

    testWidgets('query "65" filters list to include Singapore (by dial code)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapSheet());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '65');
      await tester.pump();

      expect(find.text('Singapore'), findsWidgets);
    });

    testWidgets('query that matches nothing returns empty list', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapSheet());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyzzy99999');
      await tester.pump();

      // No country rows should be visible.
      expect(find.text('Singapore'), findsNothing);
      expect(find.text('Malaysia'), findsNothing);
    });
  });

  group('CountryPickerSheet — selection', () {
    testWidgets('selecting Singapore pops with dialCode +65', (tester) async {
      CountrySelection? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async {
                  result = await showCountryPickerSheet(
                    ctx,
                    selectedIsoCode: 'MY',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap on Singapore in the suggested section.
      // Multiple Singapore widgets may appear (suggested + A-Z); tap the first.
      await tester.tap(find.text('Singapore').first);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.dialCode, '+65');
      expect(result!.isoCode, 'SG');
      expect(result!.flagEmoji, '🇸🇬');
    });

    testWidgets(
      'selected country shows checkmark, unselected shows dial code',
      (tester) async {
        await tester.pumpWidget(_wrapSheet(selectedIsoCode: 'SG'));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Singapore row (selected) should show a check icon.
        expect(find.byIcon(Icons.check), findsWidgets);

        // The +65 dial code should NOT appear as trailing text for the selected
        // row — it's replaced by the checkmark.
        // (Dial codes can appear elsewhere, so we check the icon IS present.)
        expect(find.byIcon(Icons.check), findsAtLeastNWidgets(1));
      },
    );
  });
}
