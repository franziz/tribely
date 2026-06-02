import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/events/domain/entities/place_details.dart';
import 'package:tribely/src/features/events/domain/entities/place_suggestion.dart';
import 'package:tribely/src/features/events/domain/ports/place_search_port.dart';
import 'package:tribely/src/features/events/presentation/providers/venue_picker_providers.dart';
import 'package:tribely/src/features/events/presentation/state/venue_picker_state.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class _MockPlaceSearchPort extends Mock implements PlaceSearchPort {}

// ---------------------------------------------------------------------------
// Fallbacks required by mocktail
// ---------------------------------------------------------------------------

class _FakePlaceSuggestion extends Fake implements PlaceSuggestion {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PlaceSuggestion _suggestion({String id = 'mapbox-1'}) => PlaceSuggestion(
  providerPlaceId: id,
  name: 'Lau Pa Sat',
  placeFormatted: '18 Raffles Quay, Singapore 048582',
);

PlaceDetails _details({String id = 'mapbox-1'}) => PlaceDetails(
  providerPlaceId: id,
  name: 'Lau Pa Sat',
  formattedAddress: '18 Raffles Quay, Singapore 048582',
  latitude: 1.2841,
  longitude: 103.8504,
);

/// Builds a [ProviderContainer] with [placeSearchPortProvider] overridden.
({ProviderContainer container, _MockPlaceSearchPort port}) _makeContainer() {
  final port = _MockPlaceSearchPort();
  final container = ProviderContainer(
    overrides: [placeSearchPortProvider.overrideWithValue(port)],
  );
  return (container: container, port: port);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePlaceSuggestion());
  });

  group('VenuePickerController', () {
    // -----------------------------------------------------------------------
    // Initial state
    // -----------------------------------------------------------------------

    test('initial state is VenuePickerInitial', () {
      final (:container, port: _) = _makeContainer();
      addTearDown(container.dispose);

      expect(
        container.read(venuePickerControllerProvider),
        isA<VenuePickerInitial>(),
      );
    });

    // -----------------------------------------------------------------------
    // Debounce
    // -----------------------------------------------------------------------

    test(
      'rapid onQueryChanged calls only trigger one suggest after 300ms',
      () {
        fakeAsync((async) {
          final (:container, :port) = _makeContainer();
          addTearDown(container.dispose);

          when(
            () => port.suggest(query: any(named: 'query'), sessionToken: any(named: 'sessionToken')),
          ).thenAnswer((_) async => Right([_suggestion()]));

          final controller = container.read(
            venuePickerControllerProvider.notifier,
          );

          controller.onQueryChanged('l');
          controller.onQueryChanged('la');
          controller.onQueryChanged('lau');

          // Debounce window still open — no calls yet.
          verifyNever(
            () => port.suggest(
              query: any(named: 'query'),
              sessionToken: any(named: 'sessionToken'),
            ),
          );

          async.elapse(const Duration(milliseconds: 300));
          async.flushMicrotasks();

          verify(
            () => port.suggest(
              query: 'lau',
              sessionToken: any(named: 'sessionToken'),
            ),
          ).called(1);
        });
      },
    );

    test('empty query resets to VenuePickerInitial without calling suggest', () {
      fakeAsync((async) {
        final (:container, :port) = _makeContainer();
        addTearDown(container.dispose);

        final controller = container.read(
          venuePickerControllerProvider.notifier,
        );

        controller.onQueryChanged('lau');
        controller.onQueryChanged('');

        async.elapse(const Duration(milliseconds: 300));

        expect(
          container.read(venuePickerControllerProvider),
          isA<VenuePickerInitial>(),
        );
        verifyNever(
          () => port.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        );
      });
    });

    // -----------------------------------------------------------------------
    // Session token stability within a cycle
    // -----------------------------------------------------------------------

    test('session token is stable across suggest calls in the same cycle', () {
      fakeAsync((async) {
        final (:container, :port) = _makeContainer();
        addTearDown(container.dispose);

        String? capturedToken1;
        String? capturedToken2;

        when(
          () => port.suggest(query: any(named: 'query'), sessionToken: any(named: 'sessionToken')),
        ).thenAnswer((invocation) async {
          capturedToken1 ??= invocation.namedArguments[#sessionToken] as String;
          return Right([_suggestion()]);
        });

        final controller = container.read(
          venuePickerControllerProvider.notifier,
        );

        controller.onQueryChanged('lau');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        controller.onQueryChanged('lau pa');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        when(
          () => port.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenAnswer((invocation) async {
          capturedToken2 = invocation.namedArguments[#sessionToken] as String;
          return Right([_suggestion()]);
        });

        controller.onQueryChanged('lau pa s');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // Both calls within the same session cycle must use the same token.
        // capturedToken1 is from the first suggest; capturedToken2 from the third.
        expect(capturedToken1, isNotNull);
        expect(capturedToken2, isNotNull);
        expect(capturedToken1, equals(capturedToken2));
      });
    });

    test('session token is rotated on clearSelection', () {
      fakeAsync((async) {
        final (:container, :port) = _makeContainer();
        addTearDown(container.dispose);

        String? tokenBefore;
        String? tokenAfter;

        when(
          () => port.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenAnswer((invocation) async {
          final token = invocation.namedArguments[#sessionToken] as String;
          if (tokenBefore == null) {
            tokenBefore = token;
          } else {
            tokenAfter = token;
          }
          return Right([_suggestion()]);
        });

        final controller = container.read(
          venuePickerControllerProvider.notifier,
        );

        // First typeahead cycle.
        controller.onQueryChanged('lau');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // Clear selection — should rotate session token.
        controller.clearSelection();

        // Second typeahead cycle.
        controller.onQueryChanged('lau');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(tokenBefore, isNotNull);
        expect(tokenAfter, isNotNull);
        expect(tokenBefore, isNot(equals(tokenAfter)));
      });
    });

    // -----------------------------------------------------------------------
    // Quota failure
    // -----------------------------------------------------------------------

    test('QuotaExhaustedFailure transitions to VenuePickerDegradedQuota', () {
      fakeAsync((async) {
        final (:container, :port) = _makeContainer();
        addTearDown(container.dispose);

        when(
          () => port.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenAnswer(
          (_) async => const Left(
            QuotaExhaustedFailure('Quota exceeded'),
          ),
        );

        final controller = container.read(
          venuePickerControllerProvider.notifier,
        );

        controller.onQueryChanged('lau');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(
          container.read(venuePickerControllerProvider),
          isA<VenuePickerDegradedQuota>(),
        );
      });
    });

    test('further onQueryChanged calls are ignored after VenuePickerDegradedQuota', () {
      fakeAsync((async) {
        final (:container, :port) = _makeContainer();
        addTearDown(container.dispose);

        when(
          () => port.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenAnswer(
          (_) async => const Left(QuotaExhaustedFailure('Quota exceeded')),
        );

        final controller = container.read(
          venuePickerControllerProvider.notifier,
        );

        controller.onQueryChanged('lau');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // Verify quota state is set.
        expect(
          container.read(venuePickerControllerProvider),
          isA<VenuePickerDegradedQuota>(),
        );

        // Second query — should be silently ignored.
        controller.onQueryChanged('marina');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // Still in quota-degraded state; suggest called exactly once.
        expect(
          container.read(venuePickerControllerProvider),
          isA<VenuePickerDegradedQuota>(),
        );
        verify(
          () => port.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // Network failure
    // -----------------------------------------------------------------------

    test('NetworkFailure transitions to VenuePickerDegradedNetwork', () {
      fakeAsync((async) {
        final (:container, :port) = _makeContainer();
        addTearDown(container.dispose);

        when(
          () => port.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenAnswer(
          (_) async => const Left(NetworkFailure('No internet')),
        );

        final controller = container.read(
          venuePickerControllerProvider.notifier,
        );

        controller.onQueryChanged('lau');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        final state = container.read(venuePickerControllerProvider);
        expect(state, isA<VenuePickerDegradedNetwork>());
        expect((state as VenuePickerDegradedNetwork).message, 'No internet');
      });
    });

    // -----------------------------------------------------------------------
    // Provider failure (treated as transient / network-degraded)
    // -----------------------------------------------------------------------

    test('ProviderFailure transitions to VenuePickerDegradedNetwork', () {
      fakeAsync((async) {
        final (:container, :port) = _makeContainer();
        addTearDown(container.dispose);

        when(
          () => port.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenAnswer(
          (_) async => const Left(ProviderFailure('Provider 503')),
        );

        final controller = container.read(
          venuePickerControllerProvider.notifier,
        );

        controller.onQueryChanged('lau');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(
          container.read(venuePickerControllerProvider),
          isA<VenuePickerDegradedNetwork>(),
        );
      });
    });

    // -----------------------------------------------------------------------
    // Empty result
    // -----------------------------------------------------------------------

    test('empty suggest result transitions to VenuePickerEmpty', () {
      fakeAsync((async) {
        final (:container, :port) = _makeContainer();
        addTearDown(container.dispose);

        when(
          () => port.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenAnswer((_) async => const Right([]));

        final controller = container.read(
          venuePickerControllerProvider.notifier,
        );

        controller.onQueryChanged('xyzzy');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        final state = container.read(venuePickerControllerProvider);
        expect(state, isA<VenuePickerEmpty>());
        expect((state as VenuePickerEmpty).query, 'xyzzy');
      });
    });

    // -----------------------------------------------------------------------
    // Non-empty result
    // -----------------------------------------------------------------------

    test('non-empty suggest result transitions to VenuePickerResults', () {
      fakeAsync((async) {
        final (:container, :port) = _makeContainer();
        addTearDown(container.dispose);

        final suggestions = [_suggestion(id: 'mapbox-1'), _suggestion(id: 'mapbox-2')];
        when(
          () => port.suggest(
            query: any(named: 'query'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenAnswer((_) async => Right(suggestions));

        final controller = container.read(
          venuePickerControllerProvider.notifier,
        );

        controller.onQueryChanged('lau');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        final state = container.read(venuePickerControllerProvider);
        expect(state, isA<VenuePickerResults>());
        expect((state as VenuePickerResults).suggestions, suggestions);
      });
    });

    // -----------------------------------------------------------------------
    // Successful retrieve → VenuePickerSelected
    // -----------------------------------------------------------------------

    test('selectSuggestion transitions to VenuePickerSelected on success', () async {
      final (:container, :port) = _makeContainer();
      addTearDown(container.dispose);

      final details = _details();
      when(
        () => port.retrieve(
          providerPlaceId: any(named: 'providerPlaceId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenAnswer((_) async => Right(details));

      final controller = container.read(
        venuePickerControllerProvider.notifier,
      );

      await controller.selectSuggestion(_suggestion());

      final state = container.read(venuePickerControllerProvider);
      expect(state, isA<VenuePickerSelected>());
      expect((state as VenuePickerSelected).details, details);
    });

    // -----------------------------------------------------------------------
    // selectSuggestion no-op when already selected with same place ID
    // -----------------------------------------------------------------------

    test('selectSuggestion is a no-op if already selected with the same place ID', () async {
      final (:container, :port) = _makeContainer();
      addTearDown(container.dispose);

      when(
        () => port.retrieve(
          providerPlaceId: any(named: 'providerPlaceId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenAnswer((_) async => Right(_details()));

      final controller = container.read(
        venuePickerControllerProvider.notifier,
      );

      // First selection.
      await controller.selectSuggestion(_suggestion());
      expect(
        container.read(venuePickerControllerProvider),
        isA<VenuePickerSelected>(),
      );

      // Second tap on the same suggestion.
      await controller.selectSuggestion(_suggestion());

      // retrieve must have been called exactly once.
      verify(
        () => port.retrieve(
          providerPlaceId: any(named: 'providerPlaceId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).called(1);
    });

    // -----------------------------------------------------------------------
    // clearSelection
    // -----------------------------------------------------------------------

    test('clearSelection resets to VenuePickerInitial', () async {
      final (:container, :port) = _makeContainer();
      addTearDown(container.dispose);

      when(
        () => port.retrieve(
          providerPlaceId: any(named: 'providerPlaceId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenAnswer((_) async => Right(_details()));

      final controller = container.read(
        venuePickerControllerProvider.notifier,
      );

      await controller.selectSuggestion(_suggestion());
      expect(
        container.read(venuePickerControllerProvider),
        isA<VenuePickerSelected>(),
      );

      controller.clearSelection();

      expect(
        container.read(venuePickerControllerProvider),
        isA<VenuePickerInitial>(),
      );
    });

    // -----------------------------------------------------------------------
    // retrieve failure → degraded states
    // -----------------------------------------------------------------------

    test('retrieve QuotaExhaustedFailure transitions to VenuePickerDegradedQuota', () async {
      final (:container, :port) = _makeContainer();
      addTearDown(container.dispose);

      when(
        () => port.retrieve(
          providerPlaceId: any(named: 'providerPlaceId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenAnswer(
        (_) async => const Left(QuotaExhaustedFailure('Quota exceeded')),
      );

      final controller = container.read(
        venuePickerControllerProvider.notifier,
      );

      await controller.selectSuggestion(_suggestion());

      expect(
        container.read(venuePickerControllerProvider),
        isA<VenuePickerDegradedQuota>(),
      );
    });

    test('retrieve NetworkFailure transitions to VenuePickerDegradedNetwork', () async {
      final (:container, :port) = _makeContainer();
      addTearDown(container.dispose);

      when(
        () => port.retrieve(
          providerPlaceId: any(named: 'providerPlaceId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('Connection failed')),
      );

      final controller = container.read(
        venuePickerControllerProvider.notifier,
      );

      await controller.selectSuggestion(_suggestion());

      expect(
        container.read(venuePickerControllerProvider),
        isA<VenuePickerDegradedNetwork>(),
      );
    });
  });
}
