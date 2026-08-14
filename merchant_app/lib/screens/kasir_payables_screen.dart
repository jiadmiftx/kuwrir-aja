import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Hutang supplier untuk POS Merchant
/// Mirip fitur hutang di finansial-mac
class KasirPayablesScreen extends StatefulWidget {
  const KasirPayablesScreen({super.key});

  @override
  State<KasirPayablesScreen> createState() => _KasirPayablesScreenState();
}

class _KasirPayablesScreenState extends State<KasirPayablesScreen> {
  String _filter = 'all';

  // Mock data — in production fetched from GET /my-store/pos/payables
  final List<_Payable> _payables = [
    _Payable(
      id: '1', supplierName: 'Toko Bahan Pak Slamet', supplierPhone: '08131234567',
      description: 'Bahan baku mingguan: sayuran, bumbu',
      amount: 280000, paidAmount: 0, status: 'unpaid',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    _Payable(
      id: '2', supplierName: 'CV Minuman Segar', supplierPhone: '08223456789',
      description: 'Stok minuman kemasan',
      amount: 175000, paidAmount: 100000, status: 'partial',
      dueDate: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    _Payable(
      id: '3', supplierName: 'UD Gas & Air', supplierPhone: '',
      description: 'Gas LPG 3 tabung',
      amount: 105000, paidAmount: 105000, status: 'paid',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  List<_Payable> get _filtered {
    if (_filter == 'all') return _payables;
    return _payables.where((p) => p.status == _filter).toList();
  }

  double get _totalUnpaid => _payables
      .where((p) => p.status != 'paid')
      .fold(0, (s, p) => s + (p.amount - p.paidAmount));

  String _fmt(double v) {
    final s = v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
    return 'Rp $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hutang Supplier'),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
            tooltip: 'Catat hutang baru',
            onPressed: _showAddPayableDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: Colors.red.shade700),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Hutang Belum Lunas', style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
                    Text(_fmt(_totalUnpaid), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                  ],
                ),
              ],
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _filterChip('all', 'Semua'),
                const SizedBox(width: 8),
                _filterChip('unpaid', 'Belum Lunas'),
                const SizedBox(width: 8),
                _filterChip('partial', 'Sebagian'),
                const SizedBox(width: 8),
                _filterChip('paid', 'Lunas'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('Tidak ada hutang', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildPayableCard(_filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildPayableCard(_Payable p) {
    final outstanding = p.amount - p.paidAmount;
    final progress = p.amount > 0 ? p.paidAmount / p.amount : 0.0;
    final isOverdue = p.dueDate != null && p.dueDate!.isBefore(DateTime.now()) && p.status != 'paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(p.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                _statusChip(p.status),
              ],
            ),
            if (p.supplierPhone.isNotEmpty) Text(p.supplierPhone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(p.description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(_fmt(p.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  const Text('Terbayar', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(_fmt(p.paidAmount), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Sisa', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(_fmt(outstanding), style: TextStyle(color: outstanding > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                ]),
              ],
            ),

            if (p.status != 'paid') ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.withOpacity(0.2),
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
            ],

            if (p.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, size: 14, color: isOverdue ? Colors.red : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Jatuh tempo: ${p.dueDate!.day}/${p.dueDate!.month}/${p.dueDate!.year}',
                      style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey),
                    ),
                    if (isOverdue) const Text(' (JATUH TEMPO!)', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            // Action buttons
            if (p.status != 'paid')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Spacer(),
                    FilledButton.icon(
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedPayment01, size: 16),
                      label: const Text('Catat Pembayaran'),
                      onPressed: () => _showPaymentDialog(p),
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, backgroundColor: Colors.red),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final colors = {'unpaid': Colors.red, 'partial': Colors.orange, 'paid': Colors.green};
    final labels = {'unpaid': 'Belum Lunas', 'partial': 'Sebagian', 'paid': 'Lunas'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (colors[status] ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors[status] ?? Colors.grey),
      ),
      child: Text(labels[status] ?? status, style: TextStyle(color: colors[status], fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _showPaymentDialog(_Payable p) {
    final ctrl = TextEditingController();
    String method = 'cash';
    final outstanding = p.amount - p.paidAmount;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Bayar Hutang — ${p.supplierName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sisa hutang: ${_fmt(outstanding)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah Pembayaran (Rp)', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              const Text('Metode:', style: TextStyle(fontWeight: FontWeight.w600)),
              Row(children: [
                Radio<String>(value: 'cash', groupValue: method, onChanged: (v) => setLocal(() => method = v!)),
                const Text('Cash'),
                const SizedBox(width: 12),
                Radio<String>(value: 'transfer', groupValue: method, onChanged: (v) => setLocal(() => method = v!)),
                const Text('Transfer'),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(ctrl.text) ?? 0;
                if (amount <= 0 || amount > outstanding) return;
                setState(() {
                  p.paidAmount += amount;
                  if (p.paidAmount >= p.amount) p.status = 'paid';
                  else p.status = 'partial';
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Pembayaran ${_fmt(amount)} dicatat'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Catat'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPayableDialog() {
    final supplierCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catat Hutang Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: supplierCtrl, decoration: const InputDecoration(labelText: 'Nama Supplier *', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. HP Supplier', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Keterangan (barang/jasa)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah Hutang (Rp) *', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final supplier = supplierCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (supplier.isEmpty || amount <= 0) return;
              setState(() {
                _payables.insert(0, _Payable(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  supplierName: supplier,
                  supplierPhone: phoneCtrl.text,
                  description: descCtrl.text.isEmpty ? 'Pembelian bahan/supplies' : descCtrl.text,
                  amount: amount, paidAmount: 0, status: 'unpaid',
                  createdAt: DateTime.now(),
                ));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _Payable {
  final String id;
  final String supplierName;
  final String supplierPhone;
  final String description;
  final double amount;
  double paidAmount;
  String status;
  final DateTime? dueDate;
  final DateTime createdAt;

  _Payable({
    required this.id,
    required this.supplierName,
    required this.supplierPhone,
    required this.description,
    required this.amount,
    required this.paidAmount,
    required this.status,
    this.dueDate,
    required this.createdAt,
  });
}
