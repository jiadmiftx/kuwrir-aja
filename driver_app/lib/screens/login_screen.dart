import 'package:flutter/material.dart';

import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/notification_service.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _handleOtpVerify(String phone, String code) async {
    final client = ApiClient();
    final res = await client.verifyOtp(phone, code, role: 'driver');
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

    final hasDriverProfile = res['has_driver_profile'] ?? false;
    if (!hasDriverProfile) {
      final userID = res['user']?['id'] as String?;
      final userName = res['user']?['name'] as String? ?? '';
      if (userID != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DriverOnboardingScreen(userID: userID, userName: userName)),
        );
        return;
      }
    }
    Navigator.pushReplacementNamed(context, '/job_board');
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
                headerSubtitle: 'Kode OTP dikirim lewat WhatsApp — nomor baru otomatis terdaftar',
                verifyButtonLabel: 'Masuk',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
