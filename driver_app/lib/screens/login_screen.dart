import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleOtpVerify(String phone, String code) async {
    final client = ApiClient();
    final res = await client.verifyOtp(phone, code);
    if (!mounted) return;
    if (res['token'] == null) {
      throw res['error'] ?? 'Verifikasi gagal';
    }
    final role = res['user']?['role'];
    if (role != 'driver') {
      throw 'Akun ini bukan akun driver';
    }
    await client.saveToken(res['token'], res['refresh_token'] ?? '');
    await NotificationService.uploadToken(client);
    if (!mounted) return;
    await maybePromptBiometricOptIn(context);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/job_board');
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      await GoogleSignIn.instance.initialize(serverClientId: '55640900910-02las0a6avljfjke7h9cnd2ntrdqgmui.apps.googleusercontent.com');
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mendapatkan token Google')));
        return;
      }

      final client = ApiClient();
      final res = await client.googleLogin(idToken, 'driver');
      if (!mounted) return;
      if (res['token'] != null) {
        final role = res['user']?['role'];
        if (role != 'driver') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Akun ini bukan akun driver')));
          return;
        }
        await client.saveToken(res['token'], res['refresh_token'] ?? '');
        await NotificationService.uploadToken(client);
        if (!mounted) return;
        await maybePromptBiometricOptIn(context);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/job_board');
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google login gagal: ${e.description}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google login gagal: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
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
              const Text(
                'Kuwrir Driver',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: KuwrirColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to start earning',
                style: TextStyle(
                  fontSize: 16,
                  color: KuwrirColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OtpFlow(
                onVerify: _handleOtpVerify,
                headerTitle: 'Masuk dengan nomor HP driver',
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
                onPressed: _isLoading ? null : _handleGoogleLogin,
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
                child: const Text('Belum punya akun? Daftar sebagai Driver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
