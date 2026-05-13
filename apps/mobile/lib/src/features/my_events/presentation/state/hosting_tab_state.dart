import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../events/domain/entities/event.dart';

/// State machine for the Hosting tab in [MyEventsPage].
sealed class HostingTabState extends Equatable {
  const HostingTabState();
}

/// Fetch is in progress.
final class HostingTabLoading extends HostingTabState {
  const HostingTabLoading();

  @override
  List<Object?> get props => const [];
}

/// Fetch succeeded. [events] is the current user's hosted event list.
final class HostingTabLoaded extends HostingTabState {
  const HostingTabLoaded({required this.events});

  final List<Event> events;

  @override
  List<Object?> get props => [events];
}

/// Fetch failed. [message] is user-facing copy (never a raw API error string).
final class HostingTabError extends HostingTabState {
  const HostingTabError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
