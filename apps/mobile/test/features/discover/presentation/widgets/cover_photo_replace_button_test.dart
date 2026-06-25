// Widget tests for CoverPhotoReplaceButton (TRI-306 Brief 3).
//
// Covers:
//   1. Idle state — camera button renders with correct semantics.
//   2. Uploading state — camera button is suppressed; uploading overlay visible.
//   3. Failed state — failure banner visible with Retry action; button absent.
//   4. Success state — camera button re-renders (controller resets to Idle).
//   5. Host-only gate — CoverPhotoReplaceButton absent when not included
//      (gate is on the caller; tested via event_detail_page gating in group 2).
//
// Mocking strategy:
//   - [replaceCoverPhotoControllerProvider] overridden per test via
//     ProviderScope.overrides with a fixed-state controller.
//   - No GetIt / service locator initialised — fully hermetic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/discover/presentation/controllers/replace_cover_photo_controller.dart';
import 'package:tribely/src/features/discover/presentation/state/replace_cover_photo_state.dart';
import 'package:tribely/src/features/discover/presentation/widgets/cover_photo_replace_button.dart';

// ---------------------------------------------------------------------------
// Fixed-state controller helpers
// ---------------------------------------------------------------------------

class _FixedReplaceController extends ReplaceCoverPhotoController {
  _FixedReplaceController(super.eventId, this._state);

  final ReplaceCoverPhotoState _state;

  @override
  ReplaceCoverPhotoState build() => _state;

  @override
  Future<void> replaceCoverPhoto(_) async {}

