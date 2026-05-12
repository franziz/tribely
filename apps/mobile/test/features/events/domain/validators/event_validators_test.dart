import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/features/events/domain/validators/event_validators.dart';

void main() {
  // ---------------------------------------------------------------------------
  // validateTitle
  // ---------------------------------------------------------------------------
  group('validateTitle', () {
    test('null → error (required)', () {
      expect(validateTitle(null), isNotNull);
    });

    test('empty string → error (required)', () {
      expect(validateTitle(''), isNotNull);
    });

    test('whitespace-only → error (required)', () {
      expect(validateTitle('   '), isNotNull);
    });

    test('2 chars (below min=$titleMinLen) → error', () {
      expect(validateTitle('ab'), isNotNull);
    });

    test('exactly $titleMinLen chars → valid', () {
      expect(validateTitle('abc'), isNull);
    });

    test('exactly $titleMaxLen chars → valid', () {
      expect(validateTitle('a' * titleMaxLen), isNull);
    });

    test('${titleMaxLen + 1} chars (above max) → error', () {
      expect(validateTitle('a' * (titleMaxLen + 1)), isNotNull);
    });

    test('error message contains character count hint', () {
      final msg = validateTitle('ab');
      expect(msg, contains('$titleMinLen'));
    });
  });

  // ---------------------------------------------------------------------------
  // validateCapacity
  // ---------------------------------------------------------------------------
  group('validateCapacity', () {
    test('null → error (required)', () {
      expect(validateCapacity(null), isNotNull);
    });

    test('1 (below min=$capacityMin) → error', () {
      expect(validateCapacity(1), isNotNull);
    });

    test('exactly $capacityMin → valid', () {
      expect(validateCapacity(capacityMin), isNull);
    });

    test(
      '$capacityUiClamp (UI clamp boundary) → valid (server still accepts)',
      () {
        expect(validateCapacity(capacityUiClamp), isNull);
      },
    );

    test(
      '${capacityUiClamp + 1} (above UI clamp) → valid (server-max not exceeded)',
      () {
        // UI clamp only applies to the slider display; the validator uses server bounds.
        expect(validateCapacity(capacityUiClamp + 1), isNull);
      },
    );

    test('exactly $capacityMax (server max) → valid', () {
      expect(validateCapacity(capacityMax), isNull);
    });

    test('${capacityMax + 1} (above server max) → error', () {
      expect(validateCapacity(capacityMax + 1), isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // validateDescription
  // ---------------------------------------------------------------------------
  group('validateDescription', () {
    test('null → error (required)', () {
      expect(validateDescription(null), isNotNull);
    });

    test('empty string → error (required)', () {
      expect(validateDescription(''), isNotNull);
    });

    test('${descriptionMinLenUi - 1} chars (below UI min) → error', () {
      expect(validateDescription('a' * (descriptionMinLenUi - 1)), isNotNull);
    });

    test('exactly $descriptionMinLenUi chars → valid', () {
      expect(validateDescription('a' * descriptionMinLenUi), isNull);
    });

    test('exactly $descriptionMaxLen chars → valid', () {
      expect(validateDescription('a' * descriptionMaxLen), isNull);
    });

    test('${descriptionMaxLen + 1} chars (above max) → error', () {
      expect(validateDescription('a' * (descriptionMaxLen + 1)), isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // validateLatitude
  // ---------------------------------------------------------------------------
  group('validateLatitude', () {
    test('null → error (required)', () {
      expect(validateLatitude(null), isNotNull);
    });

    test('-91 (below min=$latitudeMin) → error', () {
      expect(validateLatitude(-91), isNotNull);
    });

    test('exactly $latitudeMin → valid', () {
      expect(validateLatitude(latitudeMin), isNull);
    });

    test('0 → valid', () {
      expect(validateLatitude(0), isNull);
    });

    test('exactly $latitudeMax → valid', () {
      expect(validateLatitude(latitudeMax), isNull);
    });

    test('91 (above max=$latitudeMax) → error', () {
      expect(validateLatitude(91), isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // validateLongitude
  // ---------------------------------------------------------------------------
  group('validateLongitude', () {
    test('null → error (required)', () {
      expect(validateLongitude(null), isNotNull);
    });

    test('-181 (below min=$longitudeMin) → error', () {
      expect(validateLongitude(-181), isNotNull);
    });

    test('exactly $longitudeMin → valid', () {
      expect(validateLongitude(longitudeMin), isNull);
    });

    test('exactly $longitudeMax → valid', () {
      expect(validateLongitude(longitudeMax), isNull);
    });

    test('181 (above max=$longitudeMax) → error', () {
      expect(validateLongitude(181), isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // validateVenueName
  // ---------------------------------------------------------------------------
  group('validateVenueName', () {
    test('null → error (required)', () {
      expect(validateVenueName(null), isNotNull);
    });

    test('empty string → error (required)', () {
      expect(validateVenueName(''), isNotNull);
    });

    test('1 char (min=$venueAddressMinLen) → valid', () {
      expect(validateVenueName('a'), isNull);
    });

    test('exactly $venueAddressMaxLen chars → valid', () {
      expect(validateVenueName('a' * venueAddressMaxLen), isNull);
    });

    test('${venueAddressMaxLen + 1} chars (above max) → error', () {
      expect(validateVenueName('a' * (venueAddressMaxLen + 1)), isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // validateStartsAt
  //
  // Requires at least startsAtMinLeadTime (5 minutes) from now so that clock
  // skew between device and server does not cause a "valid on device, rejected
  // on server" race. Tests cover the exact boundary around the 5-minute mark.
  // ---------------------------------------------------------------------------
  group('validateStartsAt', () {
    test('null → error (required)', () {
      expect(validateStartsAt(null), isNotNull);
    });

    test('1 hour in the past → error', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      expect(validateStartsAt(past), isNotNull);
    });

    test('exactly now → error (must be > 5 min ahead)', () {
      expect(validateStartsAt(DateTime.now()), isNotNull);
    });

    test('now + 1 min → error (within 5-minute buffer)', () {
      final tooSoon = DateTime.now().add(const Duration(minutes: 1));
      expect(validateStartsAt(tooSoon), isNotNull);
    });

    test('now + 4 min → error (still within 5-minute buffer)', () {
      final tooSoon = DateTime.now().add(const Duration(minutes: 4));
      expect(validateStartsAt(tooSoon), isNotNull);
    });

    test('now + 6 min → valid (safely past the 5-minute buffer)', () {
      final safe = DateTime.now().add(const Duration(minutes: 6));
      expect(validateStartsAt(safe), isNull);
    });

    test('1 hour in the future → valid', () {
      final future = DateTime.now().add(const Duration(hours: 1));
      expect(validateStartsAt(future), isNull);
    });

    test('error message mentions "5 minutes"', () {
      final past = DateTime.now().subtract(const Duration(seconds: 1));
      expect(validateStartsAt(past), contains('5 minutes'));
    });
  });

  // ---------------------------------------------------------------------------
  // validateEndsAt
  // ---------------------------------------------------------------------------
  group('validateEndsAt', () {
    final start = DateTime(2030, 6, 1, 10);

    test('null → error (required)', () {
      expect(validateEndsAt(null, start), isNotNull);
    });

    test('before startsAt → error', () {
      final before = start.subtract(const Duration(minutes: 1));
      expect(validateEndsAt(before, start), isNotNull);
    });

    test('exactly equal to startsAt → error (must be strictly after)', () {
      expect(validateEndsAt(start, start), isNotNull);
    });

    test('after startsAt → valid', () {
      final after = start.add(const Duration(hours: 2));
      expect(validateEndsAt(after, start), isNull);
    });

    test(
      'null startsAt with valid endsAt → valid (no cross-check possible)',
      () {
        final any = DateTime(2030, 6, 1, 12);
        expect(validateEndsAt(any, null), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // validateApprovalMode
  // ---------------------------------------------------------------------------
  group('validateApprovalMode', () {
    test('null → error (required)', () {
      expect(validateApprovalMode(null), isNotNull);
    });

    test('"auto" → valid', () {
      expect(validateApprovalMode('auto'), isNull);
    });

    test('"manual" → valid', () {
      expect(validateApprovalMode('manual'), isNull);
    });

    test('"garbage" → error', () {
      expect(validateApprovalMode('garbage'), isNotNull);
    });

    test('empty string → error', () {
      expect(validateApprovalMode(''), isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // validateCategory
  // ---------------------------------------------------------------------------
  group('validateCategory', () {
    test('null → error (required)', () {
      expect(validateCategory(null), isNotNull);
    });

    test('EventCategory.drinks → valid', () {
      expect(validateCategory(EventCategory.drinks), isNull);
    });

    for (final cat in EventCategory.values) {
      test('${cat.name} → valid', () {
        expect(validateCategory(cat), isNull);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // EventCategory.wireValue round-trip + fromWire defensive default
  // ---------------------------------------------------------------------------
  group('EventCategory wire round-trip', () {
    for (final cat in EventCategory.values) {
      test('${cat.name} survives wireValue → fromWire', () {
        final wire = cat.wireValue;
        final recovered = EventCategory.fromWire(wire);
        expect(recovered, cat);
      });
    }

    test('unknown wire value → EventCategory.other (defensive default)', () {
      expect(
        EventCategory.fromWire('unknown_future_value'),
        EventCategory.other,
      );
    });

    test('all 7 EventCategory values are covered', () {
      expect(EventCategory.values.length, 7);
    });
  });
}
