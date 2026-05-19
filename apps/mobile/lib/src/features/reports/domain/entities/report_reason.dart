/// The machine-readable reason for filing a report.
///
/// Maps 1:1 with the backend enum accepted by POST /reports.
/// [displayString] provides the Designer-mandated user-facing copy for each
/// value (see report_copy.dart for the verbatim copy SoT used in the sheet).
enum ReportReason {
  harassment,
  hateSpeech,
  sexualContent,
  personalInformationDisclosure,
  falseInformation,
  spam,
  other;

  /// User-facing label for the reason picker radio list.
  String get displayString {
    switch (this) {
      case ReportReason.harassment:
        return 'Harassment or threats';
      case ReportReason.hateSpeech:
        return 'Hate speech or discrimination';
      case ReportReason.sexualContent:
        return 'Sexual content';
      case ReportReason.personalInformationDisclosure:
        return 'Sharing personal information';
      case ReportReason.falseInformation:
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
      case ReportReason.hateSpeech:
        return 'hate_speech';
      case ReportReason.sexualContent:
        return 'sexual_content';
      case ReportReason.personalInformationDisclosure:
        return 'personal_information_disclosure';
      case ReportReason.falseInformation:
        return 'false_information';
      case ReportReason.spam:
        return 'spam';
      case ReportReason.other:
        return 'other';
    }
  }
}
