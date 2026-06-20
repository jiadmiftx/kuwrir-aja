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
  const MerchantRegisterScreen({super.key});

  @override
  State<MerchantRegisterScreen> createState() => _MerchantRegisterScreenState();
}

class _MerchantRegisterScreenState extends State<MerchantRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0; // 0: akun, 1: toko, 2: dokumen

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
        'phone': _phoneCtrl.text.trim(),
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

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar sebagai Merchant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSteps(),
              const SizedBox(height: 24),
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
        const Text('Data Pemilik', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _field(_nameCtrl, 'Nama Lengkap', Icons.person,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 12),
        _field(_phoneCtrl, 'Nomor HP', Icons.phone, keyboardType: TextInputType.phone,
            validator: (v) => (v?.length ?? 0) < 9 ? 'Tidak valid' : null),
        const SizedBox(height: 12),
        _field(_emailCtrl, 'Email', Icons.email, keyboardType: TextInputType.emailAddress,
            validator: (v) => !(v?.contains('@') ?? false) ? 'Email tidak valid' : null),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 karakter' : null,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(height: 50, child: FilledButton(
          onPressed: _loading ? null : _registerAccount,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Lanjut →'),
        )),
        const SizedBox(height: 12),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sudah punya akun? Login')),
      ],
    );
  }

  Widget _buildStoreStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Data Toko', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _field(_storeNameCtrl, 'Nama Toko', Icons.store,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 12),
        _field(_storeDescCtrl, 'Deskripsi Toko', Icons.description),
        const SizedBox(height: 12),
        _field(_storePhoneCtrl, 'Nomor HP Toko', Icons.phone, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        _field(_addressCtrl, 'Alamat Lengkap', Icons.location_on,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 12),
        // Map location picker
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
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
                  const Icon(Icons.map, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lokasi Toko di Peta',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          '${_storeLat.toStringAsFixed(5)}, ${_storeLng.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text('Ketuk untuk memilih lokasi toko di peta', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 24),
        SizedBox(height: 50, child: FilledButton(
          onPressed: () {
            if (_storeNameCtrl.text.trim().isEmpty || _addressCtrl.text.trim().isEmpty) {
              _showError('Nama toko dan alamat wajib diisi');
              return;
            }
            setState(() => _step = 2);
          },
          child: const Text('Lanjut →'),
        )),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => setState(() => _step = 0), child: const Text('← Kembali')),
      ],
    );
  }

  Widget _buildDocsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Dokumen Verifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Dokumen diperlukan untuk verifikasi toko oleh admin.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        _docTile('KTP Pemilik *', 'Foto KTP pemilik toko yang jelas', Icons.badge, _ktpFile, () => _pick('ktp')),
        _docTile('Izin Usaha (opsional)', 'SIUP / IUMK / NIB jika ada', Icons.business_center, _bizLicenseFile, () => _pick('biz')),
        _docTile('Foto Toko *', 'Foto tampak depan toko / tempat jualan', Icons.store, _storePhotoFile, () => _pick('store')),
        const SizedBox(height: 24),
        SizedBox(height: 50, child: FilledButton(
          onPressed: _loading ? null : _submitStore,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Kirim Pendaftaran'),
        )),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('← Kembali')),
      ],
    );
  }

  Widget _docTile(String title, String subtitle, IconData icon, File? file, VoidCallback onTap) {
    final uploaded = file != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: uploaded ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
          backgroundImage: uploaded ? FileImage(file) : null,
          child: uploaded ? null : Icon(icon, color: Colors.grey),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(uploaded ? '✓ Siap' : subtitle, style: TextStyle(fontSize: 12, color: uploaded ? Colors.green : Colors.grey)),
        trailing: TextButton(onPressed: onTap, child: Text(uploaded ? 'Ganti' : 'Upload', style: TextStyle(color: uploaded ? Colors.green : KuwrirColors.primary))),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
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
            backgroundColor: done || active ? KuwrirColors.primary : Colors.grey.shade300,
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('${i + 1}', style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 12)),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(steps[i], style: TextStyle(fontSize: 12, color: active ? KuwrirColors.primary : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal))),
          if (i < steps.length - 1) Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
        ]));
      }),
    );
  }
}
