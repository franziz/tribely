import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/datasources/review_remote_datasource.dart';
import '../../domain/repositories/review_repository.dart';
import '../../domain/usecases/edit_review_usecase.dart';
import '../../domain/usecases/list_reviews_for_user_usecase.dart';
import '../../domain/usecases/list_reviews_written_by_me_usecase.dart';
import '../../domain/usecases/submit_review_usecase.dart';
import '../controllers/my_reviews_written_controller.dart';
import '../controllers/profile_reviews_controller.dart';
import '../controllers/review_composer_controller.dart';
import '../state/my_reviews_written_state.dart';
import '../state/profile_reviews_state.dart';
import '../state/review_composer_state.dart';

// ---------------------------------------------------------------------------
// Infrastructure — resolved from the GetIt service locator.
// Register implementations in apps/mobile/lib/src/core/di/service_locator.dart.
// ---------------------------------------------------------------------------

final reviewRemoteDataSourceProvider = Provider<ReviewRemoteDatasource>(
  (_) => sl<ReviewRemoteDatasource>(),
);

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (_) => sl<ReviewRepository>(),
);

// ---------------------------------------------------------------------------
// Use cases — resolved from the GetIt service locator.
// ---------------------------------------------------------------------------

final submitReviewUseCaseProvider = Provider<SubmitReviewUseCase>(
  (_) => sl<SubmitReviewUseCase>(),
);

final editReviewUseCaseProvider = Provider<EditReviewUseCase>(
  (_) => sl<EditReviewUseCase>(),
);

final listReviewsForUserUseCaseProvider = Provider<ListReviewsForUserUseCase>(
  (_) => sl<ListReviewsForUserUseCase>(),
);

final listReviewsWrittenByMeUseCaseProvider =
    Provider<ListReviewsWrittenByMeUseCase>(
      (_) => sl<ListReviewsWrittenByMeUseCase>(),
    );

// ---------------------------------------------------------------------------
// Controllers
//
// reviewComposerControllerProvider — autoDispose (stateless family shape).
//   The composer page creates one controller per visit; it is discarded on pop.
//
// profileReviewsControllerProvider — autoDispose + family(userId: String)
//   Each user profile page gets its own paginated reviews state.
//
// myReviewsWrittenControllerProvider — autoDispose
//   The "Reviews I wrote" page. Single instance, auto-discarded on pop.
// ---------------------------------------------------------------------------

final reviewComposerControllerProvider =
    NotifierProvider.autoDispose<ReviewComposerController, ReviewComposerState>(
      ReviewComposerController.new,
    );

final profileReviewsControllerProvider = NotifierProvider.autoDispose
    .family<ProfileReviewsController, ProfileReviewsState, String>(
      ProfileReviewsController.new,
    );

final myReviewsWrittenControllerProvider =
    NotifierProvider.autoDispose<
      MyReviewsWrittenController,
      MyReviewsWrittenState
    >(MyReviewsWrittenController.new);
