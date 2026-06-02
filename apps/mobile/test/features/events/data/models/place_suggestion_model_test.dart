import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/events/data/models/place_suggestion_model.dart';
import 'package:tribely/src/features/events/domain/entities/place_suggestion.dart';

void main() {
  group('PlaceSuggestionModel.fromJson', () {
    test('happy path — all fields present including poi_category', () {
      final json = {
        'mapbox_id': 'place.abc123',
        'name': 'Lau Pa Sat',
        'place_formatted': '18 Raffles Quay, Singapore 048582',
        'poi_category': ['food_and_drink', 'restaurant'],
      };

      final model = PlaceSuggestionModel.fromJson(json);

      expect(model.mapboxId, 'place.abc123');
      expect(model.name, 'Lau Pa Sat');
      expect(model.placeFormatted, '18 Raffles Quay, Singapore 048582');
      expect(model.rawCategory, 'food_and_drink');
    });

    test('poi_category absent → rawCategory is null', () {
      final json = {
        'mapbox_id': 'place.xyz',
        'name': 'Marina Bay Sands',
        'place_formatted': '10 Bayfront Ave, Singapore 018956',
      };

      final model = PlaceSuggestionModel.fromJson(json);

      expect(model.rawCategory, isNull);
    });

    test('poi_category is empty array → rawCategory is null', () {
      final json = {
        'mapbox_id': 'place.xyz',
        'name': 'Marina Bay Sands',
        'place_formatted': '10 Bayfront Ave, Singapore 018956',
        'poi_category': <dynamic>[],
      };

      final model = PlaceSuggestionModel.fromJson(json);

      expect(model.rawCategory, isNull);
    });

    test('place_formatted absent → defaults to empty string', () {
      final json = {'mapbox_id': 'place.xyz', 'name': 'Some Place'};

      final model = PlaceSuggestionModel.fromJson(json);

      expect(model.placeFormatted, '');
    });
  });

  group('PlaceSuggestionModel.toEntity', () {
    test('maps all fields to PlaceSuggestion correctly', () {
      const model = PlaceSuggestionModel(
        mapboxId: 'place.abc',
        name: 'Lau Pa Sat',
        placeFormatted: '18 Raffles Quay',
        rawCategory: 'restaurant',
      );

      final entity = model.toEntity();

      expect(entity, isA<PlaceSuggestion>());
      expect(entity.providerPlaceId, 'place.abc');
      expect(entity.name, 'Lau Pa Sat');
      expect(entity.placeFormatted, '18 Raffles Quay');
      expect(entity.rawCategory, 'restaurant');
    });

    test('null rawCategory flows through to entity', () {
      const model = PlaceSuggestionModel(
        mapboxId: 'place.abc',
        name: 'Lau Pa Sat',
        placeFormatted: '18 Raffles Quay',
      );

      final entity = model.toEntity();

      expect(entity.rawCategory, isNull);
    });
  });
}
