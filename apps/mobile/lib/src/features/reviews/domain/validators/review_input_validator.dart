/// Result of a single-field validation.
///
/// [isValid] is the primary check. [message] is a human-readable error string
/// when [isValid] is false and null otherwise.
class ValidationResult {
  const ValidationResult.valid() : isValid = true, message = null;
  const ValidationResult.invalid(String this.message) : isValid = false;

  final bool isValid;
  final String? message;
}

/// Pure validation functions for review composer input.
///
/// No Flutter, no Dio, no Riverpod. All functions are pure.
class ReviewInputValidator {
  const ReviewInputValidator._();

  static const int _minRating = 1;
  static const int _maxRating = 5;
  static const int _maxCommentLength = 500;

  /// Validates the star rating.
  ///
  /// A valid rating is an integer in [1, 5]. Zero means no selection —
  /// the submit button should be disabled, but this validator is also used
  /// for any direct integer sanity check before sending to the API.
  static ValidationResult validateRating(int? rating) {
    if (rating == null || rating < _minRating || rating > _maxRating) {
      return const ValidationResult.invalid(
        'Please select a star rating between 1 and 5.',
      );
    }
    return const ValidationResult.valid();
  }

  /// Validates the optional comment field.
  ///
  /// Null / empty is always valid (comment is optional). Non-null values
  /// exceeding 500 characters are rejected.
  static ValidationResult validateComment(String? comment) {
    if (comment == null || comment.isEmpty) {
      return const ValidationResult.valid();
    }
    if (comment.length > _maxCommentLength) {
      return ValidationResult.invalid(
        'Comments must be $_maxCommentLength characters or fewer '
        '(${comment.length} entered).',
      );
    }
    return const ValidationResult.valid();
  }
}
