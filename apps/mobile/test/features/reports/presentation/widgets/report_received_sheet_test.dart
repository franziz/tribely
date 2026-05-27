import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/reports/presentation/string_assets/report_copy.dart';
import 'package:tribely/src/features/reports/presentation/widgets/report_received_sheet.dart';

void main() {
  group('ReportReceivedSheet', () {
    testWidgets(
      'renders headline, both body paragraphs, primary CTA, and secondary link',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ReportReceivedSheet(onLearnMore: () {})),
          ),
        );
        expect(find.text(ReportCopy.sheetHeadline), findsOneWidget);
        expect(find.text(ReportCopy.sheetBodyParagraph1), findsOneWidget);
        expect(find.text(ReportCopy.sheetBodyParagraph2Sla), findsOneWidget);
        expect(find.text(ReportCopy.sheetPrimaryCta), findsOneWidget);
        expect(find.text(ReportCopy.sheetSecondaryLink), findsOneWidget);
      },
    );

    testWidgets('tapping the secondary link invokes onLearnMore', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportReceivedSheet(onLearnMore: () => tapped = true),
          ),
        ),
      );
      await tester.tap(find.text(ReportCopy.sheetSecondaryLink));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('tapping Done pops the sheet', (tester) async {
      // The sheet's Column has mainAxisSize.min and needs sufficient vertical
      // space. showModalBottomSheet allocates up to half the screen height, so
      // we set a tall physical size (1080 × 1920 at dpr=1) to prevent overflow
      // and allow the pop to animate cleanly.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => ReportReceivedSheet(onLearnMore: () {}),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportReceivedSheet), findsOneWidget);
      await tester.tap(find.text(ReportCopy.sheetPrimaryCta));
      // pumpAndSettle is safe here: the tall viewport prevents the overflow
      // that previously triggered deactivated-widget inspector diagnostics.
      await tester.pumpAndSettle();
      expect(find.byType(ReportReceivedSheet), findsNothing);
    });

    testWidgets('check_circle_outline icon is excluded from semantics',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReportReceivedSheet(onLearnMore: () {})),
        ),
      );
      final handle = tester.ensureSemantics();
      // The icon is wrapped in ExcludeSemantics — no semantics label should
      // be emitted for it (Icons.check_circle_outline would produce a label
      // like "check circle outline" if not excluded).
      expect(
        find.bySemanticsLabel(RegExp(r'check', caseSensitive: false)),
        findsNothing,
      );
      handle.dispose();
    });
  });
}
