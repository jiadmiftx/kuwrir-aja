import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/notification_service.dart';
import 'register_screen.dart';

class MerchantLoginScreen extends StatefulWidget {
  const MerchantLoginScreen({super.key});

  @override
  State<MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<MerchantLoginScreen> {
  Future<void> _handleOtpVerify(String phone, String code) async {
    final client = ApiClient();
    final res = await client.verifyOtp(phone, code, role: 'merchant');
    if (!mounted) return;
    if (res['token'] == null) {
      throw res['error'] ?? 'Verifikasi gagal';
    }
    // Note: res['user']['role'] reflects the account's original/primary
    // role (e.g. "customer" if this phone first registered as a customer
    // elsewhere) — the backend auto-attaches the merchant role to whatever
    // account already owns this phone number, and the JWT in res['token']
    // is scoped to "merchant" for this session regardless of that field.
    // No client-side role-equality check needed here.
    await client.saveToken(res['token'], res['refresh_token'] ?? '');
    await NotificationService.uploadToken(client);
    if (!mounted) return;
    await maybePromptBiometricOptIn(context);
    if (!mounted) return;
    await _routeAfterAuth(client, res);
  }

  /// Post-login routing: decides between the registration form, the
  /// pending-verification screen, and Home. user.is_active only means
  /// "this login account is enabled" (true since account creation); it
  /// says nothing about store approval, so that must never be used to
  /// unlock Home directly.
  Future<void> _routeAfterAuth(ApiClient client, Map<String, dynamic> res) async {
    final hasMerchantProfile = res['has_merchant_profile'] ?? false;
    if (!hasMerchantProfile) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MerchantRegisterScreen(startAtStep: 1)),
      );
      return;
    }
    var approved = false;
    try {
      final statusRes = await client.get('/my-store/status');
      approved = statusRes['status'] == 'approved' && statusRes['is_active'] == true;
    } catch (_) {
      // Treat an unreachable status check as not-yet-approved rather than
      // silently granting Home access.
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, approved ? '/home' : '/pending');
  }

  static const _forestSoft = Color(0xFFDCEEE2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _LogoBadge(soft: _forestSoft),
                  const SizedBox(height: 28),
                  const Text(
                    'Masuk ke Akun Toko',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: KuwrirColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pakai nomor HP tokomu untuk masuk',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, color: KuwrirColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  OtpFlow(
                    onVerify: _handleOtpVerify,
                    verifyButtonLabel: 'Masuk',
                    showHeaderIcon: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft two-layer badge (tinted halo + white disc with a soft colored
/// shadow) — same motif as the pending-verification screen, in the app's
/// forest-green brand tone, so the two screens read as one continuous
/// identity moment.
class _LogoBadge extends StatelessWidget {
  final Color soft;
  const _LogoBadge({required this.soft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(shape: BoxShape.circle, color: soft),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KuwrirColors.surface,
              boxShadow: [
                BoxShadow(
                  color: KuwrirColors.primary.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: ClipOval(
              child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}
