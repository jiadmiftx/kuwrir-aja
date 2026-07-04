import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/notification_service.dart';
import 'register_screen.dart';

class MerchantLoginScreen extends StatefulWidget {
  const MerchantLoginScreen({super.key});

  @override
  State<MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<MerchantLoginScreen> {
  bool _loading = false;

  Future<void> _handleOtpVerify(String phone, String code) async {
    final client = ApiClient();
    final res = await client.verifyOtp(phone, code, role: 'merchant');
    if (!mounted) return;
    if (res['token'] == null) {
      throw res['error'] ?? 'Verifikasi gagal';
    }
    final role = res['user']?['role'];
    if (role != 'merchant') {
      throw 'Akun ini bukan akun merchant';
    }
    await client.saveToken(res['token'], res['refresh_token'] ?? '');
    await NotificationService.uploadToken(client);
    if (!mounted) return;
    await maybePromptBiometricOptIn(context);
    if (!mounted) return;
    await _routeAfterAuth(client, res);
  }

  /// Shared post-login routing for both OTP and Google — decides between
  /// the registration form, the pending-verification screen, and Home.
  /// user.is_active only means "this login account is enabled" (true
  /// since account creation); it says nothing about store approval, so
  /// that must never be used to unlock Home directly.
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

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      await GoogleSignIn.instance.initialize(serverClientId: '55640900910-02las0a6avljfjke7h9cnd2ntrdqgmui.apps.googleusercontent.com');
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) { _showError('Gagal mendapatkan token Google'); return; }

      final client = ApiClient();
      final res = await client.googleLogin(idToken, 'merchant');
      if (!mounted) return;
      if (res['token'] != null) {
        final role = res['user']?['role'];
        if (role != 'merchant') {
          _showError('Akun ini bukan akun merchant');
          return;
        }
        await client.saveToken(res['token'], res['refresh_token'] ?? '');
        await NotificationService.uploadToken(client);
        if (!mounted) return;
        await maybePromptBiometricOptIn(context);
        if (!mounted) return;
        await _routeAfterAuth(client, res);
      } else {
        _showError(res['error'] ?? 'Google login gagal');
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) _showError('Google login gagal: ${e.description}');
    } catch (e) {
      _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiException) return e.message;
    if (e.toString().contains('TimeoutException')) {
      return 'Koneksi lambat, coba lagi.';
    }
    return 'Terjadi kesalahan, periksa koneksi internet Anda.';
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

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
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Divider(color: KuwrirColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('atau', style: TextStyle(color: KuwrirColors.textHint, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: KuwrirColors.border)),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _loginWithGoogle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KuwrirColors.textPrimary,
                        side: BorderSide(color: KuwrirColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.g_mobiledata, size: 26),
                      label: const Text('Masuk dengan Google', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    ),
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
