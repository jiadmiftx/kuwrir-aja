import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'onboarding_screen.dart';

/// Step 1 of driver registration: basic account info
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      _showError('Password dan konfirmasi tidak cocok');
      return;
    }

    setState(() => _loading = true);
    try {
      final client = ApiClient();
      final res = await client.post('/auth/register', {
        'name': _nameCtrl.text.trim(),
        'phone': _normalizedPhone(_phoneCtrl.text),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'role': 'driver',
      });

      if (!mounted) return;

      if (res['user'] != null) {
        if (res['token'] != null) {
          await client.saveToken(res['token'], res['refresh_token']);
        }
        final userID = res['user']['id'] as String;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverOnboardingScreen(
              userID: userID,
              userName: _nameCtrl.text.trim(),
            ),
          ),
        );
      } else {
        _showError(res['error'] ?? 'Registrasi gagal');
      }
    } catch (e) {
      _showError('Koneksi gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Normalizes an Indonesian phone number to canonical "+62xxxxxxxxxx"
  /// format: strips all non-digit characters, strips a leading "0", and
  /// prefixes with "+62".
  String _normalizedPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+62$digits';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: KuwrirColors.error),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    _passwordCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(title: const Text('Daftar sebagai Driver')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress indicator
              _buildStepIndicator(1),
              const SizedBox(height: 24),

              Text(
                'DATA DIRI',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: KuwrirColors.textHint,
                ),
              ),
              const SizedBox(height: 12),

              _field(_nameCtrl, 'Nama Lengkap', HugeIcons.strokeRoundedUser,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Nama wajib diisi' : null),
              const SizedBox(height: 12),
              _field(_phoneCtrl, 'Nomor HP', HugeIcons.strokeRoundedCall,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v?.trim().length ?? 0) < 9 ? 'Nomor HP tidak valid' : null),
              const SizedBox(height: 12),
              _field(_emailCtrl, 'Email', HugeIcons.strokeRoundedMail01,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v?.contains('@') ?? false) ? null : 'Email tidak valid'),
              const SizedBox(height: 12),
              _field(_passwordCtrl, 'Password', HugeIcons.strokeRoundedSquareLock01,
                  obscure: _obscure,
                  suffixIcon: IconButton(
                    icon: HugeIcon(
                      icon: _obscure ? HugeIcons.strokeRoundedViewOffSlash : HugeIcons.strokeRoundedView,
                      color: KuwrirColors.textHint,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) => (v?.length ?? 0) < 6 ? 'Minimal 6 karakter' : null),
              const SizedBox(height: 12),
              _field(_confirmCtrl, 'Konfirmasi Password', HugeIcons.strokeRoundedSquareLock01,
                  obscure: true,
                  validator: (v) => v != _passwordCtrl.text ? 'Password tidak cocok' : null),
              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: KuwrirColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Lanjut', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Sudah punya akun? Login',
                  style: TextStyle(color: KuwrirColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    List<List<dynamic>> icon, {
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: KuwrirColors.textHint),
          prefixIcon: HugeIcon(icon: icon, color: KuwrirColors.primary),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: false,
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current) {
    final steps = ['Akun', 'Dokumen', 'Menunggu'];
    return Row(
      children: List.generate(steps.length, (i) {
        final step = i + 1;
        final done = step < current;
        final active = step == current;
        return Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: done || active ? KuwrirColors.primary : KuwrirColors.border,
                child: done
                    ? const HugeIcon(icon: HugeIcons.strokeRoundedTick02, size: 14, color: Colors.white)
                    : Text('$step', style: TextStyle(color: active ? Colors.white : KuwrirColors.textHint, fontSize: 12)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(steps[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? KuwrirColors.primary : KuwrirColors.textHint,
                      fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                    )),
              ),
              if (i < steps.length - 1)
                Expanded(child: Container(height: 1, color: KuwrirColors.border)),
            ],
          ),
        );
      }),
    );
  }
}
