import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/reviews/domain/validators/review_input_validator.dart';

void main() {
  group('ReviewInputValidator.validateRating', () {
    test('null rating is invalid', () {
      final result = ReviewInputValidator.validateRating(null);
      expect(result.isValid, isFalse);
      expect(result.message, isNotNull);
    });

    test('0 is invalid (below minimum)', () {
      expect(ReviewInputValidator.validateRating(0).isValid, isFalse);
    });

    test('6 is invalid (above maximum)', () {
      expect(ReviewInputValidator.validateRating(6).isValid, isFalse);
    });

    test('1 is valid (minimum)', () {
      expect(ReviewInputValidator.validateRating(1).isValid, isTrue);
    });

    test('5 is valid (maximum)', () {
      expect(ReviewInputValidator.validateRating(5).isValid, isTrue);
    });

    for (final rating in [1, 2, 3, 4, 5]) {
      test('rating $rating is valid', () {
        expect(ReviewInputValidator.validateRating(rating).isValid, isTrue);
        expect(ReviewInputValidator.validateRating(rating).message, isNull);
      });
    }
  });

  group('ReviewInputValidator.validateComment', () {
    test('null comment is valid (optional)', () {
      final result = ReviewInputValidator.validateComment(null);
      expect(result.isValid, isTrue);
    });

    test('empty string is valid (optional)', () {
      final result = ReviewInputValidator.validateComment('');
      expect(result.isValid, isTrue);
    });

    test('500-char comment is valid (at limit)', () {
      final comment = 'a' * 500;
      expect(ReviewInputValidator.validateComment(comment).isValid, isTrue);
    });

    test('501-char comment is invalid (over limit)', () {
      final comment = 'a' * 501;
      final result = ReviewInputValidator.validateComment(comment);
      expect(result.isValid, isFalse);
      expect(result.message, isNotNull);
    });

    test('normal comment is valid', () {
      expect(
        ReviewInputValidator.validateComment('Great event!').isValid,
        isTrue,
      );
    });
  });
}
