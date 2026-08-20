import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Normalizes an Indonesian phone number to the digits-only, country-code-
/// prefixed form wa.me expects (no "+"): strips non-digits, converts a
/// leading "0" to "62", leaves an already-62-prefixed number as is.
String _normalizedForWhatsApp(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) {
    digits = '62${digits.substring(1)}';
  } else if (!digits.startsWith('62')) {
    digits = '62$digits';
  }
  return digits;
}

/// Opens WhatsApp (or a browser fallback) with a chat pre-opened to [phone].
/// Best-effort — a launch failure just shows a snackbar instead of throwing.
Future<void> openWhatsApp(BuildContext context, String phone) async {
  if (phone.trim().isEmpty) return;
  final digits = _normalizedForWhatsApp(phone);
  final uri = Uri.parse('https://wa.me/$digits');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka WhatsApp')),
      );
    }
  }
}
