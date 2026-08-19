import 'package:geolocator/geolocator.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Best-effort driver location reporting — a single GPS fix sent as a
/// side-effect of things that already happen (going online, accepting a
/// job, marking pickup/delivered) plus a light foreground poll while
/// online, not a continuous background stream. This is deliberately cheap:
/// no background service, no wake locks, no extra permission beyond the
/// foreground ACCESS_FINE_LOCATION/ACCESS_COARSE_LOCATION driver_app
/// already declares. A failure here (permission denied, GPS off, no
/// signal) is silently swallowed — it should never block the action it's
/// attached to.
class LocationService {
  static Future<void> sendCurrentLocation(ApiClient api) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      await api.updateDriverLocation(position.latitude, position.longitude);
    } catch (_) {
      // Best-effort — see class doc comment.
    }
  }
}
