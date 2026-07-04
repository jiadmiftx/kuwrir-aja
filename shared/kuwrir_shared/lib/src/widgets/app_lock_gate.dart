import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../api/api_client.dart';
import '../theme/kuwrir_colors.dart';

/// Shows a one-time "enable quick unlock?" dialog right after a fresh
/// login, if the device supports biometrics/device-lock and the user
/// hasn't already opted in. Call this from each app's login screen after
/// OTP/Google/password success, before navigating to Home. Declining just
/// leaves the flag unset — asked again on the next fresh login, never
/// persisted as a permanent "no".
Future<void> maybePromptBiometricOptIn(BuildContext context) async {
  final api = ApiClient();
  if (await api.isBiometricLockEnabled()) return;

  final auth = LocalAuthentication();
  bool supported;
  try {
    supported = (await auth.canCheckBiometrics) || (await auth.isDeviceSupported());
  } catch (_) {
    supported = false;
  }
  if (!supported || !context.mounted) return;

  final enable = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Aktifkan Kunci Cepat?'),
      content: const Text(
          'Masuk lebih praktis lain kali pakai Face ID/sidik jari atau kunci layar HP kamu, tanpa perlu OTP lagi.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, aktifkan')),
      ],
    ),
  );
  if (enable == true) {
    await api.setBiometricLockEnabled(true);
  }
}

/// Wraps an app's authenticated entry point (Home) with an opportunistic
/// biometric/device-lock check. Uses the OS's own Face ID/fingerprint
/// prompt, which itself falls back to the device's PIN/pattern/passcode
/// when no biometric sensor is enrolled or available — there is no custom
/// PIN system here. If the user never opted in (`isBiometricLockEnabled`)
/// or the device has no lock mechanism at all, this is a pure passthrough.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  final _auth = LocalAuthentication();
  final _api = ApiClient();

  bool _checking = true;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    final enabled = await _api.isBiometricLockEnabled();
    if (!enabled) {
      if (mounted) setState(() {
        _checking = false;
        _unlocked = true;
      });
      return;
    }
    await _attemptUnlock();
  }

  Future<void> _attemptUnlock() async {
    setState(() => _checking = true);
    bool success;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      if (!canCheck && !supported) {
        // No lock mechanism available on this device at all — never block.
        success = true;
      } else {
        success = await _auth.authenticate(
          localizedReason: 'Verifikasi untuk masuk ke akunmu',
          options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
        );
      }
    } catch (_) {
      // Platform not supported / plugin error — don't hold the user hostage.
      success = true;
    }
    if (mounted) setState(() {
      _checking = false;
      _unlocked = success;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_unlocked) {
      return widget.child;
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: KuwrirColors.primary),
                const SizedBox(height: 16),
                const Text('Verifikasi diperlukan untuk melanjutkan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _attemptUnlock,
                  child: const Text('Coba Lagi'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await _api.clearTokens();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                    }
                  },
                  child: const Text('Keluar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
