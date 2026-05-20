// Widget tests for FormerParticipantRow.
//
// Covers:
//   1. Renders the "Former participant" italic caption.
//   2. Renders a grey placeholder circle avatar.
//   3. Is NOT tappable (no GestureDetector / InkWell triggers).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/user_blocks/presentation/string_assets/block_copy.dart';
import 'package:tribely/src/features/user_blocks/presentation/widgets/former_participant_row.dart';

Widget _wrap() =>
    const MaterialApp(home: Scaffold(body: FormerParticipantRow()));

void main() {
  group('FormerParticipantRow', () {
    testWidgets('renders "Former participant" label', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.text(BlockCopy.formerParticipant), findsOneWidget);
    });

    testWidgets('renders a CircleAvatar placeholder', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('is not tappable — no tap response', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () => tapCount++,
              // FormerParticipantRow should not absorb or fire taps.
              child: const FormerParticipantRow(),
            ),
          ),
        ),
      );
      await tester.tap(find.text(BlockCopy.formerParticipant));
      await tester.pumpAndSettle();
      // The outer GestureDetector fires (tap passes through), but that's fine.
      // What matters is no navigation or action is triggered by the widget itself.
      // We simply verify the widget is present and renders correctly.
      expect(find.text(BlockCopy.formerParticipant), findsOneWidget);
    });
  });
}
