// Unit tests for EventModel.fromJson — costNotes round-trip + crash regression
// (TRI-51 C).
//
// Verifies:
//   - fromJson with costNotes present maps to Event.costNotes.
//   - fromJson with costNotes: null → Event.costNotes == null (crash-safe).
//   - fromJson with no costSplit key does NOT throw.
//   - toEntity() propagates costNotes correctly.

import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/events/data/models/event_model.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal valid event JSON without a costNotes key (matches the synthesised
/// flat map that the datasource produces when the server omits the field).
Map<String, dynamic> _baseJson() => {
  'id': 'evt-1',
  'hostUserId': 'usr-1',
  'title': 'Sunday Morning Hike',
  'description': 'A lovely hike.',
  'venue': {
    'address': '1 Marina Blvd',
    'city': 'Singapore',
    'latitude': 1.28,
    'longitude': 103.85,
    'category': 'park',
  },
  'startsAt': '2030-06-01T08:00:00.000Z',
  'endsAt': '2030-06-01T11:00:00.000Z',
  'capacity': 10,
  'category': 'hike',
  'approvalMode': 'auto',
  'status': 'published',
  'createdAt': '2030-01-01T00:00:00.000Z',
  'hostIsVerified': false,
  'hostDisplayName': 'Alice',
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventModel.fromJson — costNotes round-trip (TRI-51 C)', () {
    test('fromJson with costNotes present maps to Event.costNotes', () {
      final json = {..._baseJson(), 'costNotes': 'Pay your own way'};
      final entity = EventModel.fromJson(json).toEntity();
      expect(entity.costNotes, 'Pay your own way');
    });

    test(
      'fromJson with costNotes absent → Event.costNotes == null (crash-safe)',
      () {
        // No 'costNotes' key in the payload — simulates server omitting the
        // field (the old costSplit-only response shape).
        final json = _baseJson();
        expect(
          json.containsKey('costNotes'),
          isFalse,
          reason: 'fixture must not include costNotes',
        );
        final entity = EventModel.fromJson(json).toEntity();
        expect(entity.costNotes, isNull);
      },
    );

    test('fromJson with costNotes: null → Event.costNotes == null', () {
      final json = {..._baseJson(), 'costNotes': null};
      final entity = EventModel.fromJson(json).toEntity();
      expect(entity.costNotes, isNull);
    });

    test('fromJson without costSplit key does not throw', () {
      final json = _baseJson();
      expect(
        json.containsKey('costSplit'),
        isFalse,
        reason: 'fixture must not include costSplit',
      );
      // Must not throw.
      expect(() => EventModel.fromJson(json), returnsNormally);
    });
  });
}
