import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../theme/kuwrir_colors.dart';

enum _OtpStep { phone, code }

/// Reusable phone-entry -> code-entry -> resend-cooldown flow, shared by
/// every app's login screen (verify == log in) and customer_app's
/// mandatory phone-verification gate (verify == attach+verify a phone on an
/// already-authenticated account). Only [onVerify] and the header copy
/// differ between call sites; requesting the OTP itself is identical
/// everywhere.
class OtpFlow extends StatefulWidget {
  /// Called with the entered phone + code. Throw to show an error (the
  /// exception's message, or a plain string, is shown via SnackBar) —
  /// returning normally means success, and the caller is responsible for
  /// whatever happens next (navigate, pop, reload session, etc).
  final Future<void> Function(String phone, String code) onVerify;
  final String headerTitle;
  final String headerSubtitle;
  final String verifyButtonLabel;

  const OtpFlow({
    super.key,
    required this.onVerify,
    this.headerTitle = 'Masukkan nomor HP kamu',
    this.headerSubtitle = 'Kode OTP akan dikirim lewat WhatsApp ke nomor ini',
    this.verifyButtonLabel = 'Verifikasi',
  });

  @override
  State<OtpFlow> createState() => _OtpFlowState();
}

class _OtpFlowState extends State<OtpFlow> {
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

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.onVerify(_phoneCtrl.text.trim(), code);
    } catch (e) {
      if (mounted) _showError(e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _step == _OtpStep.phone ? _buildPhoneStep() : _buildCodeStep(),
    );
  }

  List<Widget> _buildPhoneStep() {
    return [
      const SizedBox(height: 24),
      const Icon(Icons.sms_outlined, size: 56, color: KuwrirColors.primary),
      const SizedBox(height: 16),
      Text(widget.headerTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(widget.headerSubtitle,
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
        onSubmitted: (_) => _verify(),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: _loading ? null : _verify,
          child: _loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.verifyButtonLabel, style: const TextStyle(fontSize: 16)),
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
