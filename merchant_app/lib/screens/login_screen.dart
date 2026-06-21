import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/notification_service.dart';

class MerchantLoginScreen extends StatefulWidget {
  const MerchantLoginScreen({super.key});

  @override
  State<MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<MerchantLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _login() async {
    if (_phoneCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final client = ApiClient();
      final res = await client.post('/auth/login', {
        'phone': _phoneCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });
      if (!mounted) return;

      if (res['token'] != null) {
        final role = res['user']?['role'];
        final isActive = res['user']?['is_active'] ?? false;

        if (role != 'merchant') {
          _showError('Akun ini bukan akun merchant');
          return;
        }
        await client.saveToken(res['token'], res['refresh_token']);
        await NotificationService.uploadToken(client);
        if (!isActive) {
          Navigator.pushReplacementNamed(context, '/pending');
          return;
        }
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError(res['error'] ?? 'Login gagal');
      }
    } catch (e) {
      _showError('Koneksi gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        final isActive = res['user']?['is_active'] ?? false;
        Navigator.pushReplacementNamed(context, isActive ? '/home' : '/pending');
      } else {
        _showError(res['error'] ?? 'Google login gagal');
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) _showError('Google login gagal: ${e.description}');
    } catch (e) {
      _showError('Google login gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.store, size: 80, color: KuwrirColors.primary),
              const SizedBox(height: 24),
              const Text('KUWRIR Merchant', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Kelola toko dan terima order', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 48),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nomor HP',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Login', style: TextStyle(fontSize: 16)),
                ),
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
