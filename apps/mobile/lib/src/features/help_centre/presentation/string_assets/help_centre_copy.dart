/// Verbatim Designer + legal-compliance APPROVED copy for the Help Centre.
///
/// Single source of truth for all user-visible Help Centre strings. Do not
/// duplicate; import this and reference the constants.
///
/// IMPORTANT (numerical coupling): the "72 hours" and "7 days" figures in
/// this file MUST stay aligned with the operator SLA in
/// docs/runbooks/moderation-cli.md §2 and with the sheet copy in
/// ../../../reports/presentation/string_assets/report_copy.dart. PM tracks
/// the coupling via a follow-up ticket.
abstract final class HelpCentreCopy {
  static const HelpArticle reportFaq = HelpArticle(
    pageTitle: 'What happens after I report someone?',
    sections: [
      HelpArticleSection(
        header: 'What happens after I report someone?',
        body:
            'Your report goes straight to our safety team. We read every one — reports are never ignored or automatically closed. We may also use your report to identify patterns of behaviour that affect other members of the community.\n\n'
            "We don't tell the person you reported that you filed it, and we don't share your name or account with them as part of the review.",
      ),
      HelpArticleSection(
        header: 'Who reviews it?',
        body:
            "Our safety team reviews all reports. We're a small, dedicated group — not an automated system. We look at the context of the report, the relevant messages or profile content, and any prior history before making a decision.",
      ),
      HelpArticleSection(
        header: 'How long until I hear back?',
        body:
            'We aim to review your report within 72 hours. We aim to fully resolve most reports within 7 days.\n\n'
            "If we need more information from you to complete the review, we'll contact you directly through the app.",
      ),
      HelpArticleSection(
        header: "What if I don't hear back?",
        body:
            "As above, we aim to reply within 72 hours and resolve within 7 days. If a week has passed and you haven't heard from us, please email us at support@tribely.app and include the date you submitted your report. We'll find it and get back to you.\n\n"
            'For privacy-related questions about your report (such as requesting we delete information you submitted), please contact privacy@gotribely.com.\n\n'
            "We're working on a built-in way to message support directly from the app — it will replace the email link above when it's ready.",
      ),
    ],
  );
}

class HelpArticle {
  const HelpArticle({required this.pageTitle, required this.sections});

  final String pageTitle;
  final List<HelpArticleSection> sections;
}

class HelpArticleSection {
  const HelpArticleSection({required this.header, required this.body});

  final String header;
  final String body;
}
