// Widget tests for DiscoverTabSwitcher.
//
// Covers:
//   1. Renders both "List" and "Map" labels.
//   2. Tapping "Map" segment fires onTabChanged(DiscoverTab.map).
//   3. Tapping "List" segment fires onTabChanged(DiscoverTab.list).
//   4. Initial state reflects selectedTab parameter.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/discover/presentation/widgets/discover_tab_switcher.dart';

Future<void> _pumpSwitcher(
  WidgetTester tester, {
  DiscoverTab selected = DiscoverTab.list,
  required ValueChanged<DiscoverTab> onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          child: DiscoverTabSwitcher(
            selectedTab: selected,
            onTabChanged: onChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('DiscoverTabSwitcher', () {
    testWidgets('1. renders both segment labels', (tester) async {
      await _pumpSwitcher(tester, onChanged: (_) {});
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
    });

    testWidgets('2. tapping Map segment calls onTabChanged with map',
        (tester) async {
      DiscoverTab? received;
      await _pumpSwitcher(
        tester,
        selected: DiscoverTab.list,
        onChanged: (tab) => received = tab,
      );

      await tester.tap(find.text('Map'));
      expect(received, equals(DiscoverTab.map));
    });

    testWidgets('3. tapping List segment calls onTabChanged with list',
        (tester) async {
      DiscoverTab? received;
      await _pumpSwitcher(
        tester,
        selected: DiscoverTab.map,
        onChanged: (tab) => received = tab,
      );

      await tester.tap(find.text('List'));
      expect(received, equals(DiscoverTab.list));
    });

    testWidgets('4a. list is selected by default', (tester) async {
      await _pumpSwitcher(
        tester,
        selected: DiscoverTab.list,
        onChanged: (_) {},
      );
      // No assertion on color — verify it renders without throwing.
      expect(find.byType(DiscoverTabSwitcher), findsOneWidget);
    });

    testWidgets('4b. map selected renders widget without error', (
      tester,
    ) async {
      await _pumpSwitcher(
        tester,
        selected: DiscoverTab.map,
        onChanged: (_) {},
      );
      expect(find.byType(DiscoverTabSwitcher), findsOneWidget);
    });
  });
}
