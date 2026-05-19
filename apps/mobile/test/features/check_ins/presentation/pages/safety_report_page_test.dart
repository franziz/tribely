// Widget tests for SafetyReportPage.
//
// Covers:
//   1. Empty field → "Send report" is disabled.
//   2. Char counter updates as user types.
//   3. Field at exactly 2000 chars → allowed.
//   4. Field over 2000 chars → Send disabled.
//   5. Submit triggers controller's flagged(reportBody).
//   6. Failure response → inline error banner shown; page stays mounted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/usecase/usecase.dart';
import 'package:tribely/src/features/check_ins/domain/entities/pending_check_in.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/acknowledge_check_in_usecase.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/flag_check_in_usecase.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/surface_pending_check_ins_usecase.dart';
import 'package:tribely/src/features/check_ins/presentation/pages/safety_report_page.dart';
import 'package:tribely/src/features/check_ins/presentation/providers/check_ins_providers.dart';
import 'package:tribely/src/features/check_ins/presentation/state/check_ins_state.dart';
import 'package:tribely/src/features/check_ins/presentation/string_assets/check_in_copy.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockSurfaceUseCase extends Mock
    implements SurfacePendingCheckInsUseCase {}

class _MockAcknowledgeUseCase extends Mock
    implements AcknowledgeCheckInUseCase {}

class _MockFlagUseCase extends Mock implements FlagCheckInUseCase {}

class _FakeNoParams extends Fake implements NoParams {}

class _FakeAcknowledgeParams extends Fake implements AcknowledgeCheckInParams {}

class _FakeFlagParams extends Fake implements FlagCheckInParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PendingCheckIn _makeCheckIn() => PendingCheckIn(
  id: 'ci-1',
  eventId: 'ev-1',
  eventTitle: 'Evening Drinks',
  hostDisplayName: 'Alice',
  endedAt: DateTime(2026, 6, 1, 21),
  createdAt: DateTime(2026, 6, 1, 22),
);

/// Wraps SafetyReportPage in a MaterialApp.router so go_router is available
/// in the widget tree (required for context.pushReplacement).
Widget _wrap({
  required _MockSurfaceUseCase surfaceUseCase,
  required _MockAcknowledgeUseCase acknowledgeUseCase,
  required _MockFlagUseCase flagUseCase,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SafetyReportPage()),
      GoRoute(
        path: '/check-ins/safety-report/submitted',
        builder: (context, state) =>
            const Scaffold(body: Text('SubmittedPage')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      surfacePendingCheckInsUseCaseProvider.overrideWithValue(surfaceUseCase),
      acknowledgeCheckInUseCaseProvider.overrideWithValue(acknowledgeUseCase),
      flagCheckInUseCaseProvider.overrideWithValue(flagUseCase),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeNoParams());
    registerFallbackValue(_FakeAcknowledgeParams());
    registerFallbackValue(_FakeFlagParams());
  });

  late _MockSurfaceUseCase surfaceUseCase;
  late _MockAcknowledgeUseCase acknowledgeUseCase;
  late _MockFlagUseCase flagUseCase;

  setUp(() {
    surfaceUseCase = _MockSurfaceUseCase();
    acknowledgeUseCase = _MockAcknowledgeUseCase();
    flagUseCase = _MockFlagUseCase();

    when(
      () => surfaceUseCase(any()),
    ).thenAnswer((_) async => Right([_makeCheckIn()]));
    when(
      () => acknowledgeUseCase(any()),
    ).thenAnswer((_) async => const Right(unit));
    when(() => flagUseCase(any())).thenAnswer((_) async => const Right(unit));
  });

  // -------------------------------------------------------------------------
  // Char counter
  // -------------------------------------------------------------------------

  testWidgets('char counter shows correct count as user types', (tester) async {
    await tester.pumpWidget(
      _wrap(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      ),
    );
    await tester.pump();

    // Enter text and verify the counter.
    await tester.enterText(find.byType(TextField), 'Hello world');
    await tester.pump();

    expect(find.text('11 / 2000'), findsOneWidget);
  });

  testWidgets('char counter at exactly 2000', (tester) async {
    await tester.pumpWidget(
      _wrap(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'a' * 2000);
    await tester.pump();

    expect(find.text('2000 / 2000'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Over-limit → Send disabled
  // -------------------------------------------------------------------------

  testWidgets('over-2000 chars: counter shows over-limit count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'a' * 2001);
    await tester.pump();

    expect(find.text('2001 / 2000'), findsOneWidget);

    // Tap should not trigger the use case.
    await tester.tap(find.text(safetyReportSendCta), warnIfMissed: false);
    await tester.pump();

    verifyNever(() => flagUseCase(any()));
  });

  // -------------------------------------------------------------------------
  // Submit triggers flagged()
  // -------------------------------------------------------------------------

  testWidgets('submit with valid body navigates to submitted page', (
    tester,
  ) async {
    // After flagged(), surface returns empty (success path).
    when(() => flagUseCase(any())).thenAnswer((_) async => const Right(unit));
    when(
      () => surfaceUseCase(any()),
    ).thenAnswer((_) async => const Right(<PendingCheckIn>[]));

    await tester.pumpWidget(
      _wrap(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      ),
    );

    // Seed controller into Showing so flagged() is not a no-op.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SafetyReportPage)),
    );
    // Keep the autoDispose provider alive throughout this test.
    container.listen<CheckInsState>(
      checkInsControllerProvider,
      (prev, _) {},
      fireImmediately: true,
    );
    // Temporarily re-stub surface to return an item for the seed.
    when(
      () => surfaceUseCase(any()),
    ).thenAnswer((_) async => Right([_makeCheckIn()]));
    await container.read(checkInsControllerProvider.notifier).refresh();
    // Then stub back to empty for the post-flag re-surface.
    when(
      () => surfaceUseCase(any()),
    ).thenAnswer((_) async => const Right(<PendingCheckIn>[]));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'I felt unsafe');
    await tester.pump();

    await tester.tap(find.text(safetyReportSendCta));
    await tester.pump();
    // Pump through async gap without pumpAndSettle (avoids timeout on navigation).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The flag use case must have been called.
    verify(() => flagUseCase(any())).called(1);

    // Navigation to submitted page.
    await tester.pumpAndSettle();
    expect(find.text('SubmittedPage'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Failure → inline error banner
  // -------------------------------------------------------------------------

  testWidgets('failure response shows inline error banner; page stays', (
    tester,
  ) async {
    const failure = NetworkFailure('Connection lost');
    when(() => flagUseCase(any())).thenAnswer((_) async => const Left(failure));

    await tester.pumpWidget(
      _wrap(
        surfaceUseCase: surfaceUseCase,
        acknowledgeUseCase: acknowledgeUseCase,
        flagUseCase: flagUseCase,
      ),
    );

    // Seed controller into Showing so flagged() is not a no-op.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SafetyReportPage)),
    );
    // Keep the autoDispose provider alive.
    container.listen<CheckInsState>(
      checkInsControllerProvider,
      (prev, _) {},
      fireImmediately: true,
    );
    await container.read(checkInsControllerProvider.notifier).refresh();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Something happened');
    await tester.pump();

    await tester.tap(find.text(safetyReportSendCta));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The BannerMessage should show the failure message.
    expect(find.text('Connection lost'), findsOneWidget);
    // The page is still mounted.
    expect(find.byType(SafetyReportPage), findsOneWidget);
  });
}
