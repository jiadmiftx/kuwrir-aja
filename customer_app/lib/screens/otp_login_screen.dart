import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/notification_service.dart';

enum _OtpStep { phone, code }

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _client = ApiClient();

  _OtpStep _step = _OtpStep.phone;
  bool _loading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _startResendCooldown() {
    setState(() => _resendSeconds = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds <= 1) {
          _resendSeconds = 0;
          timer.cancel();
        } else {
          _resendSeconds--;
        }
      });
    });
  }

  Future<void> _requestOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await _client.requestOtp(phone);
      if (!mounted) return;
      if (res['error'] != null) {
        _showError(res['error']);
        return;
      }
      setState(() => _step = _OtpStep.code);
      _startResendCooldown();
      // Debug-only convenience: the backend only includes this field when
      // running in debug mode, so this never fires against production.
      if (kDebugMode && res['debug_code'] != null) {
        _showError('Debug OTP: ${res['debug_code']}');
      }
    } catch (e) {
      if (mounted) _showError('Gagal mengirim OTP: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await _client.verifyOtp(_phoneCtrl.text.trim(), code);
      if (!mounted) return;
      if (res['token'] != null) {
        await _client.saveToken(res['token'], res['refresh_token'] ?? '');
        await NotificationService.uploadToken(_client);
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError(res['error'] ?? 'Verifikasi gagal');
      }
    } catch (e) {
      if (mounted) _showError('Verifikasi gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk dengan OTP WhatsApp')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _step == _OtpStep.phone ? _buildPhoneStep() : _buildCodeStep(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPhoneStep() {
    return [
      const SizedBox(height: 24),
      const Icon(Icons.sms_outlined, size: 56, color: KuwrirColors.primary),
      const SizedBox(height: 16),
      const Text('Masukkan nomor HP kamu',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('Kode OTP akan dikirim lewat WhatsApp ke nomor ini',
          style: TextStyle(color: KuwrirColors.textSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 32),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: 'Nomor HP',
          hintText: '08xxxxxxxxxx',
          prefixIcon: const Icon(Icons.phone),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onSubmitted: (_) => _requestOtp(),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: _loading ? null : _requestOtp,
          child: _loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Kirim Kode OTP', style: TextStyle(fontSize: 16)),
        ),
      ),
    ];
  }

  List<Widget> _buildCodeStep() {
    return [
      const SizedBox(height: 24),
      const Icon(Icons.mark_email_read_outlined, size: 56, color: KuwrirColors.primary),
      const SizedBox(height: 16),
      const Text('Masukkan kode OTP',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('Kode dikirim lewat WhatsApp ke ${_phoneCtrl.text.trim()}',
          style: TextStyle(color: KuwrirColors.textSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 32),
      TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          hintText: '000000',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onSubmitted: (_) => _verifyOtp(),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: _loading ? null : _verifyOtp,
          child: _loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Verifikasi', style: TextStyle(fontSize: 16)),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: (_loading || _resendSeconds > 0) ? null : _requestOtp,
          child: Text(_resendSeconds > 0
              ? 'Kirim ulang dalam ${_resendSeconds}s'
              : 'Kirim ulang kode'),
        ),
      ),
      Center(
        child: TextButton(
          onPressed: _loading ? null : () => setState(() => _step = _OtpStep.phone),
          child: const Text('Ganti nomor HP'),
        ),
      ),
    ];
  }
}
