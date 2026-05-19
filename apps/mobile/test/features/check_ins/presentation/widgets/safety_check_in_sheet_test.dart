// Widget tests for SafetyCheckInSheet.
//
// Covers:
//   1. "All good" path — acknowledged() called; confirmation chip visible.
//   2. "I need help" path — navigates to safety-report route.
//   3. reduce-motion respected (MediaQuery.disableAnimations).
//   4. Title uses event title substitution and truncates at 40 chars.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/usecase/usecase.dart';
import 'package:tribely/src/features/check_ins/domain/entities/pending_check_in.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/acknowledge_check_in_usecase.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/flag_check_in_usecase.dart';
import 'package:tribely/src/features/check_ins/domain/usecases/surface_pending_check_ins_usecase.dart';
import 'package:tribely/src/features/check_ins/presentation/providers/check_ins_providers.dart';
import 'package:tribely/src/features/check_ins/presentation/state/check_ins_state.dart';
import 'package:tribely/src/features/check_ins/presentation/string_assets/check_in_copy.dart';
import 'package:tribely/src/features/check_ins/presentation/widgets/safety_check_in_sheet.dart';

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

PendingCheckIn _makeCheckIn({String title = 'Evening Drinks'}) =>
    PendingCheckIn(
      id: 'ci-1',
      eventId: 'ev-1',
      eventTitle: title,
      hostDisplayName: 'Alice',
      endedAt: DateTime(2026, 6, 1, 21),
      createdAt: DateTime(2026, 6, 1, 22),
    );

