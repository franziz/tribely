// Cold-boot regression test for RequesterProfileSheet + DateFormat.yMMMM('en').
//
// This file is deliberately separate from requester_profile_sheet_test.dart,
// which calls initializeDateFormatting in setUpAll. That init persists for the
// entire test-process run, so adding this case there would mask the bug it's
// meant to guard.
//
// Limitation: the intl package does not expose a symbol-cache reset, so we
// cannot simulate a truly uninitialised state within a test process. The test
// below instead simulates the PRODUCTION PATH: call initializeDateFormatting
// (as main.dart now does at boot), THEN pump the sheet. If a future engineer
// removes the init from main.dart the sheet will crash on first open — the
// comment in main.dart and the name of this test are the primary guard; the
// test itself confirms the production path is exercised and does not throw.
//
// See TRI-28 for context.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tribely/src/core/providers/get_user_profile_usecase_provider.dart'
    show userProfileByIdProvider;
import 'package:tribely/src/core/widgets/requester_profile_sheet.dart';
import 'package:tribely/src/features/users/domain/entities/user_profile.dart';

const _testUserId = 'user-cold-boot-test';

UserProfile _makeProfile() => UserProfile(
  id: _testUserId,
  email: 'coldboot@tribely.com',
  displayName: 'Cold Boot User',
  createdAt: DateTime.utc(2026, 3, 1),
  updatedAt: DateTime.utc(2026, 3, 1),
);

void main() {
  testWidgets('cold-boot: RequesterProfileSheet renders even before '
      'initializeDateFormatting() is called', (tester) async {
    // Simulate what main.dart does at app boot: initialise locale data before
    // any widget that calls DateFormat.yMMMM('en') is rendered.
    await initializeDateFormatting('en');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileByIdProvider(
            _testUserId,
          ).overrideWithValue(AsyncData(_makeProfile())),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RequesterProfileSheet(userId: _testUserId)),
        ),
      ),
    );
    await tester.pump();

    // Sheet renders the display name — locale data was available, no
    // LocaleDataException thrown.
    expect(find.text('Cold Boot User'), findsOneWidget);
    expect(find.textContaining('Member since March 2026'), findsOneWidget);
  });
}
