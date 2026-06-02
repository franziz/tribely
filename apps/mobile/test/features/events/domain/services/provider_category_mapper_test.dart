import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/events/domain/services/provider_category_mapper.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Null / unknown inputs
  // ---------------------------------------------------------------------------
  group('null and unknown inputs → null', () {
    test('null returns null', () {
      expect(mapProviderCategoryToVenueCategory(null), isNull);
    });

    test('empty string returns null', () {
      expect(mapProviderCategoryToVenueCategory(''), isNull);
    });

    test('unknown category returns null', () {
      expect(mapProviderCategoryToVenueCategory('bowling_alley'), isNull);
    });

    test('partial match returns null (no prefix matching)', () {
      expect(mapProviderCategoryToVenueCategory('restaur'), isNull);
    });

    test('wrong case returns null (mapping is case-sensitive)', () {
      expect(mapProviderCategoryToVenueCategory('Restaurant'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Direct mappings (12 Tribely public categories)
  // ---------------------------------------------------------------------------
  group('direct / primary Mapbox key → Tribely category', () {
    test('restaurant → restaurant', () {
      expect(
        mapProviderCategoryToVenueCategory('restaurant'),
        equals('restaurant'),
      );
    });

    test('park → park', () {
      expect(mapProviderCategoryToVenueCategory('park'), equals('park'));
    });

    test('museum → museum', () {
      expect(mapProviderCategoryToVenueCategory('museum'), equals('museum'));
    });

    test('beach → beach', () {
      expect(mapProviderCategoryToVenueCategory('beach'), equals('beach'));
    });

    test('library → library', () {
      expect(mapProviderCategoryToVenueCategory('library'), equals('library'));
    });

    test('bar → bar', () {
      expect(mapProviderCategoryToVenueCategory('bar'), equals('bar'));
    });

    test('cafe → cafe', () {
      expect(mapProviderCategoryToVenueCategory('cafe'), equals('cafe'));
    });

    test('tourist_attraction → tourist_attraction', () {
      expect(
        mapProviderCategoryToVenueCategory('tourist_attraction'),
        equals('tourist_attraction'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Synonym mappings
  // ---------------------------------------------------------------------------
  group('Mapbox synonyms → expected Tribely category', () {
    test('pub → bar', () {
      expect(mapProviderCategoryToVenueCategory('pub'), equals('bar'));
    });

    test('coffee_shop → cafe', () {
      expect(
        mapProviderCategoryToVenueCategory('coffee_shop'),
        equals('cafe'),
      );
    });

    test('hawker → hawker_centre', () {
      expect(
        mapProviderCategoryToVenueCategory('hawker'),
        equals('hawker_centre'),
      );
    });

    test('transit_station → mrt_landmark', () {
      expect(
        mapProviderCategoryToVenueCategory('transit_station'),
        equals('mrt_landmark'),
      );
    });

    test('community_center (US spelling) → community_centre', () {
      expect(
        mapProviderCategoryToVenueCategory('community_center'),
        equals('community_centre'),
      );
    });

    test('community_centre (GB spelling) → community_centre', () {
      expect(
        mapProviderCategoryToVenueCategory('community_centre'),
        equals('community_centre'),
      );
    });

    test('shopping_mall → shopping_mall_common_area', () {
      expect(
        mapProviderCategoryToVenueCategory('shopping_mall'),
        equals('shopping_mall_common_area'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // All 12 Tribely public venue categories are reachable
  // ---------------------------------------------------------------------------
  group('all 12 Tribely public categories are reachable via at least one key',
      () {
    const expectedCategories = {
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
    };

    // Primary or synonym keys that map to each of the 12 values.
    const reachableVia = {
      'hawker_centre': 'hawker',
      'park': 'park',
      'museum': 'museum',
      'restaurant': 'restaurant',
      'bar': 'bar',
      'cafe': 'cafe',
      'beach': 'beach',
      'mrt_landmark': 'transit_station',
      'library': 'library',
      'community_centre': 'community_center',
      'shopping_mall_common_area': 'shopping_mall',
      'tourist_attraction': 'tourist_attraction',
    };

    for (final venueCategory in expectedCategories) {
      test('$venueCategory is reachable', () {
        final input = reachableVia[venueCategory]!;
        expect(
          mapProviderCategoryToVenueCategory(input),
          equals(venueCategory),
          reason: 'Expected "$input" to map to "$venueCategory"',
        );
      });
    }
  });
}
