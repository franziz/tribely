import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/join_requests/data/models/join_request_model.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';

void main() {
  final baseDate = DateTime.utc(2026, 1, 1);

  Map<String, dynamic> baseJson({required String status}) => {
    'id': 'jr-1',
    'eventId': 'evt-1',
    'requesterUserId': 'usr-1',
    'status': status,
    'requestedAt': baseDate.toIso8601String(),
  };

  group('JoinRequestModel._mapStatus', () {
    void expectStatus(String wire, JoinRequestStatus expected) {
      final model = JoinRequestModel.fromJson(baseJson(status: wire));
      expect(
        model.toEntity().status,
        expected,
        reason: "'$wire' should map to $expected",
      );
    }

    test("'pending' -> JoinRequestStatus.pending", () {
      expectStatus('pending', JoinRequestStatus.pending);
    });

    test("'approved' -> JoinRequestStatus.approved", () {
      expectStatus('approved', JoinRequestStatus.approved);
    });

    test(
      "'rejected' -> JoinRequestStatus.declined (product-spec language)",
      () {
        expectStatus('rejected', JoinRequestStatus.declined);
      },
    );

    test(
      "'cancelled' -> JoinRequestStatus.withdrawn (product-spec language)",
      () {
        expectStatus('cancelled', JoinRequestStatus.withdrawn);
      },
    );

    test("'removed_by_host' -> JoinRequestStatus.removedByHost (TRI-63)", () {
      expectStatus('removed_by_host', JoinRequestStatus.removedByHost);
    });

    test('unknown wire value falls back to pending defensively', () {
      expectStatus('__unknown__', JoinRequestStatus.pending);
    });
  });
}
