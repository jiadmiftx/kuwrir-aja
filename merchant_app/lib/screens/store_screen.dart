import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/store_cubit.dart';
import 'kasir_hub_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final _selfDeliveryFeeCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Toko Saya'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<StoreCubit>().load(),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Keluar',
                onPressed: () => _confirmLogout(context),
              ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

  Widget _buildBody(BuildContext context, StoreState state) {
    if (state is StoreLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is StoreError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, style: const TextStyle(color: Colors.grey)),
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Today summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ringkasan Hari Ini',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              )),
                      const SizedBox(height: 12),
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
                            value: 'IDR ${_fmt(state.todayRevenue)}',
                            color: KuwrirColors.success,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Kasir / POS entry point
              Card(
                child: ListTile(
                  leading: const Icon(Icons.point_of_sale_outlined, color: KuwrirColors.primary),
                  title: const Text('Kasir / POS'),
                  subtitle: const Text('Transaksi walk-in, laporan, piutang & hutang'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KasirHub())),
                ),
              ),
              const SizedBox(height: 16),

              // Store info
              _InfoTile(icon: Icons.store, label: 'Nama Toko', value: merchant.name),
              if (merchant.phone != null)
                _InfoTile(icon: Icons.phone, label: 'Telepon', value: merchant.phone!),
              _InfoTile(icon: Icons.location_on_outlined, label: 'Alamat', value: merchant.address),
              _InfoTile(
                icon: Icons.star,
                label: 'Rating',
                value: '${merchant.rating.toStringAsFixed(1)} (${merchant.totalReviews} ulasan)',
              ),

              const SizedBox(height: 16),

              // Open/closed toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Status Toko',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            merchant.isOpen ? 'Buka — menerima pesanan' : 'Tutup',
                            style: TextStyle(
                              fontSize: 12,
                              color: merchant.isOpen ? KuwrirColors.success : KuwrirColors.error,
                            ),
                          ),
                        ],
                      ),
                      Switch.adaptive(
                        value: merchant.isOpen,
                        onChanged: (v) => context.read<StoreCubit>().toggleOpen(v),
                        activeColor: KuwrirColors.success,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Self-delivery toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Antar Sendiri',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              'Antar pesanan tanpa driver Kuwrir',
                              style: TextStyle(
                                  fontSize: 12, color: KuwrirColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: merchant.canSelfDeliver,
                        onChanged: (v) => _toggleSelfDeliver(context, v),
                        activeColor: KuwrirColors.primary,
                      ),
                    ],
                  ),
                ),
              ),

              if (merchant.canSelfDeliver) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ongkir Antar Sendiri',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          'Tarif yang ditampilkan ke pelanggan (0 = gratis)',
                          style: TextStyle(
                              fontSize: 12, color: KuwrirColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Rp ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                            Expanded(
                              child: TextField(
                                controller: _selfDeliveryFeeCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _saveSelfDeliveryFee(context),
                              child: const Text('Simpan'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Free-delivery toggle (store-wide — powers the customer app's
              // "Gratis Ongkir" search filter)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Gratis Ongkir',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              'Semua produk tokomu muncul di filter Gratis Ongkir pelanggan',
                              style: TextStyle(
                                  fontSize: 12, color: KuwrirColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: merchant.isFreeDelivery,
                        onChanged: (v) => _toggleFreeDelivery(context, v),
                        activeColor: KuwrirColors.primary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Tax / PKP Settings ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pemungut Pajak (PKP)',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  merchant.taxEnabled
                                      ? 'Aktif — PPN dikenakan ke pelanggan'
                                      : 'Nonaktif — toko UMKM, tanpa PPN',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: merchant.taxEnabled
                                          ? KuwrirColors.primary
                                          : KuwrirColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: merchant.taxEnabled,
                            onChanged: (v) => _toggleTax(context, v, merchant.taxRate),
                            activeColor: KuwrirColors.primary,
                          ),
                        ],
                      ),
                      if (merchant.taxEnabled) ...[
                        const SizedBox(height: 12),
                        const Text('Rate Pajak (%)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _taxRateCtrl
                                  ..text = merchant.taxRate != null
                                      ? merchant.taxRate!.toStringAsFixed(0)
                                      : '',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: 'Kosong = ikuti default platform (11%)',
                                  suffixText: '%',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _saveTaxRate(context),
                              child: const Text('Simpan'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Biarkan kosong untuk menggunakan rate default platform',
                          style: TextStyle(
                              fontSize: 11, color: KuwrirColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: KuwrirColors.textSecondary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: KuwrirColors.textHint)),
              Text(value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
