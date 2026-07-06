import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationState {
  final double? lat;
  final double? lng;
  final String address;
  final bool detecting;

  const LocationState({
    this.lat,
    this.lng,
    this.address = 'Pilih lokasi',
    this.detecting = false,
  });

  bool get hasLocation => lat != null && lng != null;

  LocationState copyWith({double? lat, double? lng, String? address, bool? detecting}) =>
      LocationState(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        address: address ?? this.address,
        detecting: detecting ?? this.detecting,
      );
}

class LocationCubit extends Cubit<LocationState> {
  static const _keyLat = 'user_lat';
  static const _keyLng = 'user_lng';
  static const _keyAddress = 'user_address';

  // Mataram city center — used so nearby merchants still show when GPS
  // permission is denied or detection fails (e.g. a guest browsing before
  // ever granting location access), instead of leaving lat/lng null forever.
  static const _fallbackLat = -8.5833;
  static const _fallbackLng = 116.1167;
  static const _fallbackAddress = 'Mataram, NTB (perkiraan)';

  LocationCubit() : super(const LocationState(detecting: true));

  /// Called once on app start — loads saved location or falls back to GPS
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLat);
    final lng = prefs.getDouble(_keyLng);
    final address = prefs.getString(_keyAddress);

    if (lat != null && lng != null && address != null && address.isNotEmpty) {
      emit(LocationState(lat: lat, lng: lng, address: address));
      return;
    }

    await detectGps();
  }

  /// Request GPS and reverse-geocode to address
  Future<void> detectGps() async {
    emit(state.copyWith(detecting: true, address: 'Mendeteksi lokasi...'));
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _useFallback();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));

      final address = await _reverseGeocode(pos.latitude, pos.longitude);
      await _save(pos.latitude, pos.longitude, address);
      emit(LocationState(lat: pos.latitude, lng: pos.longitude, address: address));
    } catch (_) {
      _useFallback();
    }
  }

  /// Not persisted to prefs — a real GPS fix or manual pick should still be
  /// retried on the next app start rather than getting stuck on the default.
  void _useFallback() {
    emit(const LocationState(lat: _fallbackLat, lng: _fallbackLng, address: _fallbackAddress));
  }

  /// Called after user picks location on map
  Future<void> setLocation(double lat, double lng, String address) async {
    await _save(lat, lng, address);
    emit(LocationState(lat: lat, lng: lng, address: address));
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.thoroughfare,
          p.subLocality,
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
        ].where((s) => s != null && s.trim().isNotEmpty).cast<String>().toSet().take(2).toList();
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {}
    return 'Lokasi saat ini';
  }

  Future<void> _save(double lat, double lng, String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLat, lat);
    await prefs.setDouble(_keyLng, lng);
    await prefs.setString(_keyAddress, address);
  }
}
