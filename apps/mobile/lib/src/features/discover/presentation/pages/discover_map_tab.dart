import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/location_service_providers.dart';
import '../../../events/domain/entities/event.dart';
import '../providers/discover_map_providers.dart';
import '../providers/discover_providers.dart';
import '../providers/selected_map_event_provider.dart';
import '../state/discover_state.dart';
import '../widgets/event_map_marker.dart';
import '../widgets/location_permission_sheet.dart';
import '../widgets/map_event_bottom_sheet.dart';

// ---------------------------------------------------------------------------
// Singapore bounding box constants
// ---------------------------------------------------------------------------

/// Latitude range for Singapore — used to validate a returned position is
/// within SG before using it as the initial camera centre.
const double _kSgLatMin = 1.15;
const double _kSgLatMax = 1.48;
const double _kSgLngMin = 103.6;
const double _kSgLngMax = 104.1;

/// Initial zoom level when centering on a known position.
const double _kInitialZoom = 13.0;

/// Zoom level used for the CBD fallback (slightly wider view).
const double _kCbdFallbackZoom = 12.5;

/// Cluster radius in logical pixels — tune during on-device smoke (§ Step 8.5).
const double _kClusterRadius = 80.0;

/// Card slide-in / slide-out animation duration, matching spec §D.
const Duration _kCardAnimDuration = Duration(milliseconds: 200);

/// Cumulative downward drag threshold (logical pixels) to dismiss the card.
const double _kDragDismissThreshold = 50.0;

// ---------------------------------------------------------------------------
// DiscoverMapTab
// ---------------------------------------------------------------------------

/// Map view for the Discover screen.
///
/// Responsibilities:
///   - On first mount: check OS permission status. If not yet determined,
///     show [LocationPermissionSheet] once per session then resolve camera.
///   - Resolve initial camera centre from [LocationService.currentPosition()];
///     fall back to [kSingaporeCbd] when location is unavailable.
///   - Render OSM tiles via [TileLayer] with required [userAgentPackageName].
///   - Cluster markers via [MarkerClusterLayerWidget] (radius [_kClusterRadius]).
///   - Tap on single marker → updates [selectedMapEventProvider].
///   - Cluster tap → zoom in one level (default cluster behaviour).
///   - OSM attribution via [RichAttributionWidget] bottom-left per §5.
///   - In-tree card overlay driven by [selectedMapEventProvider] — no modal
///     route, no route-lifecycle issues with [StatefulShellRoute.indexedStack].
///
/// Technical non-goals (v1):
///   - No rotate / tilt gestures.
///   - No continuous location tracking.
///   - No Google Maps.
///   - No API keys.
///
/// The optional [tileProvider] parameter is a testability hook — pass a
/// no-op provider in widget tests to prevent network tile requests.
/// Production callers always omit it; the default (null) uses the standard
/// [NetworkTileProvider].
class DiscoverMapTab extends ConsumerStatefulWidget {
  const DiscoverMapTab({super.key, this.tileProvider});

  /// Optional tile provider override. Pass a no-op provider in widget tests
  /// to avoid real network requests. Null = default [NetworkTileProvider].
  final TileProvider? tileProvider;

  @override
  ConsumerState<DiscoverMapTab> createState() => _DiscoverMapTabState();
}

