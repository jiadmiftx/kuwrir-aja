import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'package:hugeicons/hugeicons.dart';

/// Laporan keuangan POS untuk merchant
/// Mencakup: Laba Rugi, Arus Kas, Stok — terinspirasi dari finansial-mac
class KasirReportsScreen extends StatefulWidget {
  const KasirReportsScreen({super.key});

  @override
  State<KasirReportsScreen> createState() => _KasirReportsScreenState();
}

class _KasirReportsScreenState extends State<KasirReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Date range — default: bulan berjalan
  late DateTime _from;
  late DateTime _to;

  // Mock report data — in production fetched from /my-store/pos/reports/*
  late _SummaryData _summary;
  late _LabaRugiData _labaRugi;
  late _ArusKasData _arusKas;
  late List<_StokItem> _stokItems;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = now;
    _loadMockData();
  }

  void _loadMockData() {
    _summary = _SummaryData(
      revenue: 4750000,
      totalCost: 2180000,
      grossProfit: 2570000,
      grossMarginPct: 54.1,
      txCount: 87,
      receivableUnpaid: 320000,
      payableUnpaid: 450000,
    );
    _labaRugi = _LabaRugiData(
      pendapatan: 4750000,
      hpp: 2180000,
      labaKotor: 2570000,
      pctLabaKotor: 54.1,
      bebanOperasional: 850000,
      labaBersih: 1720000,
      pctLabaBersih: 36.2,
    );
    _arusKas = _ArusKasData(
      masukPenjualan: 4100000,
      masukPiutangTerbayar: 180000,
      keluarBayarHutang: 650000,
      arusKasBersih: 3630000,
      breakdown: [
        _PaymentBreakdown('cash', 2800000, 61),
        _PaymentBreakdown('qris', 1100000, 19),
        _PaymentBreakdown('card', 200000, 3),
        _PaymentBreakdown('tab', 650000, 4),
      ],
    );
    _stokItems = [
      _StokItem('Es Teh Manis', 'MIN-001', 30, 5, 2500, lowStock: false),
      _StokItem('Es Jeruk', 'MIN-002', 25, 5, 3000, lowStock: false),
      _StokItem('Kopi Hitam', 'MIN-003', 20, 5, 3500, lowStock: false),
      _StokItem('Pisang Goreng', 'SNK-001', 5, 8, 6000, lowStock: true),
      _StokItem('Teh Botol', 'MIN-004', 2, 10, 2000, lowStock: true),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    final abs = v.abs();
    final s = abs.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.',
    );
    return v < 0 ? '-Rp $s' : 'Rp $s';
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range != null) {
      setState(() { _from = range.start; _to = range.end; });
      // TODO: call API with new date range
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedCalendar03),
            tooltip: 'Pilih periode',
            onPressed: _pickDateRange,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Laba Rugi', icon: HugeIcon(icon: HugeIcons.strokeRoundedAnalyticsUp)),
            Tab(text: 'Arus Kas', icon: HugeIcon(icon: HugeIcons.strokeRoundedWallet01)),
            Tab(text: 'Stok', icon: HugeIcon(icon: HugeIcons.strokeRoundedPackage)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Period indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                const HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${_from.day}/${_from.month}/${_from.year} — ${_to.day}/${_to.month}/${_to.year}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const Spacer(),
                TextButton(onPressed: _pickDateRange, child: const Text('Ubah', style: TextStyle(fontSize: 12))),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLabaRugi(),
                _buildArusKas(),
                _buildStok(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Laba Rugi (mirip laba_rugi.html di finansial-mac) ──────────────────────

  Widget _buildLabaRugi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(child: _kpiCard('Pendapatan', _labaRugi.pendapatan, color: Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _kpiCard('Laba Bersih', _labaRugi.labaBersih, color: KuwrirColors.primary)),
            ],
          ),
          const SizedBox(height: 12),

          // P&L breakdown card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Laporan Laba Rugi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(height: 20),
                  _plRow('Pendapatan Penjualan', _labaRugi.pendapatan, isBold: true, color: Colors.green),
                  const SizedBox(height: 8),
                  _plRow('(-) HPP / Harga Pokok', -_labaRugi.hpp, color: Colors.red.shade700),
                  const Divider(height: 16),
                  _plRow('Laba Kotor', _labaRugi.labaKotor, isBold: true),
                  _plPct('Margin Laba Kotor', _labaRugi.pctLabaKotor),
                  const SizedBox(height: 8),
                  _plRow('(-) Beban Operasional', -_labaRugi.bebanOperasional, color: Colors.orange.shade700),
                  const Divider(height: 16),
                  _plRow('Laba Bersih', _labaRugi.labaBersih, isBold: true, color: KuwrirColors.primary),
                  _plPct('Margin Laba Bersih', _labaRugi.pctLabaBersih),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Transaction count
          Card(
            child: ListTile(
              leading: const HugeIcon(icon: HugeIcons.strokeRoundedInvoice01),
              title: const Text('Total Transaksi'),
              trailing: Text('${_summary.txCount}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),

          // Receivable & payable outstanding
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _outstandingCard('Piutang Belum Lunas', _summary.receivableUnpaid, HugeIcons.strokeRoundedArrowRight01, Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _outstandingCard('Hutang Belum Lunas', _summary.payableUnpaid, HugeIcons.strokeRoundedArrowLeft01, Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _plRow(String label, double value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(_fmt(value), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  Widget _plPct(String label, double pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // ─── Arus Kas (mirip arus_kas.html di finansial-mac) ─────────────────────────

  Widget _buildArusKas() {
    final total = _arusKas.masukPenjualan + _arusKas.masukPiutangTerbayar;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Net cash KPI
          _kpiCard('Arus Kas Bersih', _arusKas.arusKasBersih, color: _arusKas.arusKasBersih >= 0 ? Colors.green : Colors.red, fullWidth: true),
          const SizedBox(height: 12),

          // Cash in / out
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Arus Kas Periode Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(height: 20),
                  _cashRow('Kas Masuk - Penjualan Tunai/QRIS/Kartu', _arusKas.masukPenjualan, isPositive: true),
                  _cashRow('Kas Masuk - Piutang Terbayar', _arusKas.masukPiutangTerbayar, isPositive: true),
                  const Divider(height: 12),
                  _cashRow('Total Kas Masuk', total, isPositive: true, isBold: true),
                  const SizedBox(height: 8),
                  _cashRow('Kas Keluar - Bayar Hutang Supplier', _arusKas.keluarBayarHutang, isPositive: false),
                  const Divider(height: 12),
                  _cashRow('Arus Kas Bersih', _arusKas.arusKasBersih, isPositive: _arusKas.arusKasBersih >= 0, isBold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Payment method breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Breakdown per Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(height: 20),
                  ..._arusKas.breakdown.map((b) => _buildBreakdownRow(b, total)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cashRow(String label, double v, {required bool isPositive, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Text(
            (isPositive ? '+' : '-') + _fmt(v),
            style: TextStyle(
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(_PaymentBreakdown b, double total) {
    final pct = total > 0 ? b.total / total * 100 : 0.0;
    final icons = {'cash': HugeIcons.strokeRoundedMoney01, 'qris': HugeIcons.strokeRoundedQrCode01, 'card': HugeIcons.strokeRoundedCreditCard, 'tab': HugeIcons.strokeRoundedUser};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icons[b.method] ?? HugeIcons.strokeRoundedPayment01, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(b.method.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${b.count}x · ${_fmt(b.total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: Colors.grey.withOpacity(0.2),
            color: KuwrirColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          Text('${pct.toStringAsFixed(1)}% dari total', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // ─── Stok (mirip stok.html di finansial-mac) ─────────────────────────────────

  Widget _buildStok() {
    final lowStockItems = _stokItems.where((i) => i.lowStock).toList();
    double totalValue = _stokItems.fold(0, (s, i) => s + i.stockValue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total stock value
          _kpiCard('Nilai Stok Total', totalValue, color: KuwrirColors.primary, fullWidth: true),
          const SizedBox(height: 12),

          // Low stock alerts
          if (lowStockItems.isNotEmpty) ...[
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('${lowStockItems.length} Produk Stok Menipis',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...lowStockItems.map((i) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedCircle, size: 8, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(child: Text(i.name)),
                          Text('Sisa: ${i.stock}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          Text(' / Min: ${i.minStock}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Full stock table
          const Text('Daftar Stok Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: _stokItems.asMap().entries.map((e) {
                final i = e.value;
                final isLast = e.key == _stokItems.length - 1;
                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: i.lowStock ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.1),
                        child: HugeIcon(
                          icon: i.lowStock ? HugeIcons.strokeRoundedAlert02 : HugeIcons.strokeRoundedTick01,
                          color: i.lowStock ? Colors.orange : Colors.green,
                          size: 18,
                        ),
                      ),
                      title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${i.sku} · HPP: ${_fmt(i.costPrice)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${i.stock} unit', style: TextStyle(fontWeight: FontWeight.bold, color: i.lowStock ? Colors.orange : null)),
                          Text(_fmt(i.stockValue), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared widgets ─────────────────────────────────────────────────────────

  Widget _kpiCard(String label, double value, {required Color color, bool fullWidth = false}) {
    return Card(
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_fmt(value), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _outstandingCard(String label, double value, List<List<dynamic>> icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            HugeIcon(icon: icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(_fmt(value), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _SummaryData {
  final double revenue, totalCost, grossProfit, grossMarginPct;
  final int txCount;
  final double receivableUnpaid, payableUnpaid;
  _SummaryData({required this.revenue, required this.totalCost, required this.grossProfit, required this.grossMarginPct, required this.txCount, required this.receivableUnpaid, required this.payableUnpaid});
}

class _LabaRugiData {
  final double pendapatan, hpp, labaKotor, pctLabaKotor, bebanOperasional, labaBersih, pctLabaBersih;
  _LabaRugiData({required this.pendapatan, required this.hpp, required this.labaKotor, required this.pctLabaKotor, required this.bebanOperasional, required this.labaBersih, required this.pctLabaBersih});
}

class _ArusKasData {
  final double masukPenjualan, masukPiutangTerbayar, keluarBayarHutang, arusKasBersih;
  final List<_PaymentBreakdown> breakdown;
  _ArusKasData({required this.masukPenjualan, required this.masukPiutangTerbayar, required this.keluarBayarHutang, required this.arusKasBersih, required this.breakdown});
}

class _PaymentBreakdown {
  final String method;
  final double total;
  final int count;
  _PaymentBreakdown(this.method, this.total, this.count);
}

class _StokItem {
  final String name, sku;
  final int stock, minStock;
  final double costPrice;
  final bool lowStock;
  _StokItem(this.name, this.sku, this.stock, this.minStock, this.costPrice, {required this.lowStock});
  double get stockValue => stock * costPrice;
}
