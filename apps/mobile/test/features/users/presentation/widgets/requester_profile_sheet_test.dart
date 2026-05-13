// Widget tests for RequesterProfileSheet.
//
// Covers:
//   1. Loaded state: displays display name + "Member since {Month YYYY}".
//   2. Error state: displays BannerMessage with retry.
//   3. Loading state: no display name visible (shimmer only).
//
// The sheet reads from [userProfileByIdProvider]
// (FutureProvider.autoDispose.family<UserProfile, String>) in core/providers/.
// Tests override that provider directly — no controller spy needed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/providers/get_user_profile_usecase_provider.dart'
    show userProfileByIdProvider;
import 'package:tribely/src/core/widgets/banner_message.dart';
import 'package:tribely/src/core/widgets/requester_profile_sheet.dart';
import 'package:tribely/src/features/users/domain/entities/user_profile.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testUserId = 'user-sheet-test';

UserProfile _makeProfile({
  String displayName = 'Priya Sharma',
  DateTime? createdAt,
}) => UserProfile(
  id: _testUserId,
  email: 'priya@tribely.com',
  displayName: displayName,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 15),
  updatedAt: DateTime.utc(2026, 1, 15),
);

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

/// Pumps [RequesterProfileSheet] with [userProfileByIdProvider] overridden to
/// the given [AsyncValue]. Uses [overrideWithValue] to inject the state
/// synchronously — no async settling required.
Future<void> _pumpSheet(
  WidgetTester tester,
  AsyncValue<UserProfile> asyncValue,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileByIdProvider(_testUserId).overrideWithValue(asyncValue),
      ],
      child: const MaterialApp(
        home: Scaffold(body: RequesterProfileSheet(userId: _testUserId)),
      ),
    ),
  );
  // One pump to build the widget tree with the pre-set state.
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    // DateFormat.yMMMM('en') used in _LoadedBody requires locale data to be
    // initialized. In a running Flutter app the framework handles this; tests
    // must do it explicitly.
    await initializeDateFormatting('en');
  });

  group('RequesterProfileSheet', () {
    // -----------------------------------------------------------------------
    // 1. Loaded: display name + member-since text
    // -----------------------------------------------------------------------
    testWidgets('loaded state renders display name and Member since text', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        AsyncData(
          _makeProfile(
            displayName: 'Alice Tan',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ),
      );

      expect(find.text('Alice Tan'), findsOneWidget);
      // DateFormat.yMMMM('en').format(DateTime.utc(2026, 1, 1)) = "January 2026"
      expect(find.textContaining('Member since January 2026'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. Error state: BannerMessage with retry
    // -----------------------------------------------------------------------
    testWidgets('error state renders BannerMessage with Retry', (tester) async {
      await _pumpSheet(
        tester,
        const AsyncError(NetworkFailure('timeout'), StackTrace.empty),
      );

      expect(find.byType(BannerMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 3. Loading state: no display name
    // -----------------------------------------------------------------------
    testWidgets('loading state does not render any display name', (
      tester,
    ) async {
      await _pumpSheet(tester, const AsyncLoading());

      expect(find.text('Alice Tan'), findsNothing);
      expect(find.textContaining('Member since'), findsNothing);
      expect(find.byType(BannerMessage), findsNothing);
    });
  });
}
