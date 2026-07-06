import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_client.dart';
import '../theme/kuwrir_colors.dart';

enum _OtpStep { phone, code }

class _Country {
  final String iso;
  final String name;
  final String dialCode;
  final String flag;
  const _Country(this.iso, this.name, this.dialCode, this.flag);
}

const _kCountries = [
  _Country('ID', 'Indonesia', '+62', '🇮🇩'),
  _Country('MY', 'Malaysia', '+60', '🇲🇾'),
  _Country('SG', 'Singapura', '+65', '🇸🇬'),
  _Country('TL', 'Timor Leste', '+670', '🇹🇱'),
  _Country('AU', 'Australia', '+61', '🇦🇺'),
  _Country('US', 'Amerika Serikat', '+1', '🇺🇸'),
  _Country('GB', 'Inggris Raya', '+44', '🇬🇧'),
  _Country('NL', 'Belanda', '+31', '🇳🇱'),
];

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

  /// Set false when the calling page already shows its own icon/title
  /// above this widget — avoids two icon+heading blocks stacking on top
  /// of each other. The code step still shows which phone number the code
  /// went to either way, since that's information, not decoration.
  final bool showHeaderIcon;

  /// Shows a tappable country-dial-code chip (flag + code) in front of the
  /// phone field, defaulting to Indonesia (+62). The number sent to the
  /// backend for Indonesia is still composed in the app's original local
  /// format (leading "0", no "+62") so existing accounts keep matching —
  /// only non-Indonesia codes are sent with an explicit dial-code prefix.
  final bool showCountryCode;

  const OtpFlow({
    super.key,
    required this.onVerify,
    this.headerTitle = 'Masukkan nomor HP kamu',
    this.headerSubtitle = 'Kode OTP akan dikirim lewat WhatsApp ke nomor ini',
    this.verifyButtonLabel = 'Verifikasi',
    this.showHeaderIcon = true,
    this.showCountryCode = false,
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
  _Country _country = _kCountries.first;

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

  /// Backend phone string. Indonesia keeps the legacy "0-prefixed" local
  /// format already stored for every existing account; other countries use
  /// an explicit dial-code prefix (e.g. "+60") since there's no legacy data
  /// to match.
  String _backendPhone() {
    final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (!widget.showCountryCode) return digits;
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return _country.dialCode == '+62' ? '0$local' : '${_country.dialCode}$local';
  }

  /// User-facing phone string shown on the code step ("kode dikirim ke...").
  String _displayPhone() {
    if (!widget.showCountryCode) return _phoneCtrl.text.trim();
    final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return '${_country.dialCode} $local';
  }

  Future<void> _requestOtp() async {
    if (_phoneCtrl.text.trim().isEmpty) return;
    final phone = _backendPhone();
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
      await widget.onVerify(_backendPhone(), code);
    } catch (e) {
      if (mounted) _showError(e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCountry() async {
    final searchCtrl = TextEditingController();
    final picked = await showModalBottomSheet<_Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? _kCountries
              : _kCountries
                  .where((c) =>
                      c.name.toLowerCase().contains(query) || c.dialCode.contains(query))
                  .toList();
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
            decoration: const BoxDecoration(
              color: KuwrirColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: KuwrirColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Pilih Kode Negara',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: false,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Cari negara',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                          title: Text(c.name, style: const TextStyle(fontSize: 14.5)),
                          trailing: Text(c.dialCode,
                              style: TextStyle(color: KuwrirColors.textSecondary, fontWeight: FontWeight.w600)),
                          onTap: () => Navigator.pop(sheetContext, c),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked != null) setState(() => _country = picked);
  }

  Widget _countryChip() {
    return InkWell(
      onTap: _pickCountry,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KuwrirColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_country.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(_country.dialCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 18, color: KuwrirColors.textHint),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _step == _OtpStep.phone ? _buildPhoneStep() : _buildCodeStep(),
    );
  }

  List<Widget> _buildPhoneStep() {
    final phoneField = TextField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Nomor HP',
        hintText: widget.showCountryCode ? '812xxxxxxxx' : '08xxxxxxxxxx',
        prefixIcon: widget.showCountryCode ? null : const Icon(Icons.phone),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onSubmitted: (_) => _requestOtp(),
    );

    return [
      if (widget.showHeaderIcon) ...[
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
      ],
      widget.showCountryCode
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _countryChip(),
                const SizedBox(width: 10),
                Expanded(child: phoneField),
              ],
            )
          : phoneField,
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
      if (widget.showHeaderIcon) ...[
        const SizedBox(height: 24),
        const Icon(Icons.mark_email_read_outlined, size: 56, color: KuwrirColors.primary),
        const SizedBox(height: 16),
        const Text('Masukkan kode OTP',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
      ] else
        const SizedBox(height: 4),
      Text('Kode dikirim lewat WhatsApp ke ${_displayPhone()}',
          style: TextStyle(color: KuwrirColors.textSecondary, fontSize: widget.showHeaderIcon ? 14 : 13.5),
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
