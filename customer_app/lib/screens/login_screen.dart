import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/notification_service.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  bool _googleLoading = false;

  Future<void> _handleOtpVerify(String phone, String code) async {
    final client = ApiClient();
    final res = await client.verifyOtp(phone, code);
    if (!mounted) return;
    if (res['token'] == null) {
      throw res['error'] ?? 'Verifikasi gagal';
    }
    await client.saveToken(res['token'], res['refresh_token'] ?? '');
    await NotificationService.uploadToken(client);
    if (!mounted) return;
    await maybePromptBiometricOptIn(context);
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await GoogleSignIn.instance.initialize(serverClientId: '55640900910-02las0a6avljfjke7h9cnd2ntrdqgmui.apps.googleusercontent.com');
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        _showError('Gagal mendapatkan token Google');
        return;
      }

      final client = ApiClient();
      final res = await client.googleLogin(idToken, 'customer');
      if (!mounted) return;

      if (res['token'] != null) {
        await client.saveToken(res['token'], res['refresh_token'] ?? '');
        await NotificationService.uploadToken(client);
        if (!mounted) return;
        await maybePromptBiometricOptIn(context);
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError(res['error'] ?? 'Google login gagal');
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _showError('Google login gagal: ${e.description}');
      }
    } catch (e) {
      _showError('Google login gagal: $e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Center(
                child: SvgPicture.asset('assets/images/logo_cocourir.svg', height: 64),
              ),
              const SizedBox(height: 16),
              const Text('Pesan makanan, terima di depan pintu',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              OtpFlow(
                onVerify: _handleOtpVerify,
                headerTitle: 'Masuk atau daftar dengan nomor HP',
                headerSubtitle: 'Kode OTP dikirim lewat WhatsApp — nomor baru otomatis terdaftar',
                verifyButtonLabel: 'Masuk',
              ),
              const SizedBox(height: 12),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('atau', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _googleLoading ? null : _loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _googleLoading
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Masuk dengan Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