  @override
  void clearFailure() {
    state = const ReplaceCoverPhotoIdle();
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

const _testEventId = 'evt-replace-001';

Future<void> _pumpWidget(
  WidgetTester tester, {
  required ReplaceCoverPhotoState controllerState,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Per Riverpod 3.x pattern: per-instance family override uses .overrideWith().
        // .overrideWith2() is for whole-family overrides on the un-instanced provider.
        replaceCoverPhotoControllerProvider(_testEventId).overrideWith(
          () => _FixedReplaceController(_testEventId, controllerState),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              // Simulate the hero Stack context.
              SizedBox(width: 400, height: 225),
              CoverPhotoReplaceButton(eventId: _testEventId),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CoverPhotoReplaceButton', () {
    // -----------------------------------------------------------------------
    // 1. Idle state
    // -----------------------------------------------------------------------

    testWidgets('idle state renders camera button with semantic label', (
      tester,
    ) async {
      await _pumpWidget(tester, controllerState: const ReplaceCoverPhotoIdle());

      // Camera icon must be present.
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);

      // Semantic label "Replace cover photo" must be exposed (AC: screen-reader
      // accessible).
      expect(find.bySemanticsLabel('Replace cover photo'), findsOneWidget);
    });

    testWidgets('idle state: uploading overlay and failure banner are absent', (
      tester,
    ) async {
      await _pumpWidget(tester, controllerState: const ReplaceCoverPhotoIdle());

      expect(find.text('Updating cover photo…'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // BannerMessage is not imported here; check for 'Retry' text instead.
      expect(find.text('Retry'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 2. Uploading state
    // -----------------------------------------------------------------------

    testWidgets(
      'uploading state renders progress indicator and caption; camera button absent',
      (tester) async {
        await _pumpWidget(
          tester,
          controllerState: const ReplaceCoverPhotoUploading(progress: 0.4),
        );

        // Progress strip visible.
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        // Caption visible.
        expect(find.text('Updating cover photo…'), findsOneWidget);
        // Camera button absent during upload (AC: button suppressed).
        expect(find.byIcon(Icons.camera_alt), findsNothing);
        expect(find.bySemanticsLabel('Replace cover photo'), findsNothing);
      },
    );

    testWidgets(
      'uploading state with null progress (indeterminate) still renders indicator',
      (tester) async {
        await _pumpWidget(
          tester,
          controllerState: const ReplaceCoverPhotoUploading(progress: null),
        );

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        // null value = indeterminate.
        expect(indicator.value, isNull);
      },
    );

    testWidgets(
      'uploading state with determinate progress wires the value correctly',
      (tester) async {
        await _pumpWidget(
          tester,
          controllerState: const ReplaceCoverPhotoUploading(progress: 0.75),
        );

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, closeTo(0.75, 0.001));
      },
    );

    // -----------------------------------------------------------------------
    // 3. Failed state
    // -----------------------------------------------------------------------

    testWidgets(
      'failed state renders failure message and Retry action; camera button absent',
      (tester) async {
        await _pumpWidget(
          tester,
          controllerState: const ReplaceCoverPhotoFailed(
            failure: NetworkFailure('No internet connection.'),
          ),
        );

        // Failure message visible.
        expect(find.text('No internet connection.'), findsOneWidget);
        // Retry action visible.
        expect(find.text('Retry'), findsOneWidget);
        // Camera button absent while in failed state.
        expect(find.byIcon(Icons.camera_alt), findsNothing);
        expect(find.bySemanticsLabel('Replace cover photo'), findsNothing);
        // Uploading overlay absent.
        expect(find.text('Updating cover photo…'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'failed state: tapping Retry clears failure and renders camera button',
      (tester) async {
        await _pumpWidget(
          tester,
          controllerState: const ReplaceCoverPhotoFailed(
            failure: ServerFailure('Server error.', statusCode: 500),
          ),
        );

        // Retry button is present.
        expect(find.text('Retry'), findsOneWidget);

        // Tap Retry — the fixed controller's clearFailure() sets state to Idle.
        await tester.tap(find.text('Retry'));
        await tester.pump();

        // Camera button should now be visible again.
        expect(find.byIcon(Icons.camera_alt), findsOneWidget);
        // Failure message gone.
        expect(find.text('Server error.'), findsNothing);
      },
    );

    testWidgets('failed state with empty message falls back to default copy', (
      tester,
    ) async {
      await _pumpWidget(
        tester,
        controllerState: const ReplaceCoverPhotoFailed(
          failure: NetworkFailure(''),
        ),
      );

      // Fallback copy is shown when failure.message is empty.
      expect(find.text('Cover photo update failed.'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 4. Success state — camera button re-renders
    // -----------------------------------------------------------------------

    testWidgets(
      'success state renders camera button (controller resets to Idle on page listen)',
      (tester) async {
        // Success is a transient state — in production the page's ref.listen
        // immediately calls handleReplaceCoverPhotoSuccess and the controller
        // is reset. In isolation, CoverPhotoReplaceButton treats Success the
        // same as Idle (falls through the switch _ branch) and renders the
        // camera button.
        await _pumpWidget(
          tester,
          controllerState: const ReplaceCoverPhotoSuccess(),
        );

        // Camera button visible in success state (same as idle — transient).
        expect(find.byIcon(Icons.camera_alt), findsOneWidget);
        // No failure or uploading UI.
        expect(find.text('Retry'), findsNothing);
        expect(find.text('Updating cover photo…'), findsNothing);
      },
    );
  });

  // -------------------------------------------------------------------------
  // CoverPhotoCrossFade
  // -------------------------------------------------------------------------

  group('CoverPhotoCrossFade', () {
    testWidgets('renders child correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CoverPhotoCrossFade(
              imageKey: ValueKey('test-key'),
              child: Text('hero-child'),
            ),
          ),
        ),
      );
      expect(find.text('hero-child'), findsOneWidget);
    });

    testWidgets('changes imageKey cross-fades to new child', (tester) async {
      String coverUrl = 'url-A';

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    CoverPhotoCrossFade(
                      imageKey: ValueKey(coverUrl),
                      child: Text('cover-$coverUrl'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => coverUrl = 'url-B'),
                      child: const Text('change'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('cover-url-A'), findsOneWidget);

      await tester.tap(find.text('change'));
      await tester.pump(); // start transition
      await tester.pump(const Duration(milliseconds: 300)); // complete

      expect(find.text('cover-url-B'), findsOneWidget);
    });
  });
}
