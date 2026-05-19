// Widget tests for BlockOptInSheet.
//
// Covers:
//   1. Both buttons render ("Block [name]" and "Not now").
//   2. "Block [name]" tap calls [onBlockTap] callback.
//   3. "Not now" tap dismisses the sheet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/reports/presentation/widgets/block_opt_in_sheet.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _wrap({required String displayName, VoidCallback? onBlockTap}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => BlockOptInSheet(
                reportedUserId: 'user-b',
                reportedUserDisplayName: displayName,
                onBlockTap: onBlockTap,
              ),
            );
          },
          child: const Text('Open sheet'),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open sheet'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BlockOptInSheet — renders both buttons', () {
    testWidgets('shows "Block [name]" and "Not now" buttons', (tester) async {
      await tester.pumpWidget(_wrap(displayName: 'Alex'));
      await _openSheet(tester);

      expect(find.text('Block Alex'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('button label includes the display name', (tester) async {
      await tester.pumpWidget(_wrap(displayName: 'Jordan'));
      await _openSheet(tester);

      expect(find.text('Block Jordan'), findsOneWidget);
    });
  });

  group('BlockOptInSheet — Block button calls callback', () {
    testWidgets('tapping "Block [name]" invokes onBlockTap', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        _wrap(displayName: 'Alex', onBlockTap: () => callCount++),
      );
      await _openSheet(tester);

      await tester.tap(find.text('Block Alex'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });
  });

  group('BlockOptInSheet — Not now dismisses', () {
    testWidgets('"Not now" dismisses the sheet', (tester) async {
      await tester.pumpWidget(_wrap(displayName: 'Alex'));
      await _openSheet(tester);

      expect(find.text('Block Alex'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // After dismiss, the sheet content is gone.
      expect(find.text('Block Alex'), findsNothing);
    });
  });
}
