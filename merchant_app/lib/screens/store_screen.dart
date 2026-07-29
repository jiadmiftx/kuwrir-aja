import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/store_cubit.dart';
import 'promo_codes_screen.dart';
import 'banner_ads_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

// Delete-account is implemented (see _deleteAccount below) but hidden from
// the account menu for now, pending review — flip this back on when ready
// instead of re-implementing.
const _kShowDeleteAccount = false;

class _StoreScreenState extends State<StoreScreen> {
  final _selfDeliveryFeeCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _uploadingLogo = false;
  bool _uploadingBanner = false;

  @override
  void initState() {
    super.initState();
    context.read<StoreCubit>().load();
  }

  @override
  void dispose() {
    _selfDeliveryFeeCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload({required bool isBanner}) async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: isBanner ? 1600 : 800,
    );
    if (xfile == null) return;

    setState(() {
      if (isBanner) {
        _uploadingBanner = true;
      } else {
        _uploadingLogo = true;
      }
    });
    try {
      final api = context.read<ApiClient>();
      if (isBanner) {
        await api.uploadStoreBanner(File(xfile.path));
      } else {
        await api.uploadStoreLogo(File(xfile.path));
      }
      if (context.mounted) context.read<StoreCubit>().load();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal upload: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingBanner = false;
          _uploadingLogo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: KuwrirColors.background,
          body: _buildBody(context, state),
        );
      },
    );
  }

  Future<void> _editDetail({
    required String label,
    required String currentValue,
    required TextInputType keyboardType,
    required Future<void> Function(String value) onSave,
  }) async {
    final ctrl = TextEditingController(text: currentValue);
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Ubah $label'),
          content: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLines: keyboardType == TextInputType.multiline ? 3 : 1,
            autofocus: true,
            decoration: InputDecoration(labelText: label, errorText: error),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final value = ctrl.text.trim();
                if (value.isEmpty) {
                  setDialogState(() => error = '$label wajib diisi');
                  return;
                }
                try {
                  await onSave(value);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  setDialogState(() => error = e is ApiException ? e.message : '$e');
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) context.read<StoreCubit>().load();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Anda akan keluar dari akun merchant ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KuwrirColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final nav = Navigator.of(context);
    await ApiClient().clearTokens();
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDeleteAccountDialog(context);
    if (confirmed != true || !context.mounted) return;

    try {
      await ApiClient().deleteAccount();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Gagal menghapus akun')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    await ApiClient().clearTokens();
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Widget _buildBody(BuildContext context, StoreState state) {
    if (state is StoreLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is StoreError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, style: TextStyle(color: KuwrirColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<StoreCubit>().load(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (state is StoreLoaded) {
      final merchant = state.merchant;
      if (_selfDeliveryFeeCtrl.text.isEmpty) {
        _selfDeliveryFeeCtrl.text = merchant.selfDeliveryFee.toStringAsFixed(0);
      }

      return RefreshIndicator(
        onRefresh: () => context.read<StoreCubit>().load(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _StoreHero(
                merchant: merchant,
                uploadingLogo: _uploadingLogo,
                uploadingBanner: _uploadingBanner,
                onPickBanner: () => _pickAndUpload(isBanner: true),
                onPickLogo: () => _pickAndUpload(isBanner: false),
                onLogout: () => _confirmLogout(context),
                onDeleteAccount: () => _deleteAccount(context),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionLabel('Hari Ini'),
                  Row(
                    children: [
                      _StatBox(
                        label: 'Pesanan',
                        value: state.todayOrders.toString(),
                        color: KuwrirColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatBox(
                        label: 'Pendapatan',
                        value: 'Rp ${_fmt(state.todayRevenue)}',
                        color: KuwrirColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('Info Toko'),
                  _SoftPanel(
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.storefront_outlined,
                          label: 'Nama Toko',
                          value: merchant.name,
                          onTap: () => _editDetail(
                            label: 'Nama Toko',
                            currentValue: merchant.name,
                            keyboardType: TextInputType.text,
                            onSave: (v) => context.read<ApiClient>().updateMerchantDetails(name: v),
                          ),
                        ),
                        const _Hairline(),
                        _InfoRow(
                          icon: Icons.call_outlined,
                          label: 'Telepon',
                          value: merchant.phone ?? 'Belum diisi',
                          onTap: () => _editDetail(
                            label: 'Telepon',
                            currentValue: merchant.phone ?? '',
                            keyboardType: TextInputType.phone,
                            onSave: (v) => context.read<ApiClient>().updateMerchantDetails(phone: v),
                          ),
                        ),
                        const _Hairline(),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Alamat',
                          value: merchant.address,
                          onTap: () => _editDetail(
                            label: 'Alamat',
                            currentValue: merchant.address,
                            keyboardType: TextInputType.multiline,
                            onSave: (v) => context.read<ApiClient>().updateMerchantDetails(address: v),
                          ),
                        ),
                        const _Hairline(),
                        _InfoRow(
                          icon: Icons.star_rounded,
                          label: 'Rating',
                          value: '${merchant.rating.toStringAsFixed(1)} · ${merchant.totalReviews} ulasan',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('Operasional'),
                  _SoftPanel(
                    child: Column(
                      children: [
                        _ToggleRow(
                          title: 'Status Toko',
                          subtitle: merchant.isOpen ? 'Buka — menerima pesanan' : 'Tutup sementara',
                          subtitleColor: merchant.isOpen ? KuwrirColors.success : KuwrirColors.textHint,
                          value: merchant.isOpen,
                          onChanged: (v) => context.read<StoreCubit>().toggleOpen(v),
                        ),
                        const _Hairline(),
                        _ToggleRow(
                          title: 'Antar Sendiri',
                          subtitle: 'Antar pesanan tanpa driver Cocourir',
                          value: merchant.canSelfDeliver,
                          onChanged: (v) => _toggleSelfDeliver(context, v),
                        ),
                        if (merchant.canSelfDeliver) ...[
                          const _Hairline(),
                          _InlineFeeEditor(
                            label: 'Ongkir Antar Sendiri (0 = gratis)',
                            controller: _selfDeliveryFeeCtrl,
                            prefixText: 'Rp ',
                            onSave: () => _saveSelfDeliveryFee(context),
                          ),
                        ],
                        const _Hairline(),
                        _ToggleRow(
                          title: 'Gratis Ongkir',
                          subtitle: 'Semua produk tokomu tampil di filter Gratis Ongkir',
                          value: merchant.isFreeDelivery,
                          onChanged: (v) => _toggleFreeDelivery(context, v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('Promosi'),
                  _SoftPanel(
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.sell_outlined,
                          label: 'Kode diskon buat pelangganmu sendiri',
                          value: 'Kode Promo',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PromoCodesScreen()),
                          ),
                        ),
                        const _Hairline(),
                        _InfoRow(
                          icon: Icons.campaign_outlined,
                          label: 'Tampil di carousel utama halaman depan',
                          value: 'Iklan Banner Homepage',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BannerAdsScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('Pajak'),
                  _SoftPanel(
                    child: Column(
                      children: [
                        _ToggleRow(
                          title: 'Pemungut Pajak (PKP)',
                          subtitle: merchant.taxEnabled
                              ? 'Aktif — PPN dikenakan ke pelanggan'
                              : 'Nonaktif — toko UMKM, tanpa PPN',
                          subtitleColor: merchant.taxEnabled ? KuwrirColors.primary : KuwrirColors.textSecondary,
                          value: merchant.taxEnabled,
                          onChanged: (v) => _toggleTax(context, v, merchant.taxRate),
                        ),
                        if (merchant.taxEnabled) ...[
                          const _Hairline(),
                          _InlineFeeEditor(
                            label: 'Rate Pajak — kosong = default platform (11%)',
                            controller: _taxRateCtrl..text = merchant.taxRate?.toStringAsFixed(0) ?? '',
                            suffixText: '%',
                            onSave: () => _saveTaxRate(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _toggleTax(BuildContext context, bool v, double? currentRate) async {
    try {
      final api = context.read<ApiClient>();
      await api.updateTaxSettings(taxEnabled: v, taxRate: currentRate);
      if (context.mounted) context.read<StoreCubit>().load();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _saveTaxRate(BuildContext context) async {
    final rateText = _taxRateCtrl.text.trim();
    final rate = rateText.isEmpty ? null : double.tryParse(rateText);
    try {
      final api = context.read<ApiClient>();
      await api.updateTaxSettings(taxEnabled: true, taxRate: rate);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rate pajak tersimpan')));
        context.read<StoreCubit>().load();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _toggleFreeDelivery(BuildContext context, bool v) async {
    try {
      final api = context.read<ApiClient>();
      await api.toggleFreeDelivery(v);
      if (context.mounted) context.read<StoreCubit>().load();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _toggleSelfDeliver(BuildContext context, bool v) async {
    try {
      final api = context.read<ApiClient>();
      await api.toggleSelfDeliver(v);
      if (context.mounted) context.read<StoreCubit>().load();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _saveSelfDeliveryFee(BuildContext context) async {
    final fee = double.tryParse(_selfDeliveryFeeCtrl.text) ?? 0;
    try {
      final api = context.read<ApiClient>();
      await api.setSelfDeliveryFee(fee);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ongkir tersimpan')));
        context.read<StoreCubit>().load();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

/// Banner + overlapping circular logo, both tap-to-upload — the store's
/// storefront exactly as customers see it at the top of the merchant
/// detail page, with an edit affordance layered directly on top instead
/// of a separate settings form buried below.
class _StoreHero extends StatelessWidget {
  final Merchant merchant;
  final bool uploadingLogo;
  final bool uploadingBanner;
  final VoidCallback onPickBanner;
  final VoidCallback onPickLogo;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  const _StoreHero({
    required this.merchant,
    required this.uploadingLogo,
    required this.uploadingBanner,
    required this.onPickBanner,
    required this.onPickLogo,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  // Banner height + how far the logo protrudes below it are fixed layout
  // constants — the hero's overall SizedBox height below is derived from
  // them so the logo's overflow is actually reserved space, not just
  // painted on top of whatever sliver comes next (that mismatch is what
  // used to let the logo visually cover the "Hari Ini" label below it).
  static const _bannerHeight = 168.0;
  static const _logoSize = 76.0;
  static const _logoOverlap = 38.0;
  static const _heroHeight = _bannerHeight + (_logoSize - _logoOverlap) + 4;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _heroHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: onPickBanner,
              child: Container(
                height: _bannerHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: KuwrirColors.primary.withValues(alpha: 0.08),
                  image: merchant.bannerUrl != null
                      ? DecorationImage(image: NetworkImage(merchant.bannerUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (merchant.bannerUrl == null)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: KuwrirColors.primary, size: 28),
                            const SizedBox(height: 6),
                            Text('Tambah banner toko',
                                style: TextStyle(color: KuwrirColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    if (uploadingBanner)
                      Container(
                        color: Colors.black38,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        ),
                      ),
                    if (merchant.bannerUrl != null && !uploadingBanner)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _EditChip(),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: SafeArea(
                        bottom: false,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          style: IconButton.styleFrom(backgroundColor: Colors.black26),
                          onSelected: (value) {
                            if (value == 'logout') onLogout();
                            if (value == 'delete') onDeleteAccount();
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'logout', child: Text('Keluar')),
                            if (_kShowDeleteAccount)
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Hapus Akun', style: TextStyle(color: KuwrirColors.error)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: _bannerHeight - _logoOverlap,
            child: GestureDetector(
              onTap: onPickLogo,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: _logoSize,
                    height: _logoSize,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: KuwrirColors.surface,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        color: KuwrirColors.primary.withValues(alpha: 0.08),
                        child: uploadingLogo
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                            : merchant.logoUrl != null
                                ? Image.network(merchant.logoUrl!, fit: BoxFit.cover)
                                : Icon(Icons.storefront, color: KuwrirColors.primary, size: 30),
                      ),
                    ),
                  ),
                  if (!uploadingLogo)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: KuwrirColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: KuwrirColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 108,
            right: 20,
            // Vertically centered in the band where the logo protrudes below
            // the banner (from _bannerHeight to _bannerHeight + _logoOverlap),
            // so the name reads as part of the same "profile row" as the
            // logo instead of floating separately over the banner image.
            top: _bannerHeight + (_logoOverlap - 22) / 2,
            child: Text(
              merchant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: KuwrirColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(100)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text('Ganti', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: KuwrirColors.textHint,
        ),
      ),
    );
  }
}

/// Flat tinted surface, replacing default boxy Material Cards — one
/// consistent container language across the screen instead of stacked
/// elevated cards.
class _SoftPanel extends StatelessWidget {
  final Widget child;
  const _SoftPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: child,
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) => Divider(height: 1, color: KuwrirColors.border);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: KuwrirColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11.5, color: KuwrirColors.textHint)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.edit_outlined, size: 16, color: KuwrirColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor ?? KuwrirColors.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: KuwrirColors.primary,
          ),
        ],
      ),
    );
  }
}

class _InlineFeeEditor extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefixText;
  final String? suffixText;
  final VoidCallback onSave;

  const _InlineFeeEditor({
    required this.label,
    required this.controller,
    this.prefixText,
    this.suffixText,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: prefixText,
                    suffixText: suffixText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: KuwrirColors.primary),
                onPressed: onSave,
                child: const Text('Simpan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
