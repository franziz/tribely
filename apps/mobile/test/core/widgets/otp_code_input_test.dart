import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/design/colors.dart';
import 'package:tribely/src/core/widgets/otp_code_input.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('OtpCodeInput — input behavior', () {
    testWidgets('paste of 123456 fires onCompleted exactly once', (
      tester,
    ) async {
      final completions = <String>[];

      await tester.pumpWidget(
        _wrap(OtpCodeInput(onCompleted: completions.add)),
      );

      // Focus the hidden field by tapping the widget.
      await tester.tap(find.byType(OtpCodeInput));
      await tester.pump();

      // Enter digits one by one to simulate paste via enterText.
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '123456');
      await tester.pump();

      expect(completions, hasLength(1));
      expect(completions.first, '123456');
    });

    testWidgets('onCompleted fires exactly once even when length stays at 6', (
      tester,
    ) async {
      final completions = <String>[];
      late TextEditingController ctrl;

      await tester.pumpWidget(
        _wrap(OtpCodeInput(onCompleted: completions.add)),
      );

      final textField = find.byType(TextField).first;
      await tester.tap(find.byType(OtpCodeInput));
      await tester.pump();

      await tester.enterText(textField, '123456');
      await tester.pump();

      // Simulate a second setText to the same 6-char value.
      // onCompleted should NOT fire again since length didn't reset below 6.
      ctrl = tester.widget<TextField>(textField).controller!;
      ctrl.text = '654321';
      await tester.pump();

      // Still only one completion because _completedFired was still true.
      expect(completions, hasLength(1));
    });

    testWidgets('non-digit characters are rejected by the formatter', (
      tester,
    ) async {
      final changes = <String>[];

      await tester.pumpWidget(
        _wrap(OtpCodeInput(onCompleted: (_) {}, onChanged: changes.add)),
      );

      final textField = find.byType(TextField).first;
      await tester.tap(find.byType(OtpCodeInput));
      await tester.pump();

      await tester.enterText(textField, 'abc123');
      await tester.pump();

      // Only the digits should survive the FilteringTextInputFormatter.
      expect(changes.last, '123');
    });

    testWidgets('backspace clears the last filled box', (tester) async {
      final changes = <String>[];

      await tester.pumpWidget(
        _wrap(OtpCodeInput(onCompleted: (_) {}, onChanged: changes.add)),
      );

      final textField = find.byType(TextField).first;
      await tester.tap(find.byType(OtpCodeInput));
      await tester.pump();

      // Type 3 digits.
      await tester.enterText(textField, '123');
      await tester.pump();
      expect(changes.last, '123');

      // Simulate backspace by trimming the last character.
      final ctrl = tester.widget<TextField>(textField).controller!;
      ctrl.text = '12';
      await tester.pump();

      expect(changes.last, '12');
    });
  });

  group('OtpCodeInput — error state', () {
    testWidgets(
      'errorState:true renders all 6 boxes with accent border color',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const OtpCodeInput(onCompleted: _noop, errorState: true)),
        );
        await tester.pump();

        // All 6 _OtpBox containers should have the accent border.
        final containers = tester.widgetList<Container>(find.byType(Container));
        final accentBorderCount = containers.where((c) {
          final deco = c.decoration;
          if (deco is! BoxDecoration) return false;
          final border = deco.border;
          if (border is! Border) return false;
          return border.top.color == TribelyColors.paperAccent;
        }).length;

        expect(accentBorderCount, greaterThanOrEqualTo(6));
      },
    );

    testWidgets(
      'errorState:false (default) does NOT use accent border when empty',
      (tester) async {
        await tester.pumpWidget(_wrap(const OtpCodeInput(onCompleted: _noop)));
        await tester.pump();

        final containers = tester.widgetList<Container>(find.byType(Container));
        final accentBorderCount = containers.where((c) {
          final deco = c.decoration;
          if (deco is! BoxDecoration) return false;
          final border = deco.border;
          if (border is! Border) return false;
          return border.top.color == TribelyColors.paperAccent;
        }).length;

        expect(accentBorderCount, 0);
      },
    );
  });

  group('OtpCodeInput — semantics', () {
    testWidgets('exposes "6-digit verification code" semantics label', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const OtpCodeInput(onCompleted: _noop)));
      await tester.pump();

      expect(
        find.bySemanticsLabel('6-digit verification code'),
        findsOneWidget,
      );
    });
  });
}

void _noop(String _) {}