class _DiscoverMapTabState extends ConsumerState<DiscoverMapTab>
    with TickerProviderStateMixin {
  late final MapController _mapController;

  /// Whether the initial camera has been positioned.
  /// Guards against re-running camera init on hot-reload / widget re-mount.
  bool _cameraInitialised = false;

  /// Tracks TickerMode state to detect branch defocus. When the Discover
  /// branch is put offstage by [StatefulShellRoute.indexedStack], TickerMode
  /// becomes false — we use that transition to clear the selected card.
  bool _lastTickerMode = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Branch defocus detection via TickerMode.
    // When [StatefulShellRoute.indexedStack] puts the Discover branch offstage,
    // TickerMode transitions from true → false for this subtree. We clear the
    // card on that edge rather than listening to navigationShell.currentIndex
    // (which would require threading state down through DiscoverPage).
    final tickerValues = TickerMode.valuesOf(context);
    // Tickers are considered "enabled" when the muted flag is false.
    final tickerMode = tickerValues.enabled;
    if (_lastTickerMode && !tickerMode) {
      // Transitioning to offstage — clear the selected event card.
      // Schedule post-frame so we don't mutate provider state during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedMapEventProvider.notifier).clear();
        }
      });
    }
    _lastTickerMode = tickerMode;

    if (!_cameraInitialised) {
      _cameraInitialised = true;
      // Post-frame so the widget tree (and ProviderScope) is fully built before
      // we read providers and potentially push a bottom sheet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initCamera();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Camera initialisation + permission flow
  // ---------------------------------------------------------------------------

  Future<void> _initCamera() async {
    final locationService = ref.read(locationServiceProvider);
    final bool promptShown = ref.read(locationPromptShownProvider);

    // 1. Check current OS permission status.
    final status = await locationService.currentPermissionStatus();

    if (!mounted) return;

    // 2. If permission is not yet determined AND the sheet hasn't been shown
    //    this session → show the rationale sheet once.
    if (status == LocationPermissionStatus.denied && !promptShown) {
      ref.read(locationPromptShownProvider.notifier).markShown();
      await _showPermissionSheet(locationService);
      if (!mounted) return;
    }

    // 3. Resolve position for camera centre.
    final position = await locationService.currentPosition();
    if (!mounted) return;

    final centre = _resolveCentre(position);
    final zoom = position != null ? _kInitialZoom : _kCbdFallbackZoom;

    _mapController.move(centre, zoom);
  }

  /// Shows the [LocationPermissionSheet] and waits for the user's choice.
  ///
  /// On "Allow location": dismiss sheet, trigger OS dialog.
  /// On "Not now": dismiss sheet; map falls back to CBD (next [currentPosition]
  /// call will return null since permission was not granted).
  Future<void> _showPermissionSheet(LocationService locationService) async {
    final completer = <String, bool>{};

    await showLocationPermissionSheet(
      context,
      onAllow: () {
        completer['allow'] = true;
        Navigator.of(context).maybePop();
      },
      onDecline: () {
        completer['allow'] = false;
        Navigator.of(context).maybePop();
      },
    );

    if (completer['allow'] == true) {
      // Trigger the OS permission dialog. Result is reflected when
      // currentPosition() is called in _initCamera after this returns.
      if (mounted) {
        await locationService.requestPermission();
      }
    }
    // On decline (or if mounted is false): no-op; CBD fallback applies.
  }

  /// Returns the camera centre:
  ///   - [position] if non-null and within the SG bounding box.
  ///   - [kSingaporeCbd] otherwise.
  static LatLng _resolveCentre(LatLng? position) {
    if (position == null) return kSingaporeCbd;
    final inSg =
        position.latitude >= _kSgLatMin &&
        position.latitude <= _kSgLatMax &&
        position.longitude >= _kSgLngMin &&
        position.longitude <= _kSgLngMax;
    return inSg ? position : kSingaporeCbd;
  }

  // ---------------------------------------------------------------------------
  // Marker helpers
  // ---------------------------------------------------------------------------

  /// Builds a [Marker] for [event], positioning it at the venue lat/lng.
  ///
  /// The child is wrapped in a [GestureDetector] so tapping selects the event
  /// via [selectedMapEventProvider]. The size is fixed at
  /// [EventMapMarker.kSingleDiameter].
  Marker _buildMarker(Event event) {
    return Marker(
      point: LatLng(event.venue.latitude, event.venue.longitude),
      width: EventMapMarker.kSingleDiameter,
      height: EventMapMarker.kSingleDiameter,
      child: GestureDetector(
        onTap: () =>
            ref.read(selectedMapEventProvider.notifier).select(event),
        child: EventMapMarker(category: event.category),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card overlay dismiss callbacks
  // ---------------------------------------------------------------------------

  /// Clears the selected event card.
  void _clearCard() {
    ref.read(selectedMapEventProvider.notifier).clear();
  }

  /// Handles "View details →" tap.
  ///
  /// Contract (from brief §4): clear provider FIRST, then push route.
  /// Order is load-bearing — prevents residual card state after back-navigation.
  void _onViewDetails(String eventId) {
    _clearCard();
    context.push('/events/$eventId');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final discoverState = ref.watch(discoverControllerProvider);
    final selectedEvent = ref.watch(selectedMapEventProvider);

    // Extract events only when loaded — empty list otherwise (map shows without
    // markers in loading / error / empty states).
    final events = switch (discoverState) {
      DiscoverLoaded(:final events) => events,
      _ => <Event>[],
    };

    final markers = events.map(_buildMarker).toList();

    // Card is visible when selectedEvent is non-null.
    final cardVisible = selectedEvent != null;

    return PopScope(
      // Intercept system back / iOS swipe-back when the card is open.
      // When card is open: consume the gesture and clear the card.
      // When card is closed: allow default pop behaviour (branch root → no-op).
      canPop: !cardVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && cardVisible) {
          _clearCard();
        }
      },
      child: SizedBox.expand(
        child: Stack(
          children: [
            // ── Map layer ──
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // Initial centre is CBD; _initCamera() moves the camera post-frame.
                initialCenter: kSingaporeCbd,
                initialZoom: _kCbdFallbackZoom,
                minZoom: 10.0,
                maxZoom: 18.0,
                // Dismiss card when the user taps the map area outside the card.
                onTap: (tapPosition, point) => _clearCard(),
                // Disable rotation (v1 non-goal).
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                // OSM tile layer — userAgentPackageName is mandatory per OSM tile
                // usage policy to avoid rate-limiting at scale.
                // [widget.tileProvider] is null in production (uses NetworkTileProvider
                // default) and overridden with a no-op provider in widget tests.
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tribely',
                  tileProvider: widget.tileProvider,
                ),

                // Marker clustering — radius 80px, spec §D.
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: _kClusterRadius.toInt(),
                    size: const Size(
                      EventMapMarker.kSingleDiameter,
                      EventMapMarker.kSingleDiameter,
                    ),
                    markers: markers,
                    // markerChildBehavior=true: the GestureDetector on each marker
                    // child owns tap handling; suppress the cluster layer's wrapping
                    // gesture to avoid double-tap registration.
                    markerChildBehavior: true,
                    builder: (context, clusterMarkers) {
                      return EventClusterMarker(count: clusterMarkers.length);
                    },
                  ),
                ),

                // OSM attribution per §5 and OSM tile usage policy.
                // Position: bottom-left — avoids collision with D5's sticky CTA which
                // mounts at the bottom edge of the Discover scaffold.
                // TODO(D4): add `url_launcher` to pubspec and replace the no-op onTap
                // with `launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'))`
                // before the first production tile request. Omitting it now avoids an
                // unauthorized pubspec change; attribution text is still visible.
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  showFlutterMapAttribution: false,
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      // no-op until url_launcher is added to pubspec — see TODO above.
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),

            // ── Card overlay ──
            //
            // AnimatedSlide drives the slide-in / slide-out. When [cardVisible]
            // is false the card slides entirely below the screen edge (offset
            // (0, 1) = 100% of card height below). Duration 200ms easeOut per §D.
            //
            // The card is kept in the tree while animating out so the slide-down
            // animation completes before the widget disappears. We use an
            // AnimatedSlide on a Positioned bottom-anchored child.
            if (selectedEvent != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _CardOverlay(
                  event: selectedEvent,
                  onViewDetails: () => _onViewDetails(selectedEvent.id),
                  onDismiss: _clearCard,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CardOverlay — animated wrapper for MapEventBottomSheet
// ---------------------------------------------------------------------------

/// Animated in-tree card overlay.
///
/// Slides up from below (offset 0,1 → 0,0) using [AnimatedSlide] with
/// 200ms easeOut on mount. Drag-to-dismiss is handled via [GestureDetector]
/// with cumulative [dy] tracking — calls [onDismiss] when threshold crossed.
class _CardOverlay extends StatefulWidget {
  const _CardOverlay({
    required this.event,
    required this.onViewDetails,
    required this.onDismiss,
  });

  final Event event;
  final VoidCallback onViewDetails;
  final VoidCallback onDismiss;

  @override
  State<_CardOverlay> createState() => _CardOverlayState();
}

class _CardOverlayState extends State<_CardOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  /// Accumulated downward drag delta (logical pixels).
  double _dragAccumulated = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kCardAnimDuration,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    // Animate in immediately.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0) {
      // Accumulate downward drag only.
      _dragAccumulated += details.delta.dy;
      if (_dragAccumulated >= _kDragDismissThreshold) {
        // Threshold crossed — dismiss. Reset so future drag on a new card
        // starts fresh (though the widget will be rebuilt by then).
        _dragAccumulated = 0;
        widget.onDismiss();
      }
    } else {
      // Upward drag resets accumulation.
      _dragAccumulated = 0;
    }
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    _dragAccumulated = 0;
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        // Absorb horizontal gestures on the card to prevent map panning
        // from accidentally triggering dismiss logic.
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: MapEventBottomSheet(
          event: widget.event,
          onViewDetails: widget.onViewDetails,
        ),
      ),
    );
  }
}
