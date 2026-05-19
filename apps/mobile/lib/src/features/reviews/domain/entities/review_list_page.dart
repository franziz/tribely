import 'package:equatable/equatable.dart';

import 'review_visibility.dart';

/// A single page of reviews in cursor-paginated list responses.
///
/// [rows] uses [ReviewVisibility] so a single list can mix visible, blind, and
/// hidden entries — the controller/widget pattern-matches per row.
///
/// Pure Dart — no Flutter, no Dio, no Riverpod.
class ReviewListPage extends Equatable {
  const ReviewListPage({required this.rows, this.nextCursor});

  final List<ReviewVisibility> rows;

  /// Null when this is the last page.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [rows, nextCursor];
}