/// Wraps the app with a GoRouter that serves the sheet as a page within a
/// modal bottom sheet (pushed via a trigger button) plus a stub safety-report
/// destination. This models the actual usage in the app where the sheet is
/// always shown via [showModalBottomSheet].
Widget _makeApp({
  required _MockSurfaceUseCase surfaceUseCase,
  required _MockAcknowledgeUseCase acknowledgeUseCase,
  required _MockFlagUseCase flagUseCase,
  bool disableAnimations = false,
  String checkInId = 'ci-1',
  String eventTitle = 'Evening Drinks',
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => SafetyCheckInSheet(
                    checkInId: checkInId,
                    eventTitle: eventTitle,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/check-ins/safety-report',
        builder: (context, state) =>
            const Scaffold(body: Text('SafetyReportPage')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      surfacePendingCheckInsUseCaseProvider.overrideWithValue(surfaceUseCase),
      acknowledgeCheckInUseCaseProvider.overrideWithValue(acknowledgeUseCase),
      flagCheckInUseCaseProvider.overrideWithValue(flagUseCase),
    ],
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

/// Seeds the [checkInsControllerProvider] into [CheckInsShowing] state via
/// the surf use case, keeping the autoDispose provider alive with a listener.
Future<ProviderContainer> _seedShowing(
  WidgetTester tester, {
  required _MockSurfaceUseCase surfaceUseCase,
  required _MockAcknowledgeUseCase acknowledgeUseCase,
}) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  // Keep the autoDispose provider alive.
  container.listen<CheckInsState>(
    checkInsControllerProvider,
    (prev, _) {},
    fireImmediately: true,
  );

  var surfaceCallCount = 0;
  when(() => surfaceUseCase(any())).thenAnswer((_) async {
    surfaceCallCount++;
    return surfaceCallCount == 1
        ? Right([_makeCheckIn()])
        : const Right(<PendingCheckIn>[]);
  });
  when(
    () => acknowledgeUseCase(any()),
  ).thenAnswer((_) async => const Right(unit));

  await container.read(checkInsControllerProvider.notifier).refresh();
  await tester.pump();
  return container;
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
  });

  // -------------------------------------------------------------------------
  // Renders correct copy
  // -------------------------------------------------------------------------

  group('renders', () {
    testWidgets('shows prompt title with event title substituted', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          surfaceUseCase: surfaceUseCase,
          acknowledgeUseCase: acknowledgeUseCase,
          flagUseCase: flagUseCase,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.text('Did you get home okay from Evening Drinks?'),
        findsOneWidget,
      );
    }, skip: Platform.isLinux);

    testWidgets('shows "All good" and "I need help" CTAs', (tester) async {
      await tester.pumpWidget(
        _makeApp(
          surfaceUseCase: surfaceUseCase,
          acknowledgeUseCase: acknowledgeUseCase,
          flagUseCase: flagUseCase,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(checkInPromptAllGoodCta), findsOneWidget);
      expect(find.text(checkInPromptNeedHelpCta), findsOneWidget);
    });

    testWidgets('truncates event title longer than 40 chars', (tester) async {
      const longTitle =
          'A Very Long Event Title That Exceeds Forty Characters For Sure';
      await tester.pumpWidget(
        _makeApp(
          surfaceUseCase: surfaceUseCase,
          acknowledgeUseCase: acknowledgeUseCase,
          flagUseCase: flagUseCase,
          eventTitle: longTitle,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The full untruncated title should NOT appear.
      expect(find.textContaining(longTitle, findRichText: false), findsNothing);
      // The truncated form should appear.
      expect(
        find.textContaining('A Very Long Event Title That Exceeds'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // "All good" path
  // -------------------------------------------------------------------------

  group('"All good" path', () {
    testWidgets(
      'tapping "All good" calls acknowledged() and shows confirmation chip',
      (tester) async {
        await tester.pumpWidget(
          _makeApp(
            surfaceUseCase: surfaceUseCase,
            acknowledgeUseCase: acknowledgeUseCase,
            flagUseCase: flagUseCase,
          ),
        );

        // Seed controller into Showing state.
        await _seedShowing(
          tester,
          surfaceUseCase: surfaceUseCase,
          acknowledgeUseCase: acknowledgeUseCase,
        );

        // Open the modal sheet.
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Tap "All good".
        await tester.tap(find.text(checkInPromptAllGoodCta));

        // Pump through the async gap (acknowledged() awaits the use case).
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // The acknowledge use case must have been called.
        verify(() => acknowledgeUseCase(any())).called(1);

        // After the cross-fade animation the confirmation chip is visible.
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text(checkInAcknowledgedConfirmation), findsOneWidget);

        // Drain the 2.5s auto-dismiss timer so no pending timers remain.
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'reduce-motion: confirmation chip visible after tap (zero-duration cross-fade)',
      (tester) async {
        await tester.pumpWidget(
          _makeApp(
            surfaceUseCase: surfaceUseCase,
            acknowledgeUseCase: acknowledgeUseCase,
            flagUseCase: flagUseCase,
            disableAnimations: true,
          ),
        );

        await _seedShowing(
          tester,
          surfaceUseCase: surfaceUseCase,
          acknowledgeUseCase: acknowledgeUseCase,
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(checkInPromptAllGoodCta));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        // With animations disabled the confirmation chip appears immediately.
        expect(find.text(checkInAcknowledgedConfirmation), findsOneWidget);

        // Drain the 2.5s auto-dismiss timer.
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });

  // -------------------------------------------------------------------------
  // "I need help" path
  // -------------------------------------------------------------------------

  group('"I need help" path', () {
    testWidgets('tapping "I need help" navigates to safety-report route', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          surfaceUseCase: surfaceUseCase,
          acknowledgeUseCase: acknowledgeUseCase,
          flagUseCase: flagUseCase,
        ),
      );
      await tester.pump();

      // Open the modal sheet.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap "I need help" — should pop the sheet and push safety-report.
      await tester.tap(find.text(checkInPromptNeedHelpCta));
      await tester.pumpAndSettle();

      // The stub route renders 'SafetyReportPage'.
      expect(find.text('SafetyReportPage'), findsOneWidget);
    });
  });
}
