import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/skeleton_loader.dart';

/// Compile-time Mapbox access token injected via `--dart-define`.
///
/// Brief B is expected to land a typed `AppConfig.mapboxAccessToken` constant.
/// Until that merges, we read the env var directly here. Brief F will refactor
/// to the config class at integration time.
const String _kMapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

/// Singapore centroid used in the error-fallback static map.
///
/// 1.3521° N, 103.8198° E — geographic centre of Singapore island.
const double _kSgLat = 1.3521;
const double _kSgLng = 103.8198;

/// Default display width per designer spec (16:9 at 358 dp).
const double _kDefaultWidth = 358.0;

/// Default display height per designer spec (16:9 at 201 dp).
const double _kDefaultHeight = 201.0;

/// Mapbox Static Images base URL.
const String _kMapboxBaseUrl =
    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static';

/// A dumb stateless widget that shows a Mapbox Static Images map tile with
/// the supplied [venueName] rendered as a label above the image.
///
/// Renders:
/// - Venue name as a [Text] label in Tribely body-M style above the image.
/// - A [SkeletonLoader] shimmering placeholder while the image loads.
/// - A graceful Singapore-centroid fallback when the primary image errors.
///
/// Non-interactive — no [GestureDetector], no tap handlers. TRI-258 handles
/// interactive picking.
///
/// URL contract: Mapbox Static Images uses `{lng},{lat}` order (GeoJSON), NOT
/// `{lat},{lng}`. Both the pin overlay coordinate and the map-centre coordinate
/// use lng-then-lat.
class StaticMapPreview extends StatelessWidget {
  const StaticMapPreview({
    required this.latitude,
    required this.longitude,
    required this.venueName,
    this.width,
    this.height,
    super.key,
  });

  final double latitude;
  final double longitude;
  final String venueName;

  /// Display width in logical pixels. Defaults to [_kDefaultWidth] (358 dp).
  final double? width;

  /// Display height in logical pixels. Defaults to [_kDefaultHeight] (201 dp).
  final double? height;

  /// Constructs the Mapbox Static Images URL for the primary map tile.
  ///
  /// Pin: large (pin-l), hex color ff5a5f (Mapbox-rendered pink marker).
  /// Zoom: 15. Retina: @2x (800×400 effective px, downsampled by the widget).
  /// Coordinate order: lng,lat throughout (GeoJSON / Mapbox convention).
  String _buildMapUrl() {
    return '$_kMapboxBaseUrl'
        '/pin-l+ff5a5f($longitude,$latitude)'
        '/$longitude,$latitude,15'
        '/400x200@2x'
        '?access_token=$_kMapboxToken';
  }

  /// Constructs the fallback Mapbox Static Images URL centred on Singapore
  /// with no pin overlay — displayed when the primary image fails to load.
  String _buildFallbackUrl() {
    return '$_kMapboxBaseUrl'
        '/$_kSgLng,$_kSgLat,10'
        '/400x200@2x'
        '?access_token=$_kMapboxToken';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? _kDefaultWidth;
    final effectiveHeight = height ?? _kDefaultHeight;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            venueName,
            style: TribelyType.bodyM(inkSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: effectiveWidth,
            height: effectiveHeight,
            child: Image.network(
              _buildMapUrl(),
              width: effectiveWidth,
              height: effectiveHeight,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SkeletonLoader(
                  width: effectiveWidth,
                  height: effectiveHeight,
                  borderRadius: 0, // parent ClipRRect handles rounding
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return _FallbackMapImage(
                  venueName: venueName,
                  fallbackUrl: _buildFallbackUrl(),
                  width: effectiveWidth,
                  height: effectiveHeight,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Fallback widget rendered when the primary [StaticMapPreview] image fails.
///
/// Shows a Singapore-centroid static image (no pin) with the venue name as a
/// [Stack] overlay. If the fallback image itself fails, renders a plain
/// [Container] with the venue name as text.
class _FallbackMapImage extends StatelessWidget {
  const _FallbackMapImage({
    required this.venueName,
    required this.fallbackUrl,
    required this.width,
    required this.height,
  });

  final String venueName;
  final String fallbackUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Image.network(
            fallbackUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Both primary and fallback failed — render a plain surface
              // container with the venue name so the user is not left with
              // a blank space.
              return Container(
                width: width,
                height: height,
                color: surface,
                alignment: Alignment.center,
                child: Text(
                  venueName,
                  style: TribelyType.bodyM(inkSecondary),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
          // Venue name overlay on the fallback SG map.
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: surface.withAlpha(204), // ~80% opacity
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                venueName,
                style: TribelyType.caption(inkSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
