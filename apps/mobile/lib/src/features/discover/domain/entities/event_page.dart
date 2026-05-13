import 'package:equatable/equatable.dart';

import '../../../events/domain/entities/event.dart';

/// A single page of [Event] results from the Discover browse endpoint.
///
/// Pagination contract:
///   - [nextCursor] is non-null when more pages are available.
///   - [nextCursor] is null AND [events] may be empty when the stream is
///     exhausted (end of results).
///
/// The cursor value is opaque — the client must never parse or construct it.
class EventPage extends Equatable {
  const EventPage({required this.events, required this.nextCursor});

  /// Events on this page. May be empty on the final page.
  final List<Event> events;

  /// Cursor to pass as `cursor=` on the next request. Null = end of stream.
  final String? nextCursor;

  /// Convenience: returns true when this is the last page.
  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [events, nextCursor];
}
