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
      backgroundColor: KuwrirColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: KuwrirColors.primary),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: KuwrirColors.primary),
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
        SnackBar(content: const Text('Semua dokumen wajib diupload'), backgroundColor: KuwrirColors.warning),
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
          SnackBar(content: Text('Upload gagal: ${res.body}'), backgroundColor: KuwrirColors.error),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: KuwrirColors.error),
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
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(title: const Text('Dokumen & Kendaraan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepIndicator(2),
              const SizedBox(height: 24),

              // Vehicle info
              Text(
                'INFORMASI KENDARAAN',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: KuwrirColors.textHint,
                ),
              ),
              const SizedBox(height: 12),

              Text('Jenis Kendaraan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: KuwrirColors.textPrimary)),
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
              const SizedBox(height: 14),

              _field(_plateCtrl, 'Nomor Plat (e.g. DR 1234 AB)', Icons.confirmation_number_outlined,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Wajib diisi' : null),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(_brandCtrl, 'Merek (e.g. Honda)', Icons.info_outline)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_colorCtrl, 'Warna', Icons.palette_outlined)),
                ],
              ),
              const SizedBox(height: 12),
              _field(_yearCtrl, 'Tahun Kendaraan', Icons.calendar_today_outlined,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 24),

              // Documents
              Text(
                'UPLOAD DOKUMEN',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: KuwrirColors.textHint,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Semua dokumen wajib. Foto harus jelas dan terbaca.',
                style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 14),

              _docUploadTile(
                'KTP',
                'Foto KTP asli — wajah dan data jelas',
                Icons.badge_outlined,
                _ktpFile,
                () => _pick('ktp'),
              ),
              _docUploadTile(
                'SIM C / SIM A',
                'Foto SIM aktif (depan)',
                Icons.card_membership_outlined,
                _simFile,
                () => _pick('sim'),
              ),
              _docUploadTile(
                'STNK',
                'Foto STNK kendaraan yang dipakai',
                Icons.article_outlined,
                _stnkFile,
                () => _pick('stnk'),
              ),
              _docUploadTile(
                'Selfie dengan KTP',
                'Foto wajah sambil memegang KTP',
                Icons.face_outlined,
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
              const SizedBox(height: 20),

              // Progress summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_allDocsPicked ? KuwrirColors.success : KuwrirColors.warning).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: (_allDocsPicked ? KuwrirColors.success : KuwrirColors.warning).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_allDocsPicked ? Icons.check_circle : Icons.info_outline,
                        color: _allDocsPicked ? KuwrirColors.success : KuwrirColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _allDocsPicked
                            ? 'Semua dokumen siap diupload!'
                            : '${[_ktpFile, _simFile, _stnkFile, _selfieFile, _vehiclePhotoFile].where((f) => f == null).length} dokumen belum diupload',
                        style: TextStyle(
                          color: _allDocsPicked ? KuwrirColors.success : KuwrirColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
                      : const Text('Kirim Pendaftaran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? KuwrirColors.primary.withValues(alpha: 0.08) : KuwrirColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? KuwrirColors.primary : KuwrirColors.border, width: selected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? KuwrirColors.primary : KuwrirColors.textHint),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: selected ? KuwrirColors.primary : KuwrirColors.textSecondary, fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docUploadTile(String title, String subtitle, IconData icon, File? file, VoidCallback onTap) {
    final uploaded = file != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
        boxShadow: [
          BoxShadow(
            color: KuwrirColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            color: uploaded ? KuwrirColors.success.withValues(alpha: 0.1) : KuwrirColors.primary.withValues(alpha: 0.08),
            child: uploaded
                ? Image.file(file, fit: BoxFit.cover)
                : Icon(icon, color: KuwrirColors.primary, size: 20),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(uploaded ? 'Sudah diupload' : subtitle,
            style: TextStyle(fontSize: 12, color: uploaded ? KuwrirColors.success : KuwrirColors.textHint)),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(uploaded ? 'Ganti' : 'Upload', style: TextStyle(color: uploaded ? KuwrirColors.success : KuwrirColors.primary, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
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
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: KuwrirColors.textHint),
          prefixIcon: Icon(icon, color: KuwrirColors.primary),
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
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text('$step', style: TextStyle(color: active ? Colors.white : KuwrirColors.textHint, fontSize: 12)),
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(steps[i], style: TextStyle(fontSize: 12, color: active ? KuwrirColors.primary : KuwrirColors.textHint, fontWeight: active ? FontWeight.w700 : FontWeight.normal))),
              if (i < steps.length - 1) Expanded(child: Container(height: 1, color: KuwrirColors.border)),
            ],
          ),
        );
      }),
    );
  }
}
