import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/address_cubit.dart';
import 'location_picker_screen.dart';

const _kQuickLabels = ['Rumah', 'Kantor', 'Lainnya'];

/// Add (existing == null) or edit an existing saved address.
class EditAddressScreen extends StatefulWidget {
  final SavedAddress? existing;
  const EditAddressScreen({super.key, this.existing});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  late final TextEditingController _customLabelCtrl;
  String _quickLabel = 'Rumah';
  bool _customLabelSelected = false;
  LatLng? _picked;
  String _address = '';
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _customLabelCtrl = TextEditingController();
    if (e != null) {
      _picked = LatLng(e.latitude, e.longitude);
      _address = e.address;
      _isDefault = e.isDefault;
      if (_kQuickLabels.contains(e.label)) {
        _quickLabel = e.label;
      } else {
        _customLabelSelected = true;
        _customLabelCtrl.text = e.label;
      }
    }
  }

  @override
  void dispose() {
    _customLabelCtrl.dispose();
    super.dispose();
  }

  String get _resolvedLabel => (_customLabelSelected || _quickLabel == 'Lainnya')
      ? _customLabelCtrl.text.trim()
      : _quickLabel;

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: _picked)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _picked = result['latlng'] as LatLng;
      _address = result['address'] as String;
    });
  }

  Future<void> _save() async {
    final label = _resolvedLabel;
    if (label.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pilih atau isi nama alamat')));
      return;
    }
    if (_picked == null || _address.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pilih lokasi di peta')));
      return;
    }

    setState(() => _saving = true);
    try {
      final cubit = context.read<AddressCubit>();
      if (widget.existing != null) {
        await cubit.edit(
          widget.existing!.id,
          label: label,
          address: _address,
          lat: _picked!.latitude,
          lng: _picked!.longitude,
          isDefault: _isDefault,
        );
      } else {
        await cubit.add(
          label: label,
          address: _address,
          lat: _picked!.latitude,
          lng: _picked!.longitude,
          isDefault: _isDefault,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e is ApiException ? e.message : 'Gagal menyimpan alamat')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Ubah Alamat' : 'Tambah Alamat'),
        backgroundColor: KuwrirColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('NAMA ALAMAT',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: KuwrirColors.textHint)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              for (final label in _kQuickLabels)
                ChoiceChip(
                  label: Text(label),
                  selected: !_customLabelSelected && _quickLabel == label,
                  onSelected: (_) => setState(() {
                    _customLabelSelected = false;
                    _quickLabel = label;
                  }),
                ),
            ],
          ),
          if (_customLabelSelected || _quickLabel == 'Lainnya') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customLabelCtrl,
              onChanged: (_) => setState(() => _customLabelSelected = true),
              onTap: () => setState(() => _customLabelSelected = true),
              decoration: InputDecoration(
                labelText: 'Nama alamat',
                hintText: 'cth. Rumah Mertua, Kos',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('LOKASI',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: KuwrirColors.textHint)),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickLocation,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: KuwrirColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KuwrirColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: KuwrirColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.map_outlined, color: KuwrirColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _address.isEmpty ? 'Pilih lokasi di peta' : _address,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: _address.isEmpty ? FontWeight.w500 : FontWeight.w600,
                        color: _address.isEmpty ? KuwrirColors.textHint : KuwrirColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: KuwrirColors.textHint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: KuwrirColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KuwrirColors.border),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              title: const Text('Jadikan alamat utama', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              activeThumbColor: KuwrirColors.primary,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan Alamat'),
            ),
          ),
        ],
      ),
    );
  }
}
