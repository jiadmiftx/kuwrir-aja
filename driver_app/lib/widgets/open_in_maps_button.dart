import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device's Google Maps app (or a browser fallback) with a 1-tap
/// driving route: driver's current position -> merchant -> customer. `origin`
/// is deliberately omitted from the deep link so Google Maps supplies live
/// device location itself — no billing, no Directions API key, no client-side
/// location tracking needed. Plain https deep link, Google Maps computes the
/// route itself.
///
/// Calls `launchUrl` directly instead of gating on `canLaunchUrl` first —
/// `canLaunchUrl` needs a matching `<queries>` entry in AndroidManifest.xml
/// (Android 11+ package visibility) to even report an https handler exists,
/// and a missing/incomplete entry makes it silently return false, which
/// made this button do nothing with no error shown. `launchUrl` itself
/// throws instead, so a real failure is at least reported to [context].
Future<void> openInGoogleMaps({
  required BuildContext context,
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
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka Google Maps')),
      );
    }
  }
}

/// Small pill button — "open in Google Maps" as a discoverable, one-tap CTA.
/// Used floating over the active-delivery map, where a raised pill against
/// varying map tile colors earns its elevation. [iconOnly] drops the pill
/// and label entirely for contexts already dense with actions (job board
/// cards) — just the icon, no shadow.
class OpenInMapsButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool filled;
  final bool iconOnly;
  const OpenInMapsButton({
    super.key,
    required this.onTap,
    this.filled = false,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        tooltip: 'Buka di Google Maps',
        onPressed: onTap,
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedMaps,
          size: 20,
          color: KuwrirColors.primary,
        ),
      );
    }
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
              HugeIcon(
                icon: HugeIcons.strokeRoundedMaps,
                size: 16,
                color: KuwrirColors.primary,
              ),
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
