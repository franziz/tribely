import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_service.dart';

/// Singleton [LocationService] provider.
///
/// Using [Provider] (not [StateProvider]) because [LocationService] is
/// stateless — it wraps platform calls and holds no mutable state.
final locationServiceProvider = Provider<LocationService>(
  (_) => LocationService(),
);
