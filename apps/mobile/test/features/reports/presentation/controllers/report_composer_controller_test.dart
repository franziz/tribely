import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/reports/domain/entities/report.dart';
import 'package:tribely/src/features/reports/domain/entities/report_reason.dart';
import 'package:tribely/src/features/reports/domain/usecases/file_report_usecase.dart';
import 'package:tribely/src/features/reports/presentation/providers/reports_providers.dart';
import 'package:tribely/src/features/reports/presentation/state/report_composer_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFileReportUseCase extends Mock implements FileReportUseCase {}

// ---------------------------------------------------------------------------
// Fake registrations
// ---------------------------------------------------------------------------

class FakeFileReportParams extends Fake implements FileReportParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Report _fakeReport() => Report(
  id: 'rpt-1',
  reporterUserId: 'user-a',
  targetType: 'review',
  targetId: 'rev-1',
  reason: ReportReason.spam,
  createdAt: DateTime(2026, 5, 1),
);

Future<void> _pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _makeContainer({required MockFileReportUseCase useCase}) {
  final container = ProviderContainer(
    overrides: [fileReportUseCaseProvider.overrideWithValue(useCase)],
  );
  // Keep autoDispose provider alive for the test duration.
  container.listen(reportComposerControllerProvider, (prev, next) {});
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeFileReportParams());
  });

  late MockFileReportUseCase useCase;

  setUp(() {
    useCase = MockFileReportUseCase();
  });

  group('submit — Idle → Submitting → Success', () {
    test(
      'transitions Idle → Submitting → Success on successful submit',
      () async {
        // Use a Completer so the Submitting state is observable mid-flight
        // before the future resolves (avoids a race with sync-resolving mocks).
        final completer = Completer<Either<Failure, Report>>();
        when(() => useCase(any())).thenAnswer((_) async => completer.future);

        final container = _makeContainer(useCase: useCase);

        expect(
          container.read(reportComposerControllerProvider),
          isA<ReportComposerIdle>(),
        );

        unawaited(
          container
              .read(reportComposerControllerProvider.notifier)
              .submit(
                targetType: 'review',
                targetId: 'rev-1',
                reason: ReportReason.spam,
              ),
        );

        // Yield once — future is held open by completer, so state is Submitting.
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(reportComposerControllerProvider),
          isA<ReportComposerSubmitting>(),
        );

        // Complete the future → state should transition to Success.
        completer.complete(Right(_fakeReport()));
        await _pump();
        final state = container.read(reportComposerControllerProvider);
        expect(state, isA<ReportComposerSuccess>());
        expect((state as ReportComposerSuccess).report.id, 'rpt-1');
      },
    );

    test('calls use case with correct params', () async {
      when(() => useCase(any())).thenAnswer((_) async => Right(_fakeReport()));

      final container = _makeContainer(useCase: useCase);
      await container
          .read(reportComposerControllerProvider.notifier)
          .submit(
            targetType: 'review',
            targetId: 'rev-42',
            reason: ReportReason.harassment,
            comment: 'Test comment',
          );

      final captured = verify(() => useCase(captureAny())).captured;
      expect(captured, hasLength(1));
      final params = captured.first as FileReportParams;
      expect(params.targetType, 'review');
      expect(params.targetId, 'rev-42');
      expect(params.reason, ReportReason.harassment);
      expect(params.comment, 'Test comment');
    });
  });

  group('submit — Failure transitions', () {
    test(
      'transitions to Failure with user-friendly message on NetworkFailure',
      () async {
        when(
          () => useCase(any()),
        ).thenAnswer((_) async => const Left(NetworkFailure('No connection')));

        final container = _makeContainer(useCase: useCase);
        await container
            .read(reportComposerControllerProvider.notifier)
            .submit(
              targetType: 'review',
              targetId: 'rev-1',
              reason: ReportReason.spam,
            );

        final state = container.read(reportComposerControllerProvider);
        expect(state, isA<ReportComposerFailure>());
        expect(
          (state as ReportComposerFailure).message,
          contains("Couldn't reach Tribely"),
        );
      },
    );

    test(
      'transitions to Failure with TargetNotFoundFailure-specific message',
      () async {
        when(() => useCase(any())).thenAnswer(
          (_) async => const Left(TargetNotFoundFailure('Review not found')),
        );

        final container = _makeContainer(useCase: useCase);
        await container
            .read(reportComposerControllerProvider.notifier)
            .submit(
              targetType: 'review',
              targetId: 'rev-1',
              reason: ReportReason.harassment,
            );

        final state = container.read(reportComposerControllerProvider);
        expect(state, isA<ReportComposerFailure>());
        expect(
          (state as ReportComposerFailure).message,
          contains('no longer exists'),
        );
      },
    );

    test('preserves selected reason in Failure state', () async {
      when(
        () => useCase(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));

      final container = _makeContainer(useCase: useCase);
      await container
          .read(reportComposerControllerProvider.notifier)
          .submit(
            targetType: 'review',
            targetId: 'rev-1',
            reason: ReportReason.hateSpeech,
          );

      final state = container.read(reportComposerControllerProvider);
      expect(state, isA<ReportComposerFailure>());
      expect((state as ReportComposerFailure).reason, ReportReason.hateSpeech);
    });

    test(
      'transitions to Failure with TargetTypeNotImplementedFailure message',
      () async {
        when(() => useCase(any())).thenAnswer(
          (_) async => const Left(
            TargetTypeNotImplementedFailure('Target type not supported'),
          ),
        );

        final container = _makeContainer(useCase: useCase);
        await container
            .read(reportComposerControllerProvider.notifier)
            .submit(
              targetType: 'message',
              targetId: 'msg-1',
              reason: ReportReason.spam,
            );

        final state = container.read(reportComposerControllerProvider);
        expect(state, isA<ReportComposerFailure>());
        expect(
          (state as ReportComposerFailure).message,
          contains('not yet supported'),
        );
      },
    );
  });

  group('double-submit guard', () {
    test('ignores second submit while Submitting', () async {
      final completer = Completer<Either<Failure, Report>>();
      when(() => useCase(any())).thenAnswer((_) async => completer.future);

      final container = _makeContainer(useCase: useCase);

      // First submit — in flight.
      unawaited(
        container
            .read(reportComposerControllerProvider.notifier)
            .submit(
              targetType: 'review',
              targetId: 'rev-1',
              reason: ReportReason.spam,
            ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(reportComposerControllerProvider),
        isA<ReportComposerSubmitting>(),
      );

      // Second submit — should be a no-op.
      await container
          .read(reportComposerControllerProvider.notifier)
          .submit(
            targetType: 'review',
            targetId: 'rev-1',
            reason: ReportReason.spam,
          );

      // Use case called exactly once.
      verify(() => useCase(any())).called(1);

      completer.complete(Right(_fakeReport()));
      await _pump();
    });
  });

  group('reset', () {
    test('reset returns to Idle from Failure', () async {
      when(
        () => useCase(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));

      final container = _makeContainer(useCase: useCase);
      await container
          .read(reportComposerControllerProvider.notifier)
          .submit(
            targetType: 'review',
            targetId: 'rev-1',
            reason: ReportReason.spam,
          );

      expect(
        container.read(reportComposerControllerProvider),
        isA<ReportComposerFailure>(),
      );

      container.read(reportComposerControllerProvider.notifier).reset();
      expect(
        container.read(reportComposerControllerProvider),
        isA<ReportComposerIdle>(),
      );
    });
  });
}
