// Tests for UserModel — the data-layer model for the authenticated user.
//
// Key invariant under review: `selfieLastFailureCategory` is held as a raw
// `String?` wire-type on the model; conversion to the typed
// [SelfieFailureCategory] enum occurs in [UserModel.toEntity], which is the
// intended data/domain conversion seam.

import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/auth/data/models/user_model.dart';
import 'package:tribely/src/features/users/domain/value_objects/selfie_failure_category.dart';

void main() {
  final baseDate = DateTime.utc(2026, 5, 19);
  final laterDate = DateTime.utc(2026, 5, 26);

  // Minimal valid JSON map — callers extend this for specific test cases.
  Map<String, dynamic> baseJson({
    String? selfieLastFailureCategory,
    String? selfieAppealLockedAt,
    String selfieStatus = 'notStarted',
    int selfieAttemptCount = 0,
  }) => {
    'id': 'usr-1',
    'email': 'test@example.com',
    'displayName': 'Test User',
    'createdAt': baseDate.toIso8601String(),
    'updatedAt': baseDate.toIso8601String(),
    'selfie_last_failure_category': selfieLastFailureCategory,
    'selfie_appeal_locked_at': selfieAppealLockedAt,
    'selfie_status': selfieStatus,
    'selfie_attempt_count': selfieAttemptCount,
  };

  group('UserModel.fromJson', () {
    test('holds selfie_last_failure_category as raw String', () {
      final model = UserModel.fromJson(
        baseJson(selfieLastFailureCategory: 'poor_lighting'),
      );

      expect(model.selfieLastFailureCategory, 'poor_lighting');
    });

    test('selfie_last_failure_category null in JSON → null on model', () {
      final model = UserModel.fromJson(baseJson());

      expect(model.selfieLastFailureCategory, isNull);
    });

    test('preserves unrecognised string without throwing', () {
      final model = UserModel.fromJson(
        baseJson(selfieLastFailureCategory: 'future_unknown_category'),
      );

      // Model stores wire-type; no parse happens here.
      expect(model.selfieLastFailureCategory, 'future_unknown_category');
    });
  });

  group('UserModel.toEntity — selfieLastFailureCategory conversion', () {
    test('poor_lighting → SelfieFailureCategory.poorLighting', () {
      final model = UserModel.fromJson(
        baseJson(selfieLastFailureCategory: 'poor_lighting'),
      );

      expect(
        model.toEntity().selfieLastFailureCategory,
        SelfieFailureCategory.poorLighting,
      );
    });

    test('face_not_visible → SelfieFailureCategory.faceNotVisible', () {
      final model = UserModel.fromJson(
        baseJson(selfieLastFailureCategory: 'face_not_visible'),
      );

      expect(
        model.toEntity().selfieLastFailureCategory,
        SelfieFailureCategory.faceNotVisible,
      );
    });

    test('quality_too_low → SelfieFailureCategory.qualityTooLow', () {
      final model = UserModel.fromJson(
        baseJson(selfieLastFailureCategory: 'quality_too_low'),
      );

      expect(
        model.toEntity().selfieLastFailureCategory,
        SelfieFailureCategory.qualityTooLow,
      );
    });

    test('other → SelfieFailureCategory.other', () {
      final model = UserModel.fromJson(
        baseJson(selfieLastFailureCategory: 'other'),
      );

      expect(
        model.toEntity().selfieLastFailureCategory,
        SelfieFailureCategory.other,
      );
    });

    test('null category → null on entity', () {
      final model = UserModel.fromJson(baseJson());

      expect(model.toEntity().selfieLastFailureCategory, isNull);
    });

    test('unrecognised string → null (lenient fromJson contract)', () {
      // SelfieFailureCategory.fromJson returns null for unknown strings.
      final model = UserModel.fromJson(
        baseJson(selfieLastFailureCategory: 'future_unknown_category'),
      );

      expect(model.toEntity().selfieLastFailureCategory, isNull);
    });
  });

  group('UserModel.toEntity — full round-trip', () {
    test('all fields map correctly to User entity', () {
      final model = UserModel.fromJson({
        'id': 'usr-42',
        'email': 'alice@example.com',
        'displayName': 'Alice',
        'createdAt': baseDate.toIso8601String(),
        'updatedAt': baseDate.toIso8601String(),
        'emailVerifiedAt': baseDate.toIso8601String(),
        'selfie_status': 'rejected',
        'selfie_attempt_count': 3,
        'selfie_last_failure_category': 'face_not_visible',
        'selfie_appeal_locked_at': laterDate.toIso8601String(),
      });

      final entity = model.toEntity();

      expect(entity.id, 'usr-42');
      expect(entity.email, 'alice@example.com');
      expect(entity.displayName, 'Alice');
      expect(entity.selfieStatus, 'rejected');
      expect(entity.selfieAttemptCount, 3);
      expect(
        entity.selfieLastFailureCategory,
        SelfieFailureCategory.faceNotVisible,
      );
      expect(entity.selfieAppealLockedAt, laterDate);
    });
  });
}
