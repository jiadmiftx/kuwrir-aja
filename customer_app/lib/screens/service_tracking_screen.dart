import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Service order tracking — 8-step timeline
class ServiceTrackingScreen extends StatelessWidget {
  final String orderNumber;
  final String merchantName;
  final String category;
  final double totalCod;
  final DateTime? scheduledAt;

  const ServiceTrackingScreen({
    super.key,
    required this.orderNumber,
    required this.merchantName,
    required this.category,
    required this.totalCod,
    this.scheduledAt,
  });

  // Simulate current status (in production: fetched from API)
  static const _currentStatus = 'confirmed';

  static const _steps = [
    (id: 'pending',           label: 'Pesanan Diterima',        desc: 'Menunggu konfirmasi merchant',        icon: Icons.receipt_long),
    (id: 'confirmed',         label: 'Dikonfirmasi',            desc: 'Merchant akan segera kirim kurir',    icon: Icons.check_circle),
    (id: 'awaiting_pickup',   label: 'Kurir Menuju Lokasi',     desc: 'Kurir dalam perjalanan ke kamu',      icon: Icons.delivery_dining),
    (id: 'item_picked_up',    label: 'Barang Diambil',          desc: 'Barang dibawa ke tempat jasa',        icon: Icons.inventory_2),
    (id: 'in_service',        label: 'Sedang Dikerjakan',       desc: 'Proses layanan berlangsung',          icon: Icons.build),
    (id: 'ready_for_return',  label: 'Selesai',                 desc: 'Menunggu kurir untuk antar balik',    icon: Icons.done_all),
    (id: 'returning',         label: 'Sedang Diantar Balik',    desc: 'Kurir dalam perjalanan ke kamu',      icon: Icons.local_shipping),
    (id: 'returned',          label: 'Selesai & Diterima',      desc: 'Barang sudah kembali — bayar COD',    icon: Icons.home),
  ];

  int get _currentIdx => _steps.indexWhere((s) => s.id == _currentStatus).clamp(0, _steps.length - 1);

  String _fmt(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';

  String _categoryEmoji(String cat) {
    const e = {'laundry': '👕', 'bengkel': '🔧', 'cleaning': '🧹', 'salon': '💇'};
    return e[cat] ?? '🔧';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Pesanan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_categoryEmoji(category), style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(merchantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(orderNumber, style: const TextStyle(color: Colors.grey, fontFamily: 'monospace')),
                    if (scheduledAt != null) ...[
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.schedule, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Jemput: ${scheduledAt!.day}/${scheduledAt!.month} pukul ${scheduledAt!.hour.toString().padLeft(2,'0')}:${scheduledAt!.minute.toString().padLeft(2,'0')}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // COD reminder
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.payments, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Bayar COD saat barang dikembalikan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Text(_fmt(totalCod), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  const Text('Siapkan uang tunai saat kurir datang', style: TextStyle(color: Colors.green, fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 20),

            // Timeline
            const Text('Status Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ..._steps.asMap().entries.map((e) => _buildStep(e.key, e.value)),
            const SizedBox(height: 16),

            // Help
            OutlinedButton.icon(
              icon: const Icon(Icons.help_outline),
              label: const Text('Hubungi Merchant'),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int idx, ({String id, String label, String desc, IconData icon}) step) {
    final done = idx < _currentIdx;
    final active = idx == _currentIdx;
    final pending = idx > _currentIdx;

    final color = done
        ? Colors.green
        : active
            ? KuwrirColors.primary
            : Colors.grey.shade300;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step icon + connector
          Column(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(pending ? 0.15 : 1),
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Icon(step.icon, color: pending ? Colors.grey.shade400 : Colors.white, size: 16),
            ),
            if (idx < _steps.length - 1)
              Container(
                width: 2,
                height: 32,
                color: done ? Colors.green.withOpacity(0.3) : Colors.grey.shade200,
              ),
          ]),
          const SizedBox(width: 12),
          // Label + desc
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      color: pending ? Colors.grey.shade400 : null,
                      fontSize: active ? 15 : 14,
                    ),
                  ),
                  if (active || done)
                    Text(step.desc, style: TextStyle(color: active ? Colors.grey : Colors.grey.shade400, fontSize: 12)),
                  if (active) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: KuwrirColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Status saat ini', style: TextStyle(color: KuwrirColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
