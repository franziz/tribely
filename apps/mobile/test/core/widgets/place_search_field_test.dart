import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/widgets/place_search_field.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('PlaceSearchField', () {
    testWidgets('shows placeholder "Search venues in Singapore"', (
      tester,
    ) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        _wrap(
          PlaceSearchField(
            controller: ctrl,
            onChanged: (_) {},
            onCleared: () {},
          ),
        ),
      );

      expect(find.text('Search venues in Singapore'), findsOneWidget);
    });

    testWidgets('typing into the field triggers onChanged with typed string', (
      tester,
    ) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      final changes = <String>[];

      await tester.pumpWidget(
        _wrap(
          PlaceSearchField(
            controller: ctrl,
            onChanged: changes.add,
            onCleared: () {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Marina Bay');
      await tester.pump();

      expect(changes, contains('Marina Bay'));
    });

    testWidgets('clear-X button is hidden when controller text is empty', (
      tester,
    ) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        _wrap(
          PlaceSearchField(
            controller: ctrl,
            onChanged: (_) {},
            onCleared: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('clear-X button is visible when controller text is non-empty', (
      tester,
    ) async {
      final ctrl = TextEditingController(text: 'Orchard');
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        _wrap(
          PlaceSearchField(
            controller: ctrl,
            onChanged: (_) {},
            onCleared: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets(
      'clear-X button becomes visible after typing into an initially empty field',
      (tester) async {
        final ctrl = TextEditingController();
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          _wrap(
            PlaceSearchField(
              controller: ctrl,
              onChanged: (_) {},
              onCleared: () {},
            ),
          ),
        );

        expect(find.byIcon(Icons.close), findsNothing);

        await tester.enterText(find.byType(TextField), 'Bugis');
        await tester.pump();

        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );

    testWidgets('tapping clear-X triggers onCleared', (tester) async {
      final ctrl = TextEditingController(text: 'Orchard');
      addTearDown(ctrl.dispose);
      var cleared = false;

      await tester.pumpWidget(
        _wrap(
          PlaceSearchField(
            controller: ctrl,
            onChanged: (_) {},
            onCleared: () => cleared = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(cleared, isTrue);
    });

    testWidgets(
      'enabled=false makes the field non-editable (typing has no effect)',
      (tester) async {
        final ctrl = TextEditingController();
        addTearDown(ctrl.dispose);
        final changes = <String>[];

        await tester.pumpWidget(
          _wrap(
            PlaceSearchField(
              controller: ctrl,
              onChanged: changes.add,
              onCleared: () {},
              enabled: false,
            ),
          ),
        );

        // Attempt to type — disabled TextField ignores input.
        await tester.enterText(find.byType(TextField), 'Sentosa');
        await tester.pump();

        // The controller text should remain empty.
        expect(ctrl.text, isEmpty);
        expect(changes, isEmpty);
      },
    );
  });
}
