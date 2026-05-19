import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';

sealed class SafetyReportState extends Equatable {
  const SafetyReportState();

  @override
  List<Object?> get props => [];
}

class SafetyReportInitial extends SafetyReportState {
  const SafetyReportInitial();
}

class SafetyReportLoading extends SafetyReportState {
  const SafetyReportLoading();
}

class SafetyReportLoaded extends SafetyReportState {
  const SafetyReportLoaded(this.data);
  final dynamic data; // TODO: replace with actual type
  @override
  List<Object?> get props => [data];
}

class SafetyReportError extends SafetyReportState {
  const SafetyReportError(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}
