import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/events/domain/services/private_venue_policy.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Public categories — all 12 should return not-private with a clean name.
  // ---------------------------------------------------------------------------
  group('public categories + clean name → not private', () {
    const publicCategories = [
      'hawker_centre',
      'park',
      'museum',
      'restaurant',
      'bar',
      'cafe',
      'beach',
      'mrt_landmark',
      'library',
      'community_centre',
      'shopping_mall_common_area',
      'tourist_attraction',
    ];

    for (final category in publicCategories) {
      test('$category → not private', () {
        final result = detectPrivateVenue(
          categoryValue: category,
          venueName: 'Lau Pa Sat',
        );
        expect(result.isPrivate, isFalse);
        expect(result.reason, isNull);
        expect(result.matchedKeyword, isNull);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Private categories — all 6 should return categoryNotPublic.
  // ---------------------------------------------------------------------------
  group('private categories + clean name → categoryNotPublic', () {
    const privateCategories = [
      'apartment',
      'condo',
      'home',
      'hotel',
      'hostel',
      'other',
    ];

    for (final category in privateCategories) {
      test('$category → categoryNotPublic', () {
        final result = detectPrivateVenue(
          categoryValue: category,
          venueName: 'Lau Pa Sat',
        );
        expect(result.isPrivate, isTrue);
        expect(result.reason, PrivateVenueReason.categoryNotPublic);
        expect(result.matchedKeyword, isNull);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Null category
  // ---------------------------------------------------------------------------
  group('null category', () {
    test('null category + clean name → not private', () {
      final result = detectPrivateVenue(
        categoryValue: null,
        venueName: 'Gardens by the Bay',
      );
      expect(result.isPrivate, isFalse);
      expect(result.reason, isNull);
    });

    test('null category + "my apartment" → keywordMatch (apartment)', () {
      final result = detectPrivateVenue(
        categoryValue: null,
        venueName: 'my apartment',
      );
      expect(result.isPrivate, isTrue);
      expect(result.reason, PrivateVenueReason.keywordMatch);
      expect(result.matchedKeyword, 'apartment');
    });
  });

  // ---------------------------------------------------------------------------
  // Every keyword — positive case proving case-insensitive contains match.
  // ---------------------------------------------------------------------------
  group('keyword matches (null category, case-insensitive contains)', () {
    const keywordCases = [
      ('condominium', 'Sunrise Condominium Tower'),
      ('apartment', 'City apartment on Level 3'),
      ('my place', 'Come to my place tonight'),
      ('my flat', 'Gathering at my flat'),
      ('my room', 'Chill at my room'),
      ('airbnb', 'Airbnb unit near Orchard'),
      ('studio', 'Studio near Bugis'),
      ('hostel', 'Capsule Hostel Dormitory'),
      ('condo', 'The Pinnacle Condo'),
      ('hotel', 'Grand Hotel lobby'),
      ('motel', 'Budget Motel near airport'),
      ('house', 'Heritage house on Emerald Hill'),
      ('home', 'home base for the group'),
      ('unit', 'unit #04-12 Tanjong Pagar'),
      ('apt', 'Apt 5B Marine Parade'),
    ];

    for (final (keyword, name) in keywordCases) {
      test('"$keyword" detected in "$name"', () {
        final result = detectPrivateVenue(
          categoryValue: null,
          venueName: name,
        );
        expect(result.isPrivate, isTrue);
        expect(result.reason, PrivateVenueReason.keywordMatch);
        expect(result.matchedKeyword, keyword);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // HDB false-positive guard — "Block" must NOT trigger a match.
  // ---------------------------------------------------------------------------
  group('HDB address false-positive guard', () {
    test('"Block 123 Smith St" with public category → not private', () {
      final result = detectPrivateVenue(
        categoryValue: 'hawker_centre',
        venueName: 'Block 123 Smith Street',
      );
      expect(result.isPrivate, isFalse);
    });

    test('"Block 335 Bukit Timah" with null category → not private', () {
      final result = detectPrivateVenue(
        categoryValue: null,
        venueName: 'Block 335 Bukit Timah',
      );
      expect(result.isPrivate, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Case-insensitivity
  // ---------------------------------------------------------------------------
  group('case-insensitive matching', () {
    test('"MY APARTMENT" matches apartment keyword', () {
      final result = detectPrivateVenue(
        categoryValue: null,
        venueName: 'MY APARTMENT',
      );
      expect(result.isPrivate, isTrue);
      expect(result.reason, PrivateVenueReason.keywordMatch);
      expect(result.matchedKeyword, 'apartment');
    });

    test('"HOSTEL" matches hostel keyword', () {
      final result = detectPrivateVenue(
        categoryValue: null,
        venueName: 'HOSTEL',
      );
      expect(result.isPrivate, isTrue);
      expect(result.reason, PrivateVenueReason.keywordMatch);
      expect(result.matchedKeyword, 'hostel');
    });
  });

  // ---------------------------------------------------------------------------
  // Priority — category check wins over keyword match.
  // ---------------------------------------------------------------------------
  group('priority: category check wins over keyword match', () {
    test('category=apartment + name="My Apartment" → categoryNotPublic', () {
      final result = detectPrivateVenue(
        categoryValue: 'apartment',
        venueName: 'My Apartment',
      );
      expect(result.isPrivate, isTrue);
      expect(result.reason, PrivateVenueReason.categoryNotPublic);
      // matchedKeyword must be null — category check short-circuits keyword scan.
      expect(result.matchedKeyword, isNull);
    });

    test('category=home + name="Condo near MRT" → categoryNotPublic', () {
      final result = detectPrivateVenue(
        categoryValue: 'home',
        venueName: 'Condo near MRT',
      );
      expect(result.isPrivate, isTrue);
      expect(result.reason, PrivateVenueReason.categoryNotPublic);
      expect(result.matchedKeyword, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Greedy / longest-first matching — "condominium" wins over "condo".
  // ---------------------------------------------------------------------------
  group('longest-first greedy matching', () {
    test('"Sunrise Condominium" matches condominium not condo', () {
      final result = detectPrivateVenue(
        categoryValue: null,
        venueName: 'Sunrise Condominium',
      );
      expect(result.isPrivate, isTrue);
      expect(result.matchedKeyword, 'condominium');
    });
  });

  // ---------------------------------------------------------------------------
  // Equatable contract.
  // ---------------------------------------------------------------------------
  group('PrivateVenueDetection equality', () {
    test('identical detections are equal', () {
      const a = PrivateVenueDetection(
        isPrivate: true,
        reason: PrivateVenueReason.keywordMatch,
        matchedKeyword: 'condo',
      );
      const b = PrivateVenueDetection(
        isPrivate: true,
        reason: PrivateVenueReason.keywordMatch,
        matchedKeyword: 'condo',
      );
      expect(a, equals(b));
    });

    test('different matchedKeyword → not equal', () {
      const a = PrivateVenueDetection(
        isPrivate: true,
        reason: PrivateVenueReason.keywordMatch,
        matchedKeyword: 'condo',
      );
      const b = PrivateVenueDetection(
        isPrivate: true,
        reason: PrivateVenueReason.keywordMatch,
        matchedKeyword: 'hotel',
      );
      expect(a, isNot(equals(b)));
    });
  });
}
