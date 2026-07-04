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
    final res = await client.verifyOtp(phone, code);
    if (!mounted) return;
    if (res['token'] == null) {
      throw res['error'] ?? 'Verifikasi gagal';
    }
    final role = res['user']?['role'];
    if (role != 'merchant') {
      throw 'Akun ini bukan akun merchant';
    }
    final isActive = res['user']?['is_active'] ?? false;
    await client.saveToken(res['token'], res['refresh_token'] ?? '');
    await NotificationService.uploadToken(client);
    if (!mounted) return;
    await maybePromptBiometricOptIn(context);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, isActive ? '/home' : '/pending');
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
        final hasMerchantProfile = res['has_merchant_profile'] ?? false;
        if (!hasMerchantProfile) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MerchantRegisterScreen(startAtStep: 1)),
          );
          return;
        }
        final isActive = res['user']?['is_active'] ?? false;
        Navigator.pushReplacementNamed(context, isActive ? '/home' : '/pending');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/images/app_icon.png', width: 88, height: 88),
                ),
              ),
              const SizedBox(height: 24),
              const Text('KUWRIR Merchant', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Kelola toko dan terima order', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              OtpFlow(
                onVerify: _handleOtpVerify,
                headerTitle: 'Masuk dengan nomor HP toko',
                headerSubtitle: 'Kode OTP dikirim lewat WhatsApp',
                verifyButtonLabel: 'Masuk',
              ),
              const SizedBox(height: 12),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('atau', style: TextStyle(color: Colors.grey))),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Masuk dengan Google'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Belum punya toko? Daftar sekarang'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
