import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/help_centre/presentation/pages/help_article_page.dart';
import 'package:tribely/src/features/help_centre/presentation/string_assets/help_centre_copy.dart';

void main() {
  group('HelpArticleScreen', () {
    testWidgets(
      'articleId == report-faq renders page title and all 4 sections (headers + bodies)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: HelpArticleScreen(articleId: 'report-faq')),
        );
        // The page title and the first section header share identical text
        // ("What happens after I report someone?") — expect at least one
        // occurrence of the page title string rather than exactly one.
        expect(
          find.text(HelpCentreCopy.reportFaq.pageTitle),
          findsAtLeastNWidgets(1),
        );
        for (final s in HelpCentreCopy.reportFaq.sections) {
          expect(find.text(s.header), findsAtLeastNWidgets(1));
          expect(find.text(s.body), findsOneWidget);
        }
        expect(HelpCentreCopy.reportFaq.sections.length, 4);
      },
    );

    testWidgets('unknown articleId renders not-found fallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HelpArticleScreen(articleId: 'does-not-exist')),
      );
      expect(find.text('Article not found'), findsOneWidget);
    });

    testWidgets('section headers carry Semantics(header: true)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HelpArticleScreen(articleId: 'report-faq')),
      );
      // Collect all Semantics(header: true) widgets. This includes the AppBar
      // title which Flutter marks as a header automatically — so we can't assert
      // an exact count equal to sections.length. Instead verify each section
      // header string is the direct text child of at least one such widget.
      final headerSemanticsWidgets = tester.widgetList<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.header == true,
        ),
      ).toList();

      for (final s in HelpCentreCopy.reportFaq.sections) {
        final matchingSemantics = headerSemanticsWidgets.where((widget) {
          // The section Semantics widget's child is a Text widget with the header text.
          final child = widget.child;
          return child is Text && child.data == s.header;
        });
        expect(
          matchingSemantics.isNotEmpty,
          isTrue,
          reason:
              'Section header "${s.header}" should be a direct child of Semantics(header: true)',
        );
      }
    });
  });
}
