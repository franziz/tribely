import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../events/domain/entities/event.dart';

sealed class EventDetailState extends Equatable {
  const EventDetailState();

  @override
  List<Object?> get props => [];
}

class EventDetailInitial extends EventDetailState {
  const EventDetailInitial();
}

class EventDetailLoading extends EventDetailState {
  const EventDetailLoading();
}

class EventDetailLoaded extends EventDetailState {
  const EventDetailLoaded(this.event);
  final Event event;

  @override
  List<Object?> get props => [event];
}

class EventDetailError extends EventDetailState {
  const EventDetailError(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

class EventDetailNotFound extends EventDetailState {
  const EventDetailNotFound();
}
