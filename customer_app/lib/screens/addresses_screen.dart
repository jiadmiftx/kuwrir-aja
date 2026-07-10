import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/address_cubit.dart';
import 'edit_address_screen.dart';
import 'location_picker_screen.dart';

/// Optionally used in "pick mode" by Cart's checkout selector and Home's
/// app-bar location tap: passing [onPick] turns tapping a row into a
/// selection instead of navigating to the edit screen. Passing
/// [onPickAdHoc] additionally surfaces a "pick on map, don't save" row —
/// the Gojek "Pilih alamat" flow always keeps that escape hatch alongside
/// the saved list (see mockup_app/customer_app/address_2.jpeg).
class AddressesScreen extends StatefulWidget {
  final ValueChanged<SavedAddress>? onPick;
  final void Function(String address, double lat, double lng)? onPickAdHoc;
  const AddressesScreen({super.key, this.onPick, this.onPickAdHoc});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AddressCubit>().load();
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result == null || !mounted) return;
    final latlng = result['latlng'] as LatLng;
    final address = result['address'] as String;
    widget.onPickAdHoc!(address, latlng.latitude, latlng.longitude);
  }

  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('rumah')) return Icons.home_outlined;
    if (l.contains('kantor')) return Icons.work_outline;
    return Icons.location_on_outlined;
  }

  Future<void> _confirmDelete(SavedAddress a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Alamat?'),
        content: Text('${a.label} akan dihapus dari daftar alamat tersimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: TextStyle(color: KuwrirColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AddressCubit>().remove(a.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: Text(
          widget.onPick != null ? 'Pilih Alamat' : 'Alamat Tersimpan',
        ),
        backgroundColor: KuwrirColors.background,
      ),
      body: Column(
        children: [
          if (widget.onPickAdHoc != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: InkWell(
                onTap: _pickOnMap,
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
                        child: Icon(
                          Icons.map_outlined,
                          color: KuwrirColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pilih Lokasi di Peta',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: KuwrirColors.textHint),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: BlocBuilder<AddressCubit, AddressState>(
              builder: (context, state) {
                if (state is AddressLoading || state is AddressInitial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is AddressError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          state.message,
                          style: TextStyle(color: KuwrirColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.read<AddressCubit>().load(),
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  );
                }
                final addresses = (state as AddressLoaded).addresses;
                if (addresses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: KuwrirColors.primary.withValues(
                                alpha: 0.08,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 36,
                              color: KuwrirColors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Belum ada alamat tersimpan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: KuwrirColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Simpan alamat rumah atau kantor untuk checkout lebih cepat',
                            style: TextStyle(
                              color: KuwrirColors.textSecondary,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final a = addresses[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: KuwrirColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: KuwrirColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: widget.onPick != null
                            ? () => widget.onPick!(a)
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditAddressScreen(existing: a),
                                ),
                              ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: KuwrirColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _iconFor(a.label),
                            color: KuwrirColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              a.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                            if (a.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: KuwrirColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'UTAMA',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: KuwrirColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: KuwrirColors.textSecondary,
                              ),
                            ),
                            if (a.detail.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  a.detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: KuwrirColors.textHint,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: widget.onPick != null
                            ? Icon(
                                Icons.chevron_right,
                                color: KuwrirColors.textHint,
                              )
                            : PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  size: 18,
                                  color: KuwrirColors.textHint,
                                ),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditAddressScreen(existing: a),
                                      ),
                                    );
                                  } else if (action == 'default') {
                                    context.read<AddressCubit>().setDefault(
                                      a.id,
                                    );
                                  } else if (action == 'delete') {
                                    _confirmDelete(a);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Ubah'),
                                  ),
                                  if (!a.isDefault)
                                    const PopupMenuItem(
                                      value: 'default',
                                      child: Text('Jadikan Utama'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Hapus'),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditAddressScreen()),
        ),
        backgroundColor: KuwrirColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Alamat'),
      ),
    );
  }
}
