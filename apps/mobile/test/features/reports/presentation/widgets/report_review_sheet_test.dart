// Widget tests for ReportReviewSheet.
//
// Covers:
//   1. Submit button disabled until a reason is selected.
//   2. Tapping a reason radio enables the submit button.
//   3. All 7 reason options render with correct user-facing copy.
//   4. Submit calls the use case (mocked controller override).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/widgets/primary_button.dart';
import 'package:tribely/src/features/reports/domain/entities/report.dart';
import 'package:tribely/src/features/reports/domain/entities/report_reason.dart';
import 'package:tribely/src/features/reports/domain/usecases/file_report_usecase.dart';
import 'package:tribely/src/features/reports/presentation/providers/reports_providers.dart';
import 'package:tribely/src/features/reports/presentation/widgets/report_review_sheet.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFileReportUseCase extends Mock implements FileReportUseCase {}

class FakeFileReportParams extends Fake implements FileReportParams {}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

Report _fakeReport() => Report(
  id: 'rpt-1',
  reporterUserId: 'user-a',
  targetType: 'review',
  targetId: 'rev-1',
  reason: ReportReason.spam,
  createdAt: DateTime(2026, 5, 1),
);

// ---------------------------------------------------------------------------
// Helper — pumps the sheet inline (not via showModalBottomSheet) so
// ProviderScope overrides work correctly in tests.
// ---------------------------------------------------------------------------

Future<void> _pumpSheet(
  WidgetTester tester, {
  MockFileReportUseCase? useCase,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (useCase != null)
          fileReportUseCaseProvider.overrideWithValue(useCase),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ReportReviewSheet(
            reviewId: 'rev-1',
            reportedUserId: 'user-b',
            reportedUserDisplayName: 'Alex',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeFileReportParams());
  });

  group('ReportReviewSheet — initial state', () {
    testWidgets('submit button is disabled when no reason selected', (
      tester,
    ) async {
      await _pumpSheet(tester);

      final button = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Submit report'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('all 7 reason options are rendered', (tester) async {
      await _pumpSheet(tester);

      for (final reason in ReportReason.values) {
        expect(
          find.text(reason.displayString),
          findsOneWidget,
          reason:
              'Expected to find "${reason.displayString}" for reason ${reason.name}',
        );
      }
    });

    testWidgets('reason copy matches enum mapping', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('Harassment or threats'), findsOneWidget);
      expect(find.text('Hate speech or discrimination'), findsOneWidget);
      expect(find.text('Sexual content'), findsOneWidget);
      expect(find.text('Sharing personal information'), findsOneWidget);
      expect(find.text('False or misleading information'), findsOneWidget);
      expect(find.text('Spam'), findsOneWidget);
      expect(find.text('Something else'), findsOneWidget);
    });
  });

  group('ReportReviewSheet — reason selection enables submit', () {
    testWidgets('tapping a reason row enables the submit button', (
      tester,
    ) async {
      final useCase = MockFileReportUseCase();
      when(() => useCase(any())).thenAnswer((_) async => Right(_fakeReport()));

      await _pumpSheet(tester, useCase: useCase);

      // Submit is disabled before selection.
      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'Submit report'),
            )
            .onPressed,
        isNull,
      );

      // Tap the 'Spam' reason row.
      await tester.tap(find.text('Spam'));
      await tester.pump();

      // Submit should now be enabled.
      final btnAfter = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Submit report'),
      );
      expect(btnAfter.onPressed, isNotNull);
    });
  });

  group('ReportReviewSheet — submit calls use case', () {
    testWidgets('selecting a reason and submitting transitions to Submitting', (
      tester,
    ) async {
      // Verify the controller enters Submitting state (proving the use case
      // was invoked) without relying on Navigator.pop teardown in a bare
      // Scaffold. The controller unit test verifies the full Idle→Success path.
      final useCase = MockFileReportUseCase();
      // Hold the future open so we can assert Submitting state mid-flight.
      final completer = Completer<Either<Failure, Report>>();
      when(() => useCase(any())).thenAnswer((_) async => completer.future);

      await _pumpSheet(tester, useCase: useCase);

      // Select a reason.
      await tester.tap(find.text('Spam'));
      await tester.pump();

      // Scroll to ensure submit button is visible.
      await tester.ensureVisible(
        find.widgetWithText(PrimaryButton, 'Submit report'),
      );

      // Tap submit.
      await tester.tap(find.widgetWithText(PrimaryButton, 'Submit report'));
      await tester.pump();

      // Controller should be Submitting — proves use case was invoked.
      verify(() => useCase(any())).called(1);

      // Clean up — complete the future so no dangling async.
      completer.complete(Right(_fakeReport()));
      await tester.pump();
    });
  });
}
