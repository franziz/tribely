import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/events/data/models/place_details_model.dart';
import 'package:tribely/src/features/events/domain/entities/place_details.dart';

/// Minimal GeoJSON Feature fixture for a Mapbox /retrieve response.
Map<String, dynamic> _featureJson({
  String mapboxId = 'place.abc123',
  String name = 'Lau Pa Sat',
  String? fullAddress = '18 Raffles Quay, Singapore 048582',
  // GeoJSON order: [longitude, latitude]
  double lng = 103.8500,
  double lat = 1.2800,
  List<dynamic>? poiCategory = const ['food_and_drink'],
}) => {
  'properties': {
    'mapbox_id': mapboxId,
    'name': name,
    if (fullAddress != null) 'full_address': fullAddress,
    if (poiCategory != null) 'poi_category': poiCategory,
  },
  'geometry': {
    'type': 'Point',
    'coordinates': [lng, lat], // GeoJSON: lng first
  },
};

void main() {
  group('PlaceDetailsModel.fromJson', () {
    // -----------------------------------------------------------------------
    // GeoJSON coordinate flip — this is the primary regression guard.
    // Mapbox GeoJSON is [longitude, latitude]; our domain entity is lat/lng.
    // If the indices are ever swapped this test catches it immediately.
    // -----------------------------------------------------------------------
    test('REGRESSION: GeoJSON [lng, lat] → entity latitude and longitude are '
        'correctly assigned (coordinates[0]=lng, coordinates[1]=lat)', () {
      // Singapore coordinates: lat 1.28, lng 103.85
      final json = _featureJson(lng: 103.85, lat: 1.28);

      final model = PlaceDetailsModel.fromJson(json);

      // The critical assertion: entity latitude must be 1.28 (index 1),
      // not 103.85 (index 0 which is longitude).
      expect(
        model.latitude,
        1.28,
        reason:
            'latitude must come from coordinates[1] (GeoJSON lng-first order)',
      );
      expect(
        model.longitude,
        103.85,
        reason:
            'longitude must come from coordinates[0] (GeoJSON lng-first order)',
      );
    });

    test('happy path — all fields present', () {
      final model = PlaceDetailsModel.fromJson(_featureJson());

      expect(model.mapboxId, 'place.abc123');
      expect(model.name, 'Lau Pa Sat');
      expect(model.formattedAddress, '18 Raffles Quay, Singapore 048582');
      expect(model.latitude, 1.2800);
      expect(model.longitude, 1038500 / 10000); // 103.85
      expect(model.rawCategory, 'food_and_drink');
    });

    test('poi_category absent → rawCategory is null', () {
      final json = _featureJson(poiCategory: null);

      final model = PlaceDetailsModel.fromJson(json);

      expect(model.rawCategory, isNull);
    });

    test('poi_category is empty array → rawCategory is null', () {
      final json = _featureJson(poiCategory: []);

      final model = PlaceDetailsModel.fromJson(json);

      expect(model.rawCategory, isNull);
    });

    test('full_address absent → falls back to place_formatted', () {
      final properties = {
        'mapbox_id': 'place.xyz',
        'name': 'Test Place',
        'place_formatted': '1 Test St, Singapore',
        // full_address intentionally absent
      };
      final json = {
        'properties': properties,
        'geometry': {
          'type': 'Point',
          'coordinates': [103.85, 1.28],
        },
      };

      final model = PlaceDetailsModel.fromJson(json);

      expect(model.formattedAddress, '1 Test St, Singapore');
    });

    test('both full_address and place_formatted absent → empty string', () {
      final properties = {
        'mapbox_id': 'place.xyz',
        'name': 'Test Place',
        // neither full_address nor place_formatted
      };
      final json = {
        'properties': properties,
        'geometry': {
          'type': 'Point',
          'coordinates': [103.85, 1.28],
        },
      };

      final model = PlaceDetailsModel.fromJson(json);

      expect(model.formattedAddress, '');
    });
  });

  group('PlaceDetailsModel.toEntity', () {
    test('maps all fields to PlaceDetails correctly', () {
      const model = PlaceDetailsModel(
        mapboxId: 'place.abc',
        name: 'Lau Pa Sat',
        formattedAddress: '18 Raffles Quay',
        longitude: 103.85,
        latitude: 1.28,
        rawCategory: 'restaurant',
      );

      final entity = model.toEntity();

      expect(entity, isA<PlaceDetails>());
      expect(entity.providerPlaceId, 'place.abc');
      expect(entity.name, 'Lau Pa Sat');
      expect(entity.formattedAddress, '18 Raffles Quay');
      expect(entity.latitude, 1.28);
      expect(entity.longitude, 103.85);
      expect(entity.rawCategory, 'restaurant');
    });

    test('null rawCategory flows through to entity', () {
      const model = PlaceDetailsModel(
        mapboxId: 'place.abc',
        name: 'Lau Pa Sat',
        formattedAddress: '18 Raffles Quay',
        longitude: 103.85,
        latitude: 1.28,
      );

      final entity = model.toEntity();

      expect(entity.rawCategory, isNull);
    });
  });
}
