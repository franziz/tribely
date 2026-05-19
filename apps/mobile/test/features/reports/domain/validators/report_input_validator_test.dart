import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/reports/domain/entities/report_reason.dart';
import 'package:tribely/src/features/reports/domain/validators/report_input_validator.dart';

void main() {
  group('ReportInputValidator.validateReason', () {
    test('null reason is invalid', () {
      final result = ReportInputValidator.validateReason(null);
      expect(result.isValid, isFalse);
      expect(result.message, isNotNull);
    });

    for (final reason in ReportReason.values) {
      test('${reason.name} is valid', () {
        final result = ReportInputValidator.validateReason(reason);
        expect(result.isValid, isTrue);
        expect(result.message, isNull);
      });
    }
  });

  group('ReportInputValidator.validateComment', () {
    test('null comment is valid (optional)', () {
      final result = ReportInputValidator.validateComment(null);
      expect(result.isValid, isTrue);
    });

    test('empty string is valid (optional)', () {
      final result = ReportInputValidator.validateComment('');
      expect(result.isValid, isTrue);
    });

    test('500-char comment is valid (at limit)', () {
      final comment = 'a' * 500;
      expect(ReportInputValidator.validateComment(comment).isValid, isTrue);
    });

    test('501-char comment is invalid (over limit)', () {
      final comment = 'a' * 501;
      final result = ReportInputValidator.validateComment(comment);
      expect(result.isValid, isFalse);
      expect(result.message, isNotNull);
      expect(result.message, contains('500'));
    });

    test('normal comment is valid', () {
      expect(
        ReportInputValidator.validateComment('This review seemed fake.').isValid,
        isTrue,
      );
    });
  });

  group('ReportReason.displayString', () {
    test('each reason has a non-empty display string', () {
      for (final reason in ReportReason.values) {
        expect(reason.displayString, isNotEmpty);
      }
    });

    test('harassment maps to correct copy', () {
      expect(ReportReason.harassment.displayString, 'Harassment or threats');
    });

    test('hate_speech maps to correct copy', () {
      expect(
        ReportReason.hate_speech.displayString,
        'Hate speech or discrimination',
      );
    });

    test('sexual_content maps to correct copy', () {
      expect(ReportReason.sexual_content.displayString, 'Sexual content');
    });

    test('personal_information_disclosure maps to correct copy', () {
      expect(
        ReportReason.personal_information_disclosure.displayString,
        'Sharing personal information',
      );
    });

    test('false_information maps to correct copy', () {
      expect(
        ReportReason.false_information.displayString,
        'False or misleading information',
      );
    });

    test('spam maps to correct copy', () {
      expect(ReportReason.spam.displayString, 'Spam');
    });

    test('other maps to correct copy', () {
      expect(ReportReason.other.displayString, 'Something else');
    });
  });
}
