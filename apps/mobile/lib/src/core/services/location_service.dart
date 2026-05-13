import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Singapore CBD centre — used as the fallback when location is unavailable.
const LatLng kSingaporeCbd = LatLng(1.2843, 103.8511);

/// Abstraction over the platform location permission + position APIs.
///
/// Rules:
/// - Never throws to callers — errors are surfaced as [null] / status enum values.
/// - Never caches a position across sessions (PDPA).
/// - Never opens system settings UI (that is a presentation concern).
/// - Never runs in the background.
enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}

class LocationService {
  /// Returns the current permission state without requesting anything.
  Future<LocationPermissionStatus> currentPermissionStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return LocationPermissionStatus.serviceDisabled;

      final permission = await Geolocator.checkPermission();
      return _mapPermission(permission);
    } catch (_) {
      return LocationPermissionStatus.denied;
    }
  }

  /// Requests the when-in-use location permission if not yet determined.
  ///
  /// Returns [LocationPermissionStatus.serviceDisabled] immediately when
  /// location services are off — the OS dialog cannot help in that case.
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return LocationPermissionStatus.serviceDisabled;

      final permission = await Geolocator.requestPermission();
      return _mapPermission(permission);
    } catch (_) {
      return LocationPermissionStatus.denied;
    }
  }

  /// Returns the device's current position, or [null] when:
  /// - permission is denied / permanently denied,
  /// - location services are disabled,
  /// - the fix times out (8 s), or
  /// - any unexpected platform error occurs.
  ///
  /// Callers should fall back to [kSingaporeCbd] on [null].
  Future<LatLng?> currentPosition() async {
    try {
      final status = await currentPermissionStatus();
      if (status != LocationPermissionStatus.granted) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      // Covers TimeoutException, PermissionDeniedException, and any other
      // platform error.  Caller falls back to Singapore CBD.
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  LocationPermissionStatus _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.permanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }
}
