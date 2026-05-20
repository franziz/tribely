// Widget test for MyReviewsWrittenPage — go_router navigation regression.
//
// Fix #5 (TRI-30 architecture-reviewer): Navigator.of.pushNamed was replaced
// with context.push because go_router does NOT register routes into Flutter's
// named-route table. This test exercises the REAL go_router to prevent the
// same class of bug from regressing.
//
// Covers:
//   1. Tapping the edit link on a recent review navigates to /reviews/write
//      without throwing a RouteNotFoundException.
//   2. The navigation target includes the reviewId query param.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/features/reviews/domain/entities/review.dart';
import 'package:tribely/src/features/reviews/domain/entities/review_list_page.dart';
import 'package:tribely/src/features/reviews/domain/entities/review_visibility.dart';
import 'package:tribely/src/features/reviews/domain/usecases/list_reviews_written_by_me_usecase.dart';
import 'package:tribely/src/features/reviews/presentation/controllers/my_reviews_written_controller.dart';
import 'package:tribely/src/features/reviews/presentation/pages/my_reviews_written_page.dart';
import 'package:tribely/src/features/reviews/presentation/providers/review_providers.dart';
import 'package:tribely/src/features/reviews/presentation/state/my_reviews_written_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockListReviewsWrittenByMeUseCase extends Mock
    implements ListReviewsWrittenByMeUseCase {}

// ---------------------------------------------------------------------------
// Fake registrations
// ---------------------------------------------------------------------------

class FakeListReviewsWrittenByMeParams extends Fake
    implements ListReviewsWrittenByMeParams {}

// ---------------------------------------------------------------------------
// Stub controller — bypasses the async load; returns a fixed loaded state.
// ---------------------------------------------------------------------------

class _StubController extends MyReviewsWrittenController {
  _StubController(this._fixed);

  final MyReviewsWrittenState _fixed;

  @override
  MyReviewsWrittenState build() => _fixed;
}

// ---------------------------------------------------------------------------
// Test data — a single recent review (createdAt within 24h → canEdit=true).
// ---------------------------------------------------------------------------

final _kReview = Review(
  id: 'rev-001',
  eventId: 'evt-001',
  raterUserId: 'user-me',
  ratedUserId: 'user-them',
  rating: 4,
  comment: 'Great time!',
  createdAt: DateTime.now().subtract(const Duration(hours: 2)), // within 24h
  hidden: false,
);

final _kPage = ReviewListPage(rows: [ReviewVisible(review: _kReview)]);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Records the last path + query pushed onto the router so tests can assert it.
String? _lastPushedLocation;

GoRouter _buildRouter() {
  _lastPushedLocation = null;
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MyReviewsWrittenPage(),
      ),
      GoRoute(
        path: '/reviews/write',
        builder: (context, state) {
          _lastPushedLocation = state.uri.toString();
          return const Scaffold(body: Text('Review composer'));
        },
      ),
    ],
  );
}

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final stub = _StubController(MyReviewsWrittenLoaded(page: _kPage));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [myReviewsWrittenControllerProvider.overrideWith(() => stub)],
      child: MaterialApp.router(routerConfig: _buildRouter()),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeListReviewsWrittenByMeParams());
  });

  group('MyReviewsWrittenPage — go_router navigation', () {
    testWidgets(
      '1. Tapping edit link navigates to /reviews/write via go_router '
      '(no RouteNotFoundException)',
      (tester) async {
        await _pumpPage(tester);

        // The edit link renders as 'Edit' text inside ReviewRow when canEdit.
        final editFinder = find.text('Edit ›');
        expect(editFinder, findsOneWidget);

        // Tap the edit link — must not throw.
        await tester.tap(editFinder);
        await tester.pumpAndSettle();

        // Verify the router navigated to /reviews/write (not an error page).
        expect(find.text('Review composer'), findsOneWidget);
        expect(_lastPushedLocation, isNotNull);
        expect(_lastPushedLocation, contains('/reviews/write'));
      },
    );

    testWidgets('2. Navigation target includes reviewId query param', (
      tester,
    ) async {
      await _pumpPage(tester);

      final editFinder = find.text('Edit ›');
      await tester.tap(editFinder);
      await tester.pumpAndSettle();

      expect(_lastPushedLocation, contains('reviewId=rev-001'));
    });
  });
}
