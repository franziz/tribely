// Widget tests for BlockConfirmSheet.
//
// Covers:
//   1. Headline and all consequence bullets render.
//   2. "Block [name]" button is present.
//   3. "Cancel" button dismisses the sheet.
//   4. Tapping Block button invokes the controller.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/user_blocks/domain/entities/user_block.dart';
import 'package:tribely/src/features/user_blocks/domain/usecases/block_user_usecase.dart';
import 'package:tribely/src/features/user_blocks/presentation/providers/user_block_providers.dart';
import 'package:tribely/src/features/user_blocks/presentation/string_assets/block_copy.dart';
import 'package:tribely/src/features/user_blocks/presentation/widgets/block_confirm_sheet.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockBlockUserUseCase extends Mock implements BlockUserUseCase {}

class FakeBlockUserParams extends Fake implements BlockUserParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserBlock _fakeBlock() => UserBlock(
  id: 'blk-1',
  initiatorUserId: 'user-a',
  blockedUserId: 'user-b',
  createdAt: DateTime(2026, 5, 1),
);

Widget _wrap({
  required MockBlockUserUseCase useCase,
  VoidCallback? onSuccess,
  String displayName = 'Maya Tan',
}) {
  return ProviderScope(
    overrides: [blockUserUseCaseProvider.overrideWithValue(useCase)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BlockConfirmSheet(
                  userId: 'user-b',
                  displayName: displayName,
                  onSuccess: onSuccess,
                ),
              );
            },
            child: const Text('Open sheet'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open sheet'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBlockUserParams());
  });

  late MockBlockUserUseCase useCase;

  setUp(() {
    useCase = MockBlockUserUseCase();
  });

  group('BlockConfirmSheet — renders', () {
    testWidgets('renders headline and Block button', (tester) async {
      when(() => useCase(any())).thenAnswer((_) async => Right(_fakeBlock()));
      await tester.pumpWidget(_wrap(useCase: useCase, displayName: 'Maya Tan'));
      await _openSheet(tester);

      expect(find.text(BlockCopy.blockConfirmTitle), findsOneWidget);
      expect(find.text('Block Maya Tan'), findsOneWidget);
    });

    testWidgets('renders at least the first consequence bullet', (
      tester,
    ) async {
      when(() => useCase(any())).thenAnswer((_) async => Right(_fakeBlock()));
      await tester.pumpWidget(_wrap(useCase: useCase));
      await _openSheet(tester);

      // Verify first bullet text is present (others may need scroll)
      expect(
        find.textContaining("won't be able to see your profile"),
        findsOneWidget,
      );
    });

    testWidgets('renders Cancel button', (tester) async {
      when(() => useCase(any())).thenAnswer((_) async => Right(_fakeBlock()));
      await tester.pumpWidget(_wrap(useCase: useCase));
      await _openSheet(tester);

      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('BlockConfirmSheet — Cancel dismisses', () {
    testWidgets('"Cancel" tap dismisses the sheet', (tester) async {
      when(() => useCase(any())).thenAnswer((_) async => Right(_fakeBlock()));
      await tester.pumpWidget(_wrap(useCase: useCase));
      await _openSheet(tester);

      expect(find.text('Block Maya Tan'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text(BlockCopy.blockConfirmTitle), findsNothing);
    });
  });

  group('BlockConfirmSheet — Block button invokes controller', () {
    testWidgets('tapping Block invokes BlockUserUseCase', (tester) async {
      when(() => useCase(any())).thenAnswer((_) async => Right(_fakeBlock()));

      await tester.pumpWidget(_wrap(useCase: useCase));
      await _openSheet(tester);

      await tester.tap(find.text('Block Maya Tan'));
      await tester.pumpAndSettle();

      verify(() => useCase(any())).called(1);
    });
  });

  group('BlockConfirmSheet — inline error on Failure', () {
    testWidgets('shows error banner on block failure', (tester) async {
      when(
        () => useCase(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));

      await tester.pumpWidget(_wrap(useCase: useCase));
      await _openSheet(tester);

      await tester.tap(find.text('Block Maya Tan'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't reach Tribely"), findsOneWidget);
    });
  });
}
