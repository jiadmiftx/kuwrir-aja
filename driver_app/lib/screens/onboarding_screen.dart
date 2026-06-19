import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'pending_screen.dart';

/// Step 2 of driver registration: vehicle info + document upload
class DriverOnboardingScreen extends StatefulWidget {
  final String userID;
  final String userName;

  const DriverOnboardingScreen({
    super.key,
    required this.userID,
    required this.userName,
  });

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();

  String _vehicleType = 'motorcycle';
  bool _loading = false;

  // Document files — picked by user
  File? _ktpFile;
  File? _simFile;
  File? _stnkFile;
  File? _selfieFile;
  File? _vehiclePhotoFile;

  final _picker = ImagePicker();

  Future<void> _pick(String docType) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;

    final xfile = await _picker.pickImage(source: src, imageQuality: 80, maxWidth: 1200);
    if (xfile == null) return;

    final file = File(xfile.path);
    setState(() {
      switch (docType) {
        case 'ktp':           _ktpFile = file; break;
        case 'sim':           _simFile = file; break;
        case 'stnk':          _stnkFile = file; break;
        case 'selfie':        _selfieFile = file; break;
        case 'vehicle_photo': _vehiclePhotoFile = file; break;
      }
    });
  }

  bool get _allDocsPicked =>
      _ktpFile != null &&
      _simFile != null &&
      _stnkFile != null &&
      _selfieFile != null &&
      _vehiclePhotoFile != null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allDocsPicked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua dokumen wajib diupload'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final token = await ApiClient().getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/driver/apply');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['vehicle_type'] = _vehicleType
        ..fields['vehicle_plate'] = _plateCtrl.text.trim().toUpperCase()
        ..fields['vehicle_year'] = _yearCtrl.text.trim()
        ..fields['vehicle_color'] = _colorCtrl.text.trim()
        ..fields['vehicle_brand'] = _brandCtrl.text.trim();

      final docs = {
        'ktp': _ktpFile!,
        'sim': _simFile!,
        'stnk': _stnkFile!,
        'selfie': _selfieFile!,
        'vehicle_photo': _vehiclePhotoFile!,
      };
      for (final entry in docs.entries) {
        req.files.add(await http.MultipartFile.fromPath(entry.key, entry.value.path));
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverPendingScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload gagal: ${res.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _plateCtrl.dispose(); _yearCtrl.dispose();
    _colorCtrl.dispose(); _brandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dokumen & Kendaraan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepIndicator(2),
              const SizedBox(height: 24),

              // Vehicle info
              const Text('Informasi Kendaraan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              const Text('Jenis Kendaraan', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _vehicleChip('motorcycle', Icons.two_wheeler, 'Motor'),
                  const SizedBox(width: 8),
                  _vehicleChip('bicycle', Icons.pedal_bike, 'Sepeda'),
                  const SizedBox(width: 8),
                  _vehicleChip('car', Icons.directions_car, 'Mobil'),
                ],
              ),
              const SizedBox(height: 12),

              _field(_plateCtrl, 'Nomor Plat (e.g. DR 1234 AB)', Icons.confirmation_number,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Wajib diisi' : null),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(_brandCtrl, 'Merek (e.g. Honda)', Icons.info_outline)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_colorCtrl, 'Warna', Icons.palette)),
                ],
              ),
              const SizedBox(height: 12),
              _field(_yearCtrl, 'Tahun Kendaraan', Icons.calendar_today,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 24),

              // Documents
              const Text('Upload Dokumen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Semua dokumen wajib. Foto harus jelas dan terbaca.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),

              _docUploadTile(
                'KTP',
                'Foto KTP asli — wajah dan data jelas',
                Icons.badge,
                _ktpFile,
                () => _pick('ktp'),
              ),
              _docUploadTile(
                'SIM C / SIM A',
                'Foto SIM aktif (depan)',
                Icons.card_membership,
                _simFile,
                () => _pick('sim'),
              ),
              _docUploadTile(
                'STNK',
                'Foto STNK kendaraan yang dipakai',
                Icons.article,
                _stnkFile,
                () => _pick('stnk'),
              ),
              _docUploadTile(
                'Selfie dengan KTP',
                'Foto wajah sambil memegang KTP',
                Icons.face,
                _selfieFile,
                () => _pick('selfie'),
              ),
              _docUploadTile(
                'Foto Kendaraan',
                'Foto kendaraan tampak depan (plat terlihat)',
                Icons.two_wheeler,
                _vehiclePhotoFile,
                () => _pick('vehicle_photo'),
              ),
              const SizedBox(height: 24),

              // Progress summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _allDocsPicked ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _allDocsPicked ? Colors.green : Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(_allDocsPicked ? Icons.check_circle : Icons.info_outline,
                        color: _allDocsPicked ? Colors.green : Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _allDocsPicked
                            ? 'Semua dokumen siap diupload!'
                            : '${[_ktpFile, _simFile, _stnkFile, _selfieFile, _vehiclePhotoFile].where((f) => f == null).length} dokumen belum diupload',
                        style: TextStyle(color: _allDocsPicked ? Colors.green.shade700 : Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Kirim Pendaftaran', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleChip(String value, IconData icon, String label) {
    final selected = _vehicleType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? KuwrirColors.primary.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? KuwrirColors.primary : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? KuwrirColors.primary : Colors.grey),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: selected ? KuwrirColors.primary : Colors.grey, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docUploadTile(String title, String subtitle, IconData icon, File? file, VoidCallback onTap) {
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
        subtitle: Text(uploaded ? '✓ Sudah diupload' : subtitle,
            style: TextStyle(fontSize: 12, color: uploaded ? Colors.green : Colors.grey)),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(uploaded ? 'Ganti' : 'Upload', style: TextStyle(color: uploaded ? Colors.green : KuwrirColors.primary)),
        ),
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
                backgroundColor: done || active ? KuwrirColors.primary : Colors.grey.shade300,
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text('$step', style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 12)),
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(steps[i], style: TextStyle(fontSize: 12, color: active ? KuwrirColors.primary : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal))),
              if (i < steps.length - 1) Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
            ],
          ),
        );
      }),
    );
  }
}
