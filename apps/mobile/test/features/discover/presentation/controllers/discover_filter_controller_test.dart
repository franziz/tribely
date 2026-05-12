import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/discover/domain/entities/discover_filters.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_filter_controller.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_filter_providers.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_filter_state.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a [ProviderContainer] with [DiscoverFilterController] wired.
/// Returns both so callers can read state and call methods.
({ProviderContainer container, DiscoverFilterController controller})
_makeContainer() {
  final container = ProviderContainer();
  // Eagerly read to trigger build().
  container.read(discoverFilterControllerProvider);
  final controller = container.read(discoverFilterControllerProvider.notifier);
  return (container: container, controller: controller);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------
  group('initial state', () {
    test('timeWindow=anytime, no categories, no distance on build', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      final state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;

      expect(state.timeWindow, TimeWindow.anytime);
      expect(state.categories, isEmpty);
      expect(state.maxDistanceKm, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // setTimeWindow — single-select (radio-like) semantics
  // ---------------------------------------------------------------------------
  group('setTimeWindow — single-select semantics', () {
    test('setting a new value replaces the previous one', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      controller.setTimeWindow(TimeWindow.tonight);
      var state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;
      expect(state.timeWindow, TimeWindow.tonight);

      controller.setTimeWindow(TimeWindow.thisWeek);
      state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;
      expect(state.timeWindow, TimeWindow.thisWeek);

      // Must be thisWeek only — never accumulates both values.
      expect(state.timeWindow, isNot(TimeWindow.tonight));
    });

    test(
      'setting the same value again is a no-op (state object identical)',
      () {
        final (:container, :controller) = _makeContainer();
        addTearDown(container.dispose);

        controller.setTimeWindow(TimeWindow.tonight);
        final before = container.read(discoverFilterControllerProvider);

        controller.setTimeWindow(TimeWindow.tonight);
        final after = container.read(discoverFilterControllerProvider);

        // Same object reference — no state emission occurred.
        expect(identical(before, after), isTrue);
      },
    );

    test('anytime replaces a previously set window', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      controller.setTimeWindow(TimeWindow.tonight);
      controller.setTimeWindow(TimeWindow.anytime);

      final state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;
      expect(state.timeWindow, TimeWindow.anytime);
    });
  });

  // ---------------------------------------------------------------------------
  // toggleCategory — multi-select OR semantics
  // ---------------------------------------------------------------------------
  group('toggleCategory — multi-select semantics', () {
    test('selecting an absent category adds it', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      controller.toggleCategory(EventCategory.drinks);

      final state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;
      expect(state.categories, contains(EventCategory.drinks));
    });

    test('selecting an already-present category removes it (toggle off)', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      controller.toggleCategory(EventCategory.drinks);
      controller.toggleCategory(EventCategory.drinks);

      final state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;
      expect(state.categories, isNot(contains(EventCategory.drinks)));
      expect(state.categories, isEmpty);
    });

    test('multiple categories can be active simultaneously (OR semantics)', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      controller.toggleCategory(EventCategory.drinks);
      controller.toggleCategory(EventCategory.hike);

      final state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;
      expect(
        state.categories,
        containsAll([EventCategory.drinks, EventCategory.hike]),
      );
    });

    test('removing one category leaves others intact', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      controller.toggleCategory(EventCategory.drinks);
      controller.toggleCategory(EventCategory.hike);
      controller.toggleCategory(EventCategory.drinks); // remove drinks

      final state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;
      expect(state.categories, isNot(contains(EventCategory.drinks)));
      expect(state.categories, contains(EventCategory.hike));
    });
  });

  // ---------------------------------------------------------------------------
  // setMaxDistanceKm
  // ---------------------------------------------------------------------------
  group('setMaxDistanceKm', () {
    test('sets distance to non-null value', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      controller.setMaxDistanceKm(5.0);

      final state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;
      expect(state.maxDistanceKm, 5.0);
    });

    test('null clears the distance filter', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      controller.setMaxDistanceKm(25.0);
      controller.setMaxDistanceKm(null);

      final state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;
      expect(state.maxDistanceKm, isNull);
    });

    test('setting the same value is a no-op', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      controller.setMaxDistanceKm(5.0);
      final before = container.read(discoverFilterControllerProvider);

      controller.setMaxDistanceKm(5.0);
      final after = container.read(discoverFilterControllerProvider);

      expect(identical(before, after), isTrue);
    });

    test('null-to-null is a no-op', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      final before = container.read(discoverFilterControllerProvider);
      controller.setMaxDistanceKm(null);
      final after = container.read(discoverFilterControllerProvider);

      expect(identical(before, after), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // reset
  // ---------------------------------------------------------------------------
  group('reset', () {
    test('clears all fields back to initial defaults', () {
      final (:container, :controller) = _makeContainer();
      addTearDown(container.dispose);

      controller.setTimeWindow(TimeWindow.tonight);
      controller.toggleCategory(EventCategory.drinks);
      controller.toggleCategory(EventCategory.hike);
      controller.setMaxDistanceKm(25.0);

      controller.reset();

      final state =
          container.read(discoverFilterControllerProvider)
              as DiscoverFiltersActive;
      expect(state.timeWindow, TimeWindow.anytime);
      expect(state.categories, isEmpty);
      expect(state.maxDistanceKm, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Debounce — 5-tap race test
  //
  // Fire 5 toggleCategory calls within 100ms (all within the 250ms window),
  // then advance FakeAsync clock by 250ms and assert exactly one emission lands
  // on the debounced stream.
  // ---------------------------------------------------------------------------
  group('debounce', () {
    test(
      '5 toggleCategory calls within 100ms produce exactly 1 debounced emission '
      'after advancing 250ms',
      () {
        fakeAsync((async) {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          container.read(discoverFilterControllerProvider);
          final controller = container.read(
            discoverFilterControllerProvider.notifier,
          );

          final emissions = <DiscoverFiltersActive>[];
          final sub = controller.debouncedStream.listen(emissions.add);

          // Fire 5 taps — each resets the 250ms timer.
          // Advance 20ms between taps so total elapsed ≈ 100ms (< 250ms).
          controller.toggleCategory(EventCategory.drinks);
          async.elapse(const Duration(milliseconds: 20));

          controller.toggleCategory(EventCategory.hike);
          async.elapse(const Duration(milliseconds: 20));

          controller.toggleCategory(EventCategory.museum);
          async.elapse(const Duration(milliseconds: 20));

          controller.toggleCategory(EventCategory.sports);
          async.elapse(const Duration(milliseconds: 20));

          controller.toggleCategory(EventCategory.nightlife);
          async.elapse(const Duration(milliseconds: 20));

          // Total elapsed: 100ms. No timer should have fired yet.
          expect(emissions, isEmpty, reason: 'debounce window not elapsed yet');

          // Advance past the debounce window — exactly one timer fires.
          async.elapse(const Duration(milliseconds: 250));

          expect(
            emissions,
            hasLength(1),
            reason: 'exactly 1 emission after the debounce window',
          );

          // The snapshot must reflect the final state after all 5 toggles.
          // drinks→on, hike→on, museum→on, sports→on, nightlife→on.
          expect(
            emissions.first.categories,
            containsAll([
              EventCategory.drinks,
              EventCategory.hike,
              EventCategory.museum,
              EventCategory.sports,
              EventCategory.nightlife,
            ]),
          );

          sub.cancel();
        });
      },
    );

    test(
      'two mutations separated by >250ms each produce 2 debounced emissions',
      () {
        fakeAsync((async) {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          container.read(discoverFilterControllerProvider);
          final controller = container.read(
            discoverFilterControllerProvider.notifier,
          );

          final emissions = <DiscoverFiltersActive>[];
          final sub = controller.debouncedStream.listen(emissions.add);

          controller.setTimeWindow(TimeWindow.tonight);
          async.elapse(const Duration(milliseconds: 300)); // fires 1st timer

          controller.setTimeWindow(TimeWindow.thisWeek);
          async.elapse(const Duration(milliseconds: 300)); // fires 2nd timer

          expect(emissions, hasLength(2));
          expect(emissions[0].timeWindow, TimeWindow.tonight);
          expect(emissions[1].timeWindow, TimeWindow.thisWeek);

          sub.cancel();
        });
      },
    );

    test('reset() emits exactly one debounced snapshot after 250ms', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(discoverFilterControllerProvider);
        final controller = container.read(
          discoverFilterControllerProvider.notifier,
        );

        // Set some state first.
        controller.setTimeWindow(TimeWindow.tonight);
        async.elapse(const Duration(milliseconds: 300));

        final emissions = <DiscoverFiltersActive>[];
        final sub = controller.debouncedStream.listen(emissions.add);

        controller.reset();
        async.elapse(const Duration(milliseconds: 250));

        expect(emissions, hasLength(1));
        expect(emissions.first.timeWindow, TimeWindow.anytime);
        expect(emissions.first.categories, isEmpty);
        expect(emissions.first.maxDistanceKm, isNull);

        sub.cancel();
      });
    });

    test('no emission fires before 250ms has elapsed after the last tap', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(discoverFilterControllerProvider);
        final controller = container.read(
          discoverFilterControllerProvider.notifier,
        );

        final emissions = <DiscoverFiltersActive>[];
        final sub = controller.debouncedStream.listen(emissions.add);

        controller.toggleCategory(EventCategory.drinks);
        async.elapse(const Duration(milliseconds: 249));

        expect(emissions, isEmpty, reason: 'timer has not fired yet at 249ms');

        async.elapse(const Duration(milliseconds: 1)); // total 250ms — fires
        expect(emissions, hasLength(1));

        sub.cancel();
      });
    });
  });
}
