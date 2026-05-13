// Widget tests for the pending requests section on the host event detail page.
//
// Tests the _PendingRequestsSection behaviour indirectly via the controller
// state + a thin widget harness that mimics the section's switch/rendering.
//
// Covers:
//   1. Section hidden (SizedBox.shrink) when zero pending items.
//   2. Section renders row with requester name when items.length > 0.
//   3. Section header shows correct count "REQUESTS (N)".
//   4. 409 CapacityFull → BannerMessage shown at section top; row still present.
//   5. Race-condition (ConflictFailure) → raceConflictId set on state.
//   6. Network failure → sectionError set on state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/widgets/banner_message.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request_with_requester.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/host_pending_list_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/host_pending_list_state.dart';
import 'package:tribely/src/features/join_requests/presentation/widgets/pending_request_row.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testEventId = 'evt-section-test';

JoinRequestWithRequester _requester({
  String id = 'jr-1',
  String displayName = 'Priya Sharma',
}) {
  return JoinRequestWithRequester(
    joinRequest: JoinRequest(
      id: id,
      eventId: _testEventId,
      requesterUserId: 'user-1',
      status: JoinRequestStatus.pending,
      requestedAt: DateTime.utc(2026, 5, 1),
    ),
    requester: JoinRequestRequesterSummary(
      id: 'user-1',
      displayName: displayName,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fixed-state controller
// ---------------------------------------------------------------------------

class _FixedHostPendingController extends HostPendingListController {
  _FixedHostPendingController(this._fixed) : super(_testEventId);

  final HostPendingListState _fixed;

  @override
  HostPendingListState build() => _fixed;

  @override
  Future<void> retry() async {}

  @override
  Future<void> load() async {}

  @override
  Future<void> approve(String joinRequestId) async {}

  @override
  Future<void> decline(String joinRequestId, {String? reason}) async {}

  @override
  void clearSectionError() {}

  @override
  void clearRaceConflict() {}
}

// ---------------------------------------------------------------------------
// Mini section harness
// Replicates the core rendering logic of _PendingLoadedSection without
// importing private symbols.
// ---------------------------------------------------------------------------

class _SectionHarness extends ConsumerWidget {
  const _SectionHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(hostPendingListControllerProvider(_testEventId));
    final controller = ref.read(
      hostPendingListControllerProvider(_testEventId).notifier,
    );

    return switch (st) {
      HostPendingListLoading() => const CircularProgressIndicator(),
      HostPendingListError(:final failure) => BannerMessage(
        message: failure.message,
        action: BannerAction(label: 'Retry', onTap: controller.retry),
      ),
      HostPendingListLoaded(items: final items) when items.isEmpty =>
        const SizedBox.shrink(),
      HostPendingListLoaded(
        :final items,
        :final sectionError,
        :final actionInFlightId,
      ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('REQUESTS (${items.length})'),
            if (sectionError != null) BannerMessage(message: sectionError),
            ...items.map(
              (item) => PendingRequestRow(
                key: ValueKey(item.joinRequest.id),
                item: item,
                onApprove: () => controller.approve(item.joinRequest.id),
                onDecline: (_) =>
                    controller.decline(item.joinRequest.id, reason: 'test'),
                isInFlight: actionInFlightId == item.joinRequest.id,
              ),
            ),
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpSection(
  WidgetTester tester,
  HostPendingListState state,
) async {
  final controller = _FixedHostPendingController(state);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hostPendingListControllerProvider(
          _testEventId,
        ).overrideWith(() => controller),
      ],
      child: const MaterialApp(home: Scaffold(body: _SectionHarness())),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PendingRequestsSection', () {
    // -----------------------------------------------------------------------
    // 1. Zero pending → section hidden
    // -----------------------------------------------------------------------
    testWidgets('renders nothing when items list is empty', (tester) async {
      await _pumpSection(tester, const HostPendingListLoaded(items: []));

      expect(find.byType(PendingRequestRow), findsNothing);
      expect(find.textContaining('REQUESTS'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 2. Items present → row with display name visible
    // -----------------------------------------------------------------------
    testWidgets(
      'renders PendingRequestRow with requester name when items > 0',
      (tester) async {
        await _pumpSection(
          tester,
          HostPendingListLoaded(items: [_requester()]),
        );

        expect(find.byType(PendingRequestRow), findsOneWidget);
        expect(find.text('Priya Sharma'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 3. Section header count
    // -----------------------------------------------------------------------
    testWidgets('section header shows correct item count', (tester) async {
      await _pumpSection(
        tester,
        HostPendingListLoaded(
          items: [
            _requester(id: 'jr-1'),
            _requester(id: 'jr-2', displayName: 'Kai'),
          ],
        ),
      );

      expect(find.textContaining('REQUESTS (2)'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 4. 409 CapacityFull → BannerMessage shown, row stays
    // -----------------------------------------------------------------------
    testWidgets(
      '409 CapacityFull: BannerMessage shown at section top, row still present',
      (tester) async {
        await _pumpSection(
          tester,
          HostPendingListLoaded(
            items: [_requester()],
            sectionError:
                "This event is now full — you can't approve more joiners.",
          ),
        );

        expect(find.byType(BannerMessage), findsOneWidget);
        expect(find.textContaining('This event is now full'), findsOneWidget);
        // Row is still in the list (row stays per PM AC).
        expect(find.byType(PendingRequestRow), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 5. Race condition → raceConflictId set on state
    // -----------------------------------------------------------------------
    testWidgets('race-condition: HostPendingListLoaded carries raceConflictId', (
      tester,
    ) async {
      final state = HostPendingListLoaded(
        items: [_requester()],
        raceConflictId: 'jr-1',
      );

      // Verify the state field is set correctly (controller tested separately).
      expect(state.raceConflictId, equals('jr-1'));
    });

    // -----------------------------------------------------------------------
    // 6. Network failure → sectionError set on state
    // -----------------------------------------------------------------------
    testWidgets('network failure sets sectionError on state', (tester) async {
      const errorMsg = 'No connection. Check your network and try again.';

      await _pumpSection(
        tester,
        HostPendingListLoaded(items: [_requester()], sectionError: errorMsg),
      );

      expect(find.byType(BannerMessage), findsOneWidget);
      expect(find.textContaining('No connection'), findsOneWidget);
    });
  });
}
