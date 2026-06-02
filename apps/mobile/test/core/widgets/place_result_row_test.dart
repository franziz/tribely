import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/widgets/place_result_row.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('PlaceResultRow', () {
    testWidgets('renders name text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlaceResultRow(
            name: 'Gardens by the Bay',
            placeFormatted: '18 Marina Gardens Dr, Singapore 018953',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Gardens by the Bay'), findsOneWidget);
    });

    testWidgets('renders placeFormatted text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlaceResultRow(
            name: 'Gardens by the Bay',
            placeFormatted: '18 Marina Gardens Dr, Singapore 018953',
            onTap: () {},
          ),
        ),
      );

      expect(
        find.text('18 Marina Gardens Dr, Singapore 018953'),
        findsOneWidget,
      );
    });

    testWidgets('tapping the row triggers onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          PlaceResultRow(
            name: 'Orchard Road',
            placeFormatted: 'Orchard, Singapore',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(PlaceResultRow));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('default leading icon (Icons.place_outlined) renders when leading is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlaceResultRow(
            name: 'Sentosa',
            placeFormatted: 'Sentosa Island, Singapore',
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    });

    testWidgets('custom leading widget renders instead of default icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlaceResultRow(
            name: 'Sentosa',
            placeFormatted: 'Sentosa Island, Singapore',
            onTap: () {},
            leading: const Icon(Icons.star, key: Key('custom-leading')),
          ),
        ),
      );

      expect(find.byKey(const Key('custom-leading')), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsNothing);
    });

    testWidgets('row minimum height is at least 64dp', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlaceResultRow(
            name: 'Bugis',
            placeFormatted: 'Bugis, Singapore',
            onTap: () {},
          ),
        ),
      );

      final renderBox = tester.renderObject<RenderBox>(
        find.byType(PlaceResultRow),
      );
      expect(renderBox.size.height, greaterThanOrEqualTo(64));
    });
  });
}
