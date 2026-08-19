import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device's Google Maps app (or a browser fallback) with a 1-tap
/// driving route: driver's current position -> merchant -> customer. `origin`
/// is deliberately omitted from the deep link so Google Maps supplies live
/// device location itself — no billing, no Directions API key, no client-side
/// location tracking needed. Plain https deep link, Google Maps computes the
/// route itself.
Future<void> openInGoogleMaps({
  required double merchantLat,
  required double merchantLng,
  required double customerLat,
  required double customerLng,
}) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&waypoints=$merchantLat,$merchantLng'
    '&destination=$customerLat,$customerLng'
    '&travelmode=driving',
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Small pill button — "open in Google Maps" as a discoverable, one-tap CTA.
/// Shared by the job board's order cards and the active-delivery detail map.
class OpenInMapsButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool filled;
  const OpenInMapsButton({super.key, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled
          ? KuwrirColors.primary.withValues(alpha: 0.1)
          : KuwrirColors.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: filled ? 0 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 16, color: KuwrirColors.primary),
              const SizedBox(width: 6),
              Text(
                'Buka di Google Maps',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: KuwrirColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
