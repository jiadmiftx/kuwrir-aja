import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/session_cubit.dart';

/// Mandatory, non-dismissible phone verification — shown by HomeScreen for
/// any logged-in user whose account has no verified real phone (e.g. a
/// password-registered account that never completed an OTP check). Blocks
/// the rest of the app until the user completes a real OTP check.
class PhoneVerificationGate extends StatelessWidget {
  const PhoneVerificationGate({super.key});

  Future<void> _handleVerify(
    BuildContext context,
    String phone,
    String code,
  ) async {
    final client = ApiClient();
    await client.verifyMyPhone(phone, code);
    if (!context.mounted) return;
    await context.read<SessionCubit>().load();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedShieldUser,
                  size: 48,
                  color: KuwrirColors.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Verifikasi Nomor HP Wajib',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Untuk keamanan akun dan komunikasi terkait pesanan, verifikasi nomor HP kamu dulu sebelum melanjutkan.',
                  style: TextStyle(color: KuwrirColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OtpFlow(
                  onVerify: (phone, code) =>
                      _handleVerify(context, phone, code),
                  headerTitle: 'Masukkan nomor HP kamu',
                  headerSubtitle:
                      'Kode OTP akan dikirim lewat WhatsApp ke nomor ini',
                  verifyButtonLabel: 'Verifikasi Nomor',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
