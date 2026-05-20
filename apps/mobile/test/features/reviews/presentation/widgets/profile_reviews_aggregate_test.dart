// Widget tests for ProfileReviewsAggregate.
//
// Covers:
//   1. Empty state — "No reviews yet" in italicCaption.
//   2. Populated state — renders star rating, count, and comments.
//   3. Mutual-window-pending state — opaque "Reviews pending" block.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/reviews/domain/entities/profile_review_aggregate.dart';
import 'package:tribely/src/features/reviews/domain/entities/recent_review_comment.dart';
import 'package:tribely/src/features/reviews/presentation/string_assets/review_copy.dart';
import 'package:tribely/src/features/reviews/presentation/widgets/profile_reviews_aggregate.dart';

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

ProfileReviewAggregate _emptyAggregate() =>
    const ProfileReviewAggregate(reviewCount: 0, recentVisibleComments: []);

ProfileReviewAggregate _populatedAggregate() => ProfileReviewAggregate(
  averageRating: 4.2,
  reviewCount: 5,
  recentVisibleComments: [
    RecentReviewComment(
      excerpt: 'Great event!',
      raterDisplayName: 'Alice',
      rating: 5,
      eventTitle: 'Drinks at Bar',
      createdAt: DateTime(2026, 5, 1),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProfileReviewsAggregate — empty state', () {
    testWidgets('renders "No reviews yet" text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileReviewsAggregate(
            aggregate: _emptyAggregate(),
            onSeeAll: () {},
          ),
        ),
      );

      expect(find.text(ReviewCopy.noReviewsYet), findsOneWidget);
      expect(find.text(ReviewCopy.reviewsPending), findsNothing);
    });
  });

  group('ProfileReviewsAggregate — populated state', () {
    testWidgets('renders average rating and review count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileReviewsAggregate(
            aggregate: _populatedAggregate(),
            onSeeAll: () {},
          ),
        ),
      );

      expect(find.text('4.2'), findsOneWidget);
      expect(find.text('(5)'), findsOneWidget);
    });

    testWidgets('renders recent comment excerpts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileReviewsAggregate(
            aggregate: _populatedAggregate(),
            onSeeAll: () {},
          ),
        ),
      );

      expect(find.textContaining('Great event!'), findsOneWidget);
    });

    testWidgets('renders "See all" link and fires callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          ProfileReviewsAggregate(
            aggregate: _populatedAggregate(),
            onSeeAll: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text(ReviewCopy.seeAll));
      expect(tapped, isTrue);
    });
  });

  group('ProfileReviewsAggregate — mutual-window-pending state', () {
    testWidgets('renders "Reviews pending" opaque block', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileReviewsAggregate(
            aggregate: _emptyAggregate(),
            onSeeAll: () {},
            mutualWindowPending: true,
          ),
        ),
      );

      expect(find.text(ReviewCopy.reviewsPending), findsOneWidget);
      expect(find.text(ReviewCopy.noReviewsYet), findsNothing);
      // Average rating should not be rendered.
      expect(find.text('0.0'), findsNothing);
    });
  });
}
