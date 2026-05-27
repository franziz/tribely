/// HelpArticleScreen — static FAQ surface for the Help Centre.
///
/// This feature deliberately collapses to a single `presentation/` layer:
/// the article is hardcoded static copy with no domain logic, persistence,
/// or async behaviour, so a `domain/` or `data/` layer would be empty
/// scaffolding. Adding a second article means adding a const entry to
/// [HelpCentreCopy], NOT extracting an abstraction. The 3-layer template
/// re-applies as soon as articles become dynamic (CMS, search, favourites).
///
/// Routed via `/help/article/:id`. Currently `articleId == 'report-faq'`
/// is the only supported value; unknown ids render a "not found" fallback.
import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../string_assets/help_centre_copy.dart';

class HelpArticleScreen extends StatelessWidget {
  const HelpArticleScreen({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context) {
    final article = articleId == 'report-faq' ? HelpCentreCopy.reportFaq : null;
    if (article == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Help Centre')),
        body: const Center(child: Text('Article not found')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Help Centre')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.pageTitle,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            ...article.sections.map((s) => _ArticleSectionBlock(section: s)),
          ],
        ),
      ),
    );
  }
}

class _ArticleSectionBlock extends StatelessWidget {
  const _ArticleSectionBlock({required this.section});

  final HelpArticleSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              section.header,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: TribelyColors.paperInkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
