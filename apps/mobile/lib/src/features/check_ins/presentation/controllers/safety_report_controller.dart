import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/safety_report_state.dart';

class SafetyReportController extends Notifier<SafetyReportState> {
  @override
  SafetyReportState build() => const SafetyReportInitial();

  // Resolve dependencies via `ref.read(...)` inside methods rather than
  // constructor-injecting them — standard Riverpod 3.x convention.
  //
  // Example:
  //
  // Future<void> load() async {
  //   state = const SafetyReportLoading();
  //   final useCase = ref.read(<someUseCaseProvider>);
  //   final result = await useCase(NoParams());
  //   state = result.match(
  //     (failure) => SafetyReportError(failure),
  //     (data) => SafetyReportLoaded(data),
  //   );
  // }
}
