import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'package:hugeicons/hugeicons.dart';

/// Buy/track paid homepage carousel slots. A slot goes live only after
/// admin approval (Banner.Status) — see backend admin/handler.go
/// ApproveBanner/RejectBanner.
class BannerAdsScreen extends StatefulWidget {
  const BannerAdsScreen({super.key});

  @override
  State<BannerAdsScreen> createState() => _BannerAdsScreenState();
}

class _BannerAdsScreenState extends State<BannerAdsScreen> {
  List<Map<String, dynamic>> _banners = [];
  double _walletBalance = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final banners = await api.getMyBanners();
      final wallet = await api.getMerchantWallet();
      if (!mounted) return;
      setState(() {
        _banners = banners;
        _walletBalance = wallet.balance;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal memuat data';
        _loading = false;
      });
    }
  }

  Future<void> _buySlot() async {
    final purchased = await showDialog<bool>(
      context: context,
      builder: (_) => _BuyBannerDialog(walletBalance: _walletBalance),
    );
    if (purchased == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Iklan Banner Homepage'),
        backgroundColor: KuwrirColors.background,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _buySlot,
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedMegaphone01),
        label: const Text('Beli Slot Banner'),
        backgroundColor: KuwrirColors.primary,
      ),
      body: _buildBody(),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: KuwrirColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KuwrirColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedWallet01, color: KuwrirColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo Wallet', style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
                      Text('Rp ${_fmt(_walletBalance)}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_banners.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedMegaphone01, size: 48, color: KuwrirColors.textHint),
                    const SizedBox(height: 12),
                    Text('Belum pernah beli slot banner',
                        style: TextStyle(fontWeight: FontWeight.w700, color: KuwrirColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Tampil di carousel utama halaman depan customer',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: KuwrirColors.textHint)),
                  ],
                ),
              ),
            )
          else
            ..._banners.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BannerCard(
                    banner: b,
                    onUploadImage: b['image_url'] == null
                        ? () => _uploadImage(b['id'] as String)
                        : null,
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _uploadImage(String bannerId) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (xfile == null) return;
    try {
      await context.read<ApiClient>().uploadMyBannerImage(bannerId, File(xfile.path));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload gambar: $e')),
        );
      }
    }
  }
}

class _BannerCard extends StatelessWidget {
  final Map<String, dynamic> banner;
  final VoidCallback? onUploadImage;
  const _BannerCard({required this.banner, this.onUploadImage});

  ({String label, Color color}) _statusStyle(String status) {
    switch (status) {
      case 'approved':
        return (label: 'Tayang', color: KuwrirColors.success);
      case 'rejected':
        return (label: 'Ditolak (di-refund)', color: KuwrirColors.error);
      default:
        return (label: 'Menunggu Review', color: KuwrirColors.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = banner['status'] as String? ?? 'pending_review';
    final style = _statusStyle(status);
    final pricePaid = (banner['price_paid'] as num?)?.toDouble() ?? 0;
    final expiresAt = DateTime.tryParse(banner['expires_at'] as String? ?? '');

    return Container(
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(banner['title'] as String? ?? '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(style.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: style.color)),
                ),
              ],
            ),
            if ((banner['subtitle'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(banner['subtitle'] as String, style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
            ],
            const SizedBox(height: 8),
            Text(
              'Dibayar Rp${pricePaid.toStringAsFixed(0)}'
              '${expiresAt != null ? ' • berlaku sampai ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}' : ''}',
              style: TextStyle(fontSize: 12, color: KuwrirColors.textHint),
            ),
            if (onUploadImage != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onUploadImage,
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedImage02, size: 16),
                label: const Text('Upload Gambar Banner'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BuyBannerDialog extends StatefulWidget {
  final double walletBalance;
  const _BuyBannerDialog({required this.walletBalance});

  @override
  State<_BuyBannerDialog> createState() => _BuyBannerDialogState();
}

class _BuyBannerDialogState extends State<_BuyBannerDialog> {
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  int _days = 7;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _buy() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Judul banner wajib diisi');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().createMyBanner({
        'title': title,
        'subtitle': _subtitleCtrl.text.trim(),
        'days': _days,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal membeli slot banner';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Beli Slot Banner'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Judul Banner'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _subtitleCtrl,
                decoration: const InputDecoration(labelText: 'Subjudul (opsional)'),
              ),
              const SizedBox(height: 14),
              Text('Durasi Tayang', style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [3, 7, 14, 30].map((d) {
                  final selected = d == _days;
                  return ChoiceChip(
                    label: Text('$d hari'),
                    selected: selected,
                    onSelected: (_) => setState(() => _days = d),
                    selectedColor: KuwrirColors.primary.withValues(alpha: 0.15),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Gambar bisa diupload setelah dibuat. Biaya dipotong dari saldo wallet-mu.',
                style: TextStyle(fontSize: 12, color: KuwrirColors.textHint),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: KuwrirColors.error, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          onPressed: _saving ? null : _buy,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Beli'),
        ),
      ],
    );
  }
}
