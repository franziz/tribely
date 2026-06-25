// Unit tests for CreateEventParamsModel serialisation.
//
// Primary concern: startsAt / endsAt must emit UTC ISO-8601 strings (ending
// with 'Z') regardless of whether the input DateTime is local or already UTC.
// Server's z.string().datetime({ offset: true }) rejects timezone-less strings
// produced by DateTime.toIso8601String() on local DateTimes.

import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/events/data/models/create_event_params_model.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/features/events/domain/repositories/event_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CreateEventParamsModel _modelFrom({
  required DateTime startsAt,
  required DateTime endsAt,
}) {
  final params = CreateEventParams(
    title: 'Sunday Morning Hike',
    category: EventCategory.hike,
    venueName: '1 Marina Blvd, Marina Bay',
    venueCategory: 'park',
    latitude: 1.28,
    longitude: 103.85,
    startsAt: startsAt,
    endsAt: endsAt,
    capacity: 10,
    approvalMode: 'auto',
    description: 'A lovely hike for solo travellers exploring Singapore.',
  );
  return CreateEventParamsModel.fromDomain(params);
}

void main() {
  // ---------------------------------------------------------------------------
  // venue.category serialisation (TRI-33 Brief 8)
  // ---------------------------------------------------------------------------
  group('CreateEventParamsModel.toJson — venue.category serialisation', () {
    test('venueCategory is serialised as venue.category in the request body', () {
      final json = _modelFrom(
        startsAt: DateTime.utc(2030, 6, 1, 8),
        endsAt: DateTime.utc(2030, 6, 1, 11),
      ).toJson();

      final venue = json['venue'] as Map<String, dynamic>;
      expect(
        venue['category'],
        'park',
        reason:
            'venueCategory must be included in the POST body as venue.category',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // startsAt / endsAt UTC serialisation (Fix #1 — TRI-26)
  // ---------------------------------------------------------------------------
  group('CreateEventParamsModel.toJson — UTC datetime serialisation', () {
    test('startsAt from a local DateTime serialises with trailing Z', () {
      // DateTime() without explicit UTC flag is local — reproduces the bug.
      final localStart = DateTime(2030, 6, 1, 8, 0);
      final localEnd = DateTime(2030, 6, 1, 11, 0);

      final json = _modelFrom(startsAt: localStart, endsAt: localEnd).toJson();

      expect(
        (json['startsAt'] as String).endsWith('Z'),
        isTrue,
        reason: 'startsAt must be a UTC ISO-8601 string (trailing Z)',
      );
    });

    test('endsAt from a local DateTime serialises with trailing Z', () {
      final localStart = DateTime(2030, 6, 1, 8, 0);
      final localEnd = DateTime(2030, 6, 1, 11, 0);

      final json = _modelFrom(startsAt: localStart, endsAt: localEnd).toJson();

      expect(
        (json['endsAt'] as String).endsWith('Z'),
        isTrue,
        reason: 'endsAt must be a UTC ISO-8601 string (trailing Z)',
      );
    });

    test(
      'startsAt from an already-UTC DateTime still serialises with trailing Z',
      () {
        final utcStart = DateTime.utc(2030, 6, 1, 0, 0);
        final utcEnd = DateTime.utc(2030, 6, 1, 3, 0);

        final json = _modelFrom(startsAt: utcStart, endsAt: utcEnd).toJson();

        expect(
          (json['startsAt'] as String).endsWith('Z'),
          isTrue,
          reason: 'UTC input must not double-convert; still ends with Z',
        );
      },
    );

    test(
      'serialised startsAt preserves the correct instant (UTC+8 → UTC offset)',
      () {
        // Singapore is UTC+8. 08:00 local == 00:00 UTC. Verify instant equality
        // by round-tripping through DateTime.parse.
        //
        // Note: DateTime() without UTC flag picks up the device's local timezone
        // in tests. We use a known UTC value to make the assertion deterministic.
        final utcStart = DateTime.utc(2030, 6, 1, 0, 0);
        final utcEnd = DateTime.utc(2030, 6, 1, 3, 0);

        final json = _modelFrom(startsAt: utcStart, endsAt: utcEnd).toJson();

        final parsed = DateTime.parse(json['startsAt'] as String);
        expect(
          parsed.isAtSameMomentAs(utcStart),
          isTrue,
          reason:
              '.toUtc() must not shift the instant — only the representation',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // costNotes serialisation + costSplit removal (TRI-51 C)
  // ---------------------------------------------------------------------------
  group('CreateEventParamsModel.toJson — costNotes / costSplit (TRI-51 C)', () {
    CreateEventParamsModel modelWithCostNotes(String? costNotes) {
      final params = CreateEventParams(
        title: 'Sunday Morning Hike',
        category: EventCategory.hike,
        venueName: '1 Marina Blvd, Marina Bay',
        venueCategory: 'park',
        latitude: 1.28,
        longitude: 103.85,
        startsAt: DateTime.utc(2030, 6, 1, 8),
        endsAt: DateTime.utc(2030, 6, 1, 11),
        capacity: 10,
        approvalMode: 'auto',
        description: 'A lovely hike.',
        costNotes: costNotes,
      );
      return CreateEventParamsModel.fromDomain(params);
    }

    test('costNotes is present in toJson when non-null and non-empty', () {
      final json = modelWithCostNotes('split it').toJson();
      expect(json.containsKey('costNotes'), isTrue);
      expect(json['costNotes'], 'split it');
    });

    test('costNotes is absent from toJson when null', () {
      final json = modelWithCostNotes(null).toJson();
      expect(json.containsKey('costNotes'), isFalse);
    });

    test('costNotes is absent from toJson when empty string', () {
      final json = modelWithCostNotes('').toJson();
      expect(json.containsKey('costNotes'), isFalse);
    });

    test('costSplit is absent from toJson in all cases', () {
      final jsonWithNotes = modelWithCostNotes('split it').toJson();
      final jsonWithoutNotes = modelWithCostNotes(null).toJson();
      expect(jsonWithNotes.containsKey('costSplit'), isFalse);
      expect(jsonWithoutNotes.containsKey('costSplit'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // coverPhotoStorageKey serialisation (TRI-49 Brief 5)
  // ---------------------------------------------------------------------------
  group(
    'CreateEventParamsModel.toJson — coverPhotoStorageKey (TRI-49 Brief 5)',
    () {
      CreateEventParamsModel modelWithKey(String? key) {
        final params = CreateEventParams(
          title: 'Sunday Morning Hike',
          category: EventCategory.hike,
          venueName: '1 Marina Blvd, Marina Bay',
          venueCategory: 'park',
          latitude: 1.28,
          longitude: 103.85,
          startsAt: DateTime.utc(2030, 6, 1, 8),
          endsAt: DateTime.utc(2030, 6, 1, 11),
          capacity: 10,
          approvalMode: 'auto',
          description: 'A lovely hike.',
          coverPhotoStorageKey: key,
        );
        return CreateEventParamsModel.fromDomain(params);
      }

      test('coverPhotoStorageKey is present in toJson when non-null', () {
        final json = modelWithKey('events/covers/test-key.jpg').toJson();
        expect(json.containsKey('coverPhotoStorageKey'), isTrue);
        expect(json['coverPhotoStorageKey'], 'events/covers/test-key.jpg');
      });

      test('coverPhotoStorageKey is absent from toJson when null', () {
        final json = modelWithKey(null).toJson();
        expect(json.containsKey('coverPhotoStorageKey'), isFalse);
      });
    },
  );
}
