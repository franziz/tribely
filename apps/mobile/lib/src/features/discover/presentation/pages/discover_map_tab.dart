import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/location_service_providers.dart';
import '../../../events/domain/entities/event.dart';
import '../providers/discover_map_providers.dart';
import '../providers/discover_providers.dart';
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
///   - Tap on single marker → [showMapEventBottomSheet].
///   - Cluster tap → zoom in one level (default cluster behaviour).
///   - OSM attribution via [RichAttributionWidget] bottom-left per §5.
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
  /// The child is wrapped in a [GestureDetector] so tapping opens the bottom
  /// sheet. The size is fixed at [EventMapMarker.kSingleDiameter].
  Marker _buildMarker(Event event) {
    return Marker(
      point: LatLng(event.venue.latitude, event.venue.longitude),
      width: EventMapMarker.kSingleDiameter,
      height: EventMapMarker.kSingleDiameter,
      child: GestureDetector(
        onTap: () => showMapEventBottomSheet(context, event, vsync: this),
        child: EventMapMarker(category: event.category),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final discoverState = ref.watch(discoverControllerProvider);

    // Extract events only when loaded — empty list otherwise (map shows without
    // markers in loading / error / empty states).
    final events = switch (discoverState) {
      DiscoverLoaded(:final events) => events,
      _ => <Event>[],
    };

    final markers = events.map(_buildMarker).toList();

    return SizedBox.expand(
      child: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          // Initial centre is CBD; _initCamera() moves the camera post-frame.
          initialCenter: kSingaporeCbd,
          initialZoom: _kCbdFallbackZoom,
          minZoom: 10.0,
          maxZoom: 18.0,
          // Disable rotation (v1 non-goal).
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          // OSM tile layer — userAgentPackageName is mandatory per OSM tile
          // usage policy to avoid rate-limiting at scale.
          // [widget.tileProvider] is null in production (uses NetworkTileProvider
          // default) and overridden with a no-op provider in widget tests.
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
    );
  }
}
