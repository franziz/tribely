// Widget tests for RequesterProfileSheet — TRI-65 pill slot.
//
// Covers:
//   1. Pill present: VerifiedPill renders Icons.verified when isVerified=true.
//   2. Pill absent: Icons.verified is not in the tree when isVerified=false
//      (VerifiedPill short-circuits to SizedBox.shrink() per TRI-64 contract).
//   3. Layout preserved: display name and "Member since" copy both render
//      regardless of verification state (TRI-28 AC).
//
// Override strategy: [userProfileByIdProvider] is a FutureProvider.autoDispose
// .family<UserProfile, String>. Tests use [overrideWithValue(AsyncData(...))]
// to inject the loaded state synchronously — no async settling required.
// GetIt / service locator is never initialised; all DI is through overrides.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tribely/src/core/providers/get_user_profile_usecase_provider.dart'
    show userProfileByIdProvider;
import 'package:tribely/src/core/widgets/requester_profile_sheet.dart';
import 'package:tribely/src/core/widgets/verified_pill.dart';
import 'package:tribely/src/features/users/domain/entities/user_profile.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testUserId = 'user-tri65-test';

UserProfile _makeProfile({bool isVerified = false}) => UserProfile(
  id: _testUserId,
  email: 'tri65@tribely.com',
  displayName: 'Priya Sharma',
  createdAt: DateTime.utc(2026, 1, 15),
  updatedAt: DateTime.utc(2026, 1, 15),
  isVerified: isVerified,
);

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpSheet(WidgetTester tester, UserProfile profile) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileByIdProvider(
          _testUserId,
        ).overrideWithValue(AsyncData(profile)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: RequesterProfileSheet(userId: _testUserId)),
      ),
    ),
  );
  // One pump to build the widget tree with the pre-set synchronous state.
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    // DateFormat.yMMMM('en') used in _LoadedBody requires locale data.
    await initializeDateFormatting('en');
  });

  group('RequesterProfileSheet — TRI-65 VerifiedPill slot', () {
    // -------------------------------------------------------------------------
    // 1. Pill present when verified
    // -------------------------------------------------------------------------
    testWidgets(
      'renders VerifiedPill and Icons.verified when isVerified=true',
      (tester) async {
        await _pumpSheet(tester, _makeProfile(isVerified: true));

        expect(find.byType(VerifiedPill), findsOneWidget);
        expect(find.byIcon(Icons.verified), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // 2. Pill absent when not verified — no whitespace gap
    // -------------------------------------------------------------------------
    testWidgets('does not render Icons.verified when isVerified=false', (
      tester,
    ) async {
      await _pumpSheet(tester, _makeProfile(isVerified: false));

      // VerifiedPill widget is in the tree (Wrap child) but renders
      // SizedBox.shrink() — use the icon as the visibility oracle.
      expect(find.byIcon(Icons.verified), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 3a. TRI-28 layout preserved — verified
    // -------------------------------------------------------------------------
    testWidgets(
      'display name and Member since text render when isVerified=true',
      (tester) async {
        await _pumpSheet(tester, _makeProfile(isVerified: true));

        expect(find.text('Priya Sharma'), findsOneWidget);
        expect(find.textContaining('Member since'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // 3b. TRI-28 layout preserved — not verified
    // -------------------------------------------------------------------------
    testWidgets(
      'display name and Member since text render when isVerified=false',
      (tester) async {
        await _pumpSheet(tester, _makeProfile(isVerified: false));

        expect(find.text('Priya Sharma'), findsOneWidget);
        expect(find.textContaining('Member since'), findsOneWidget);
      },
    );
  });
}
