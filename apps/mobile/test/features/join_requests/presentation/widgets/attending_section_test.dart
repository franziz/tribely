// Widget tests for the _AttendingSection rendered on the host event detail page.
//
// Covers:
//   1. Section hidden (SizedBox.shrink) when items list is empty.
//   2. Section renders AttendingRequestRow with requester name when items > 0.
//   3. Section header shows correct count "ATTENDING (N)".
//   4. Error state renders BannerMessage with retry.
//   5. Loading state renders nothing (SizedBox.shrink).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/widgets/banner_message.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request.dart';
import 'package:tribely/src/features/join_requests/domain/entities/join_request_with_requester.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/host_attending_list_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/host_attending_list_state.dart';
import 'package:tribely/src/features/join_requests/presentation/widgets/attending_request_row.dart';
import 'package:tribely/src/core/error/failures.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testEventId = 'evt-attending-widget-test';

JoinRequestWithRequester _makeItem(String id, String name) =>
    JoinRequestWithRequester(
      joinRequest: JoinRequest(
        id: id,
        eventId: _testEventId,
        requesterUserId: 'user-$id',
        status: JoinRequestStatus.approved,
        requestedAt: DateTime.utc(2026, 5, 1),
      ),
      requester: JoinRequestRequesterSummary(id: 'user-$id', displayName: name),
    );

// ---------------------------------------------------------------------------
// Fixed-state controller spy
// ---------------------------------------------------------------------------

class _FixedHostAttendingController extends HostAttendingListController {
  _FixedHostAttendingController(this._fixed) : super(_testEventId);

  final HostAttendingListState _fixed;

  @override
  HostAttendingListState build() => _fixed;

  @override
  Future<void> retry() async {}
}

// ---------------------------------------------------------------------------
// Section harness — replicates the rendering logic of _AttendingSection
// without importing private symbols.
// ---------------------------------------------------------------------------

class _SectionHarness extends ConsumerWidget {
  const _SectionHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(hostAttendingListControllerProvider(_testEventId));
    final controller = ref.read(
      hostAttendingListControllerProvider(_testEventId).notifier,
    );

    return switch (st) {
      HostAttendingListLoading() => const SizedBox.shrink(),
      HostAttendingListError(:final failure) => BannerMessage(
        message: failure.message,
        action: BannerAction(label: 'Retry', onTap: controller.retry),
      ),
      HostAttendingListLoaded(items: final items) when items.isEmpty =>
        const SizedBox.shrink(),
      HostAttendingListLoaded(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ATTENDING (${items.length})'),
          ...items.map(
            (item) => AttendingRequestRow(
              key: ValueKey(item.joinRequest.id),
              item: item,
            ),
          ),
        ],
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpSection(
  WidgetTester tester,
  HostAttendingListState state,
) async {
  final controller = _FixedHostAttendingController(state);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hostAttendingListControllerProvider(
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
  group('AttendingSection', () {
    // -----------------------------------------------------------------------
    // 1. Loading → nothing rendered
    // -----------------------------------------------------------------------
    testWidgets('renders nothing when loading', (tester) async {
      await _pumpSection(tester, const HostAttendingListLoading());

      expect(find.byType(AttendingRequestRow), findsNothing);
      expect(find.textContaining('ATTENDING'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 2. Loaded empty → nothing rendered
    // -----------------------------------------------------------------------
    testWidgets('renders nothing when items list is empty', (tester) async {
      await _pumpSection(tester, const HostAttendingListLoaded(items: []));

      expect(find.byType(AttendingRequestRow), findsNothing);
      expect(find.textContaining('ATTENDING'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 3. Loaded with items → rows + correct header
    // -----------------------------------------------------------------------
    testWidgets(
      'renders AttendingRequestRow with requester name when items > 0',
      (tester) async {
        await _pumpSection(
          tester,
          HostAttendingListLoaded(items: [_makeItem('jr-1', 'Alice Tan')]),
        );

        expect(find.byType(AttendingRequestRow), findsOneWidget);
        expect(find.text('Alice Tan'), findsOneWidget);
      },
    );

    testWidgets('section header shows correct item count', (tester) async {
      await _pumpSection(
        tester,
        HostAttendingListLoaded(
          items: [
            _makeItem('jr-1', 'Alice'),
            _makeItem('jr-2', 'Bob'),
            _makeItem('jr-3', 'Carol'),
          ],
        ),
      );

      expect(find.textContaining('ATTENDING (3)'), findsOneWidget);
      expect(find.byType(AttendingRequestRow), findsNWidgets(3));
    });

    // -----------------------------------------------------------------------
    // 4. Error state → BannerMessage with retry
    // -----------------------------------------------------------------------
    testWidgets('error state renders BannerMessage with retry', (tester) async {
      await _pumpSection(
        tester,
        const HostAttendingListError(failure: NetworkFailure('timeout')),
      );

      expect(find.byType(BannerMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
