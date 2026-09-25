import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;

  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapCtrl = MapController();
  bool _mapReady = false;

  LatLng _picked = const LatLng(
    -6.2088,
    106.8456,
  ); // fallback: Jakarta, diganti GPS otomatis
  String _address = 'Pilih lokasi di peta';
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _picked = widget.initial!;
  }

  void _onMapReady() {
    _mapReady = true;
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = loc);
      if (_mapReady) _mapCtrl.move(loc, 16);
      await _resolveAddress(loc);
    } catch (_) {}
  }

  Future<void> _resolveAddress(LatLng loc) async {
    if (!mounted) return;
    setState(() => _resolving = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );
      if (!mounted) return;
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.subAdministrativeArea,
        ].where((s) => s != null && s.isNotEmpty).toList();
        setState(() => _address = parts.join(', '));
      }
    } catch (_) {
      if (!mounted) return;
      // Never show raw lat/lng to the user — fall back to a friendly label.
      setState(() => _address = 'Lokasi dipilih di peta');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _onTap(TapPosition _, LatLng loc) {
    setState(() => _picked = loc);
    _resolveAddress(loc);
  }

  void _centerOnUser() => _getUserLocation();

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi Pengiriman'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'latlng': _picked,
              'address': _address,
            }),
            child: const Text(
              'Pilih',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _picked,
              initialZoom: 15,
              onTap: _onTap,
              onMapReady: _onMapReady,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kuwrir.customer',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked,
                    width: 48,
                    height: 48,
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedMapPin,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Bottom address card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedLocation01,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _resolving
                            ? const Text(
                                'Mendapatkan alamat...',
                                style: TextStyle(color: Colors.grey),
                              )
                            : Text(
                                _address,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ketuk peta untuk memilih titik pengiriman',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          // GPS button
          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton.small(
              heroTag: 'gps_btn',
              onPressed: _centerOnUser,
              child: const HugeIcon(icon: HugeIcons.strokeRoundedGpsSignal01),
            ),
          ),
        ],
      ),
    );
  }
}
