import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'location_picker_screen.dart';
import 'pending_screen.dart';

/// Merchant registration: data diri + data toko + upload 3 dokumen
/// Single-step form (semua sekaligus)
class MerchantRegisterScreen extends StatefulWidget {
  /// Step to start at. Use 1 to skip account creation (e.g. after OTP
  /// login already created the user account) and go straight to store info.
  final int startAtStep;

  const MerchantRegisterScreen({super.key, this.startAtStep = 0});

  @override
  State<MerchantRegisterScreen> createState() => _MerchantRegisterScreenState();
}

class _MerchantRegisterScreenState extends State<MerchantRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late int _step; // 0: akun, 1: toko, 2: dokumen

  @override
  void initState() {
    super.initState();
    _step = widget.startAtStep;
  }

  // Akun
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  // Toko
  final _storeNameCtrl = TextEditingController();
  final _storeDescCtrl = TextEditingController();
  final _storePhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  double _storeLat = -8.8953;
  double _storeLng = 116.2833;

  // Dokumen
  File? _ktpFile;
  File? _bizLicenseFile;
  File? _storePhotoFile;

  bool _loading = false;
  final _picker = ImagePicker();

  Future<void> _pick(String docType) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Foto'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeri'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;
    final xfile = await _picker.pickImage(source: src, imageQuality: 80, maxWidth: 1200);
    if (xfile == null) return;
    setState(() {
      switch (docType) {
        case 'ktp':   _ktpFile = File(xfile.path); break;
        case 'biz':   _bizLicenseFile = File(xfile.path); break;
        case 'store': _storePhotoFile = File(xfile.path); break;
      }
    });
  }

  // Step 0: register user account
  Future<void> _registerAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final client = ApiClient();
      final res = await client.post('/auth/register', {
        'name': _nameCtrl.text.trim(),
        'phone': _normalizedPhone(_phoneCtrl.text),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'role': 'merchant',
      });
      if (res['user'] != null) {
        if (res['token'] != null) {
          await client.saveToken(res['token'], res['refresh_token']);
        }
        setState(() { _step = 1; });
      } else {
        _showError(res['error'] ?? 'Registrasi gagal');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Step 2: submit store + docs via multipart
  Future<void> _submitStore() async {
    if (_ktpFile == null || _storePhotoFile == null) {
      _showError('KTP dan foto toko wajib diupload');
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await ApiClient().getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/my-store');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['name'] = _storeNameCtrl.text.trim()
        ..fields['description'] = _storeDescCtrl.text.trim()
        ..fields['phone'] = _storePhoneCtrl.text.trim()
        ..fields['address'] = _addressCtrl.text.trim()
        ..fields['latitude'] = _storeLat.toString()
        ..fields['longitude'] = _storeLng.toString();

      req.files.add(await http.MultipartFile.fromPath('owner_ktp', _ktpFile!.path));
      req.files.add(await http.MultipartFile.fromPath('store_photo', _storePhotoFile!.path));
      if (_bizLicenseFile != null) {
        req.files.add(await http.MultipartFile.fromPath('business_license', _bizLicenseFile!.path));
      }

      final streamed = await req.send();
      if (!mounted) return;

      if (streamed.statusCode == 201) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MerchantPendingScreen()));
      } else {
        final body = await streamed.stream.bytesToString();
        _showError('Gagal: $body');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Normalizes a raw phone number input to canonical "+62xxxxxxxxxx"
  /// format: strips all non-digit characters, drops a leading "0" if
  /// present, and prefixes "+62" (Indonesian numbers only — this is a
  /// Lombok-based platform). The backend now normalizes phone numbers
  /// server-side too, but sending a consistent format keeps client-side
  /// display/logging sane.
  String _normalizedPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    } else if (digits.startsWith('62')) {
      digits = digits.substring(2);
    }
    return '+62$digits';
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: KuwrirColors.error));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Daftar sebagai Merchant'),
        backgroundColor: KuwrirColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSteps(),
              const SizedBox(height: 28),
              if (_step == 0) _buildAccountStep(),
              if (_step == 1) _buildStoreStep(),
              if (_step == 2) _buildDocsStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Data Pemilik',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: KuwrirColors.textPrimary)),
        const SizedBox(height: 18),
        _field(_nameCtrl, 'Nama Lengkap', Icons.person_outline,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 12),
        _field(_phoneCtrl, 'Nomor HP', Icons.phone_outlined, keyboardType: TextInputType.phone,
            hint: 'Boleh format apa saja, mis. 08xxx atau +62 8xxx',
            validator: (v) => (v?.length ?? 0) < 9 ? 'Tidak valid' : null),
        const SizedBox(height: 12),
        _field(_emailCtrl, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress,
            validator: (v) => !(v?.contains('@') ?? false) ? 'Email tidak valid' : null),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: KuwrirColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KuwrirColors.border),
          ),
          child: TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 karakter' : null,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, color: KuwrirColors.textHint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: KuwrirColors.textHint),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KuwrirColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _loading ? null : _registerAccount,
            child: _loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Lanjut', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: KuwrirColors.textSecondary),
          child: const Text('Sudah punya akun? Login'),
        ),
      ],
    );
  }

  Widget _buildStoreStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Data Toko',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: KuwrirColors.textPrimary)),
        const SizedBox(height: 18),
        _field(_storeNameCtrl, 'Nama Toko', Icons.storefront_outlined,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 12),
        _field(_storeDescCtrl, 'Deskripsi Toko', Icons.description_outlined),
        const SizedBox(height: 12),
        _field(_storePhoneCtrl, 'Nomor HP Toko', Icons.phone_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        _field(_addressCtrl, 'Alamat Lengkap', Icons.location_on_outlined,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 12),
        // Map location picker
        Container(
          decoration: BoxDecoration(
            color: KuwrirColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KuwrirColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push<LatLng>(
                context,
                MaterialPageRoute(
                  builder: (_) => LocationPickerScreen(
                    initial: LatLng(_storeLat, _storeLng),
                  ),
                ),
              );
              if (result != null) {
                setState(() {
                  _storeLat = result.latitude;
                  _storeLng = result.longitude;
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: KuwrirColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.map_outlined, color: KuwrirColors.primary, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lokasi Toko di Peta',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14.5, color: KuwrirColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          '${_storeLat.toStringAsFixed(5)}, ${_storeLng.toStringAsFixed(5)}',
                          style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: KuwrirColors.textHint),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('Ketuk untuk memilih lokasi toko di peta',
            style: TextStyle(color: KuwrirColors.textHint, fontSize: 12)),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KuwrirColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              if (_storeNameCtrl.text.trim().isEmpty || _addressCtrl.text.trim().isEmpty) {
                _showError('Nama toko dan alamat wajib diisi');
                return;
              }
              setState(() => _step = 2);
            },
            child: const Text('Lanjut', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        // No "Kembali" when entering here via OTP (startAtStep > 0)
        // — the account is already created and this screen replaced login
        // in the nav stack, so there's nothing valid to pop back to.
        if (widget.startAtStep == 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: KuwrirColors.textPrimary,
                side: BorderSide(color: KuwrirColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => setState(() => _step = 0),
              child: const Text('Kembali', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Dokumen Verifikasi',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: KuwrirColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Dokumen diperlukan untuk verifikasi toko oleh admin.',
            style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 18),
        _docTile('KTP Pemilik *', 'Foto KTP pemilik toko yang jelas', Icons.badge_outlined, _ktpFile, () => _pick('ktp')),
        _docTile('Izin Usaha (opsional)', 'SIUP / IUMK / NIB jika ada', Icons.business_center_outlined, _bizLicenseFile, () => _pick('biz')),
        _docTile('Foto Toko *', 'Foto tampak depan toko / tempat jualan', Icons.store_outlined, _storePhotoFile, () => _pick('store')),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KuwrirColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _loading ? null : _submitStore,
            child: _loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Kirim Pendaftaran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: KuwrirColors.textPrimary,
              side: BorderSide(color: KuwrirColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => setState(() => _step = 1),
            child: const Text('Kembali', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _docTile(String title, String subtitle, IconData icon, File? file, VoidCallback onTap) {
    final uploaded = file != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: uploaded
              ? KuwrirColors.success.withValues(alpha: 0.1)
              : KuwrirColors.primary.withValues(alpha: 0.08),
          backgroundImage: uploaded ? FileImage(file) : null,
          child: uploaded ? null : Icon(icon, color: KuwrirColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        subtitle: Text(uploaded ? 'Siap' : subtitle,
            style: TextStyle(
                fontSize: 12, color: uploaded ? KuwrirColors.success : KuwrirColors.textSecondary)),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(uploaded ? 'Ganti' : 'Upload',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: uploaded ? KuwrirColors.success : KuwrirColors.primary)),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator, String? hint}) {
    return Container(
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: KuwrirColors.textHint),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSteps() {
    final steps = ['Akun', 'Toko', 'Dokumen'];
    return Row(
      children: List.generate(steps.length, (i) {
        final done = i < _step;
        final active = i == _step;
        return Expanded(child: Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: done || active ? KuwrirColors.primary : KuwrirColors.border,
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('${i + 1}',
                    style: TextStyle(
                        color: active ? Colors.white : KuwrirColors.textHint, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(steps[i],
                style: TextStyle(
                    fontSize: 12,
                    color: active ? KuwrirColors.primary : KuwrirColors.textHint,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ),
          if (i < steps.length - 1) Expanded(child: Container(height: 1, color: KuwrirColors.border)),
        ]));
      }),
    );
  }
}
