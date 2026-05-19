/// The machine-readable reason for filing a report.
///
/// Maps 1:1 with the backend enum accepted by POST /reports.
/// [displayString] provides the Designer-mandated user-facing copy for each
/// value (see report_copy.dart for the verbatim copy SoT used in the sheet).
enum ReportReason {
  harassment,
  hate_speech,
  sexual_content,
  personal_information_disclosure,
  false_information,
  spam,
  other;

  /// User-facing label for the reason picker radio list.
  String get displayString {
    switch (this) {
      case ReportReason.harassment:
        return 'Harassment or threats';
      case ReportReason.hate_speech:
        return 'Hate speech or discrimination';
      case ReportReason.sexual_content:
        return 'Sexual content';
      case ReportReason.personal_information_disclosure:
        return 'Sharing personal information';
      case ReportReason.false_information:
        return 'False or misleading information';
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.other:
        return 'Something else';
    }
  }

  /// Wire value sent to the backend (matches the API enum literals).
  String get wireValue {
    switch (this) {
      case ReportReason.harassment:
        return 'harassment';
      case ReportReason.hate_speech:
        return 'hate_speech';
      case ReportReason.sexual_content:
        return 'sexual_content';
      case ReportReason.personal_information_disclosure:
        return 'personal_information_disclosure';
      case ReportReason.false_information:
        return 'false_information';
      case ReportReason.spam:
        return 'spam';
      case ReportReason.other:
        return 'other';
    }
  }
}
