import 'package:equatable/equatable.dart';

import 'blocked_user_summary.dart';

/// A page of blocked-user summaries returned by [GET /me/blocks].
///
/// [rows] contains enriched summaries (display name + avatar fetched per-row).
/// [nextCursor] is null when there are no more pages.
class UserBlockListPage extends Equatable {
  const UserBlockListPage({required this.rows, this.nextCursor});

  final List<BlockedUserSummary> rows;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [rows, nextCursor];
}
