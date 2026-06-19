import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Piutang / Tab pelanggan untuk POS Merchant
/// Mirip fitur piutang di finansial-mac
class KasirReceivablesScreen extends StatefulWidget {
  const KasirReceivablesScreen({super.key});

  @override
  State<KasirReceivablesScreen> createState() => _KasirReceivablesScreenState();
}

class _KasirReceivablesScreenState extends State<KasirReceivablesScreen> {
  String _filter = 'all'; // all, unpaid, partial, paid

  // Mock data — in production fetched from GET /my-store/pos/receivables
  final List<_Receivable> _receivables = [
    _Receivable(
      id: '1', customerName: 'Bapak Wayan', customerPhone: '08123456789',
      description: 'Tab dari transaksi POS-260601143022',
      amount: 87500, paidAmount: 0, status: 'unpaid',
      dueDate: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    _Receivable(
      id: '2', customerName: 'Ibu Made', customerPhone: '08234567890',
      description: 'Tab makan siang 3 hari',
      amount: 125000, paidAmount: 75000, status: 'partial',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    _Receivable(
      id: '3', customerName: 'Pak Ketut', customerPhone: '',
      description: 'Tab dari transaksi POS-260530091015',
      amount: 52000, paidAmount: 52000, status: 'paid',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  List<_Receivable> get _filtered {
    if (_filter == 'all') return _receivables;
    return _receivables.where((r) => r.status == _filter).toList();
  }

  double get _totalUnpaid => _receivables
      .where((r) => r.status != 'paid')
      .fold(0, (s, r) => s + (r.amount - r.paidAmount));

  String _fmt(double v) {
    final s = v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
    return 'Rp $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Piutang / Tab Pelanggan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Catat piutang manual',
            onPressed: _showAddReceivableDialog,
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
              gradient: LinearGradient(colors: [KuwrirColors.primary, KuwrirColors.primary.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_forward, color: Colors.white),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Piutang Belum Lunas', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(_fmt(_totalUnpaid), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                ? const Center(child: Text('Tidak ada piutang', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildReceivableCard(_filtered[i]),
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

  Widget _buildReceivableCard(_Receivable r) {
    final outstanding = r.amount - r.paidAmount;
    final progress = r.amount > 0 ? r.paidAmount / r.amount : 0.0;
    final isOverdue = r.dueDate != null && r.dueDate!.isBefore(DateTime.now()) && r.status != 'paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                _statusChip(r.status),
              ],
            ),
            if (r.customerPhone.isNotEmpty) Text(r.customerPhone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(r.description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(_fmt(r.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  const Text('Terbayar', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(_fmt(r.paidAmount), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Sisa', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(_fmt(outstanding), style: TextStyle(color: outstanding > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                ]),
              ],
            ),

            if (r.status != 'paid') ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.withOpacity(0.2),
                color: KuwrirColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ],

            if (r.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 14, color: isOverdue ? Colors.red : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Jatuh tempo: ${r.dueDate!.day}/${r.dueDate!.month}/${r.dueDate!.year}',
                      style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey),
                    ),
                    if (isOverdue) const Text(' (Jatuh Tempo!)', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            // Action buttons
            if (r.status != 'paid')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Riwayat'),
                      onPressed: () => _showPaymentHistory(r),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Terima Bayar'),
                      onPressed: () => _showPaymentDialog(r),
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
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
    final colors = {
      'unpaid': Colors.red,
      'partial': Colors.orange,
      'paid': Colors.green,
    };
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

  void _showPaymentDialog(_Receivable r) {
    final ctrl = TextEditingController();
    String method = 'cash';
    final outstanding = r.amount - r.paidAmount;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Terima Pembayaran — ${r.customerName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sisa piutang: ${_fmt(outstanding)}', style: TextStyle(color: KuwrirColors.primary, fontWeight: FontWeight.bold)),
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
                  r.paidAmount += amount;
                  if (r.paidAmount >= r.amount) r.status = 'paid';
                  else r.status = 'partial';
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

  void _showPaymentHistory(_Receivable r) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Riwayat Pembayaran — ${r.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            const Center(child: Text('Belum ada riwayat pembayaran', style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  void _showAddReceivableDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catat Piutang Manual'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Pelanggan *', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. HP', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Keterangan', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah (Rp) *', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (name.isEmpty || amount <= 0) return;
              setState(() {
                _receivables.insert(0, _Receivable(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  customerName: name,
                  customerPhone: phoneCtrl.text,
                  description: descCtrl.text.isEmpty ? 'Piutang manual' : descCtrl.text,
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

class _Receivable {
  final String id;
  final String customerName;
  final String customerPhone;
  final String description;
  final double amount;
  double paidAmount;
  String status;
  final DateTime? dueDate;
  final DateTime createdAt;

  _Receivable({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.description,
    required this.amount,
    required this.paidAmount,
    required this.status,
    this.dueDate,
    required this.createdAt,
  });
}
