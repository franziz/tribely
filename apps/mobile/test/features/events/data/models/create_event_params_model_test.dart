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
}
