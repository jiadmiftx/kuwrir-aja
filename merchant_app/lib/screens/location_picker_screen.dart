import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;

  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapCtrl = MapController();
  bool _mapReady = false;

  LatLng _picked = const LatLng(-6.2088, 106.8456); // fallback: Jakarta, diganti GPS otomatis

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
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;

      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = loc);
      if (_mapReady) _mapCtrl.move(loc, 16);
    } catch (_) {}
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Pilih Lokasi Toko'),
        backgroundColor: KuwrirColors.background,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _picked),
            style: TextButton.styleFrom(foregroundColor: KuwrirColors.primary),
            child: const Text('Pilih', style: TextStyle(fontWeight: FontWeight.w700)),
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
              onTap: (_, loc) => setState(() => _picked = loc),
              onMapReady: _onMapReady,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kuwrir.merchant',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked,
                    width: 48,
                    height: 48,
                    child: Icon(Icons.store_mall_directory,
                        color: KuwrirColors.primary, size: 48),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              decoration: BoxDecoration(
                color: KuwrirColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: KuwrirColors.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: KuwrirColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.location_on_outlined, color: KuwrirColors.primary, size: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_picked.latitude.toStringAsFixed(6)}, ${_picked.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: KuwrirColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Ketuk peta untuk menandai lokasi toko',
                      style: TextStyle(fontSize: 12, color: KuwrirColors.textHint)),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 128,
            child: FloatingActionButton.small(
              heroTag: 'gps_btn',
              onPressed: _getUserLocation,
              backgroundColor: KuwrirColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
