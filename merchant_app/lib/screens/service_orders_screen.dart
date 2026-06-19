import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Service order management for jasa merchants (laundry, bengkel, etc.)
/// Statuses handled here: confirmed → in_service → ready_for_return
class ServiceOrdersScreen extends StatefulWidget {
  const ServiceOrdersScreen({super.key});

  @override
  State<ServiceOrdersScreen> createState() => _ServiceOrdersScreenState();
}

// ─── Mock data ────────────────────────────────────────────────────────────────

class _ServiceOrder {
  final String id, orderNumber, customerName, customerPhone;
  final List<String> items;
  final double total, weightKg;
  final String serviceNotes, pickupAddress;
  String status;
  final DateTime createdAt;
  final DateTime? scheduledAt;

  _ServiceOrder({
    required this.id, required this.orderNumber,
    required this.customerName, required this.customerPhone,
    required this.items, required this.total,
    required this.status, required this.createdAt,
    required this.pickupAddress,
    this.weightKg = 0,
    this.serviceNotes = '',
    this.scheduledAt,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class _ServiceOrdersScreenState extends State<ServiceOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_ServiceOrder> _orders = [
    _ServiceOrder(
      id: '1', orderNumber: 'SVC-260601091015',
      customerName: 'Ibu Ratna', customerPhone: '08123456789',
      items: ['Cuci + Setrika (4kg)'], total: 86000, weightKg: 4,
      status: 'confirmed',
      pickupAddress: 'Jl. Pantai Kuta No. 5',
      serviceNotes: 'Pisahkan baju putih',
      scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    _ServiceOrder(
      id: '2', orderNumber: 'SVC-260601094522',
      customerName: 'Pak Budi', customerPhone: '08234567890',
      items: ['Servis Ringan', 'Tambal Ban ×2'], total: 135000,
      status: 'item_picked_up',
      pickupAddress: 'Jl. Raya No. 12',
      serviceNotes: 'Ganti oli Castrol 10W-40',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    _ServiceOrder(
      id: '3', orderNumber: 'SVC-260601101200',
      customerName: 'Mbak Sari', customerPhone: '08345678901',
      items: ['Cuci + Setrika (6kg)'], total: 117000, weightKg: 6,
      status: 'in_service',
      pickupAddress: 'Villa Kuta No. 8',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    _ServiceOrder(
      id: '4', orderNumber: 'SVC-260601082030',
      customerName: 'Pak Joko', customerPhone: '08456789012',
      items: ['Tune Up'], total: 187000,
      status: 'ready_for_return',
      pickupAddress: 'Jl. Bypass No. 23',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  final _tabs = const [
    (status: 'confirmed',        label: 'Baru'),
    (status: 'item_picked_up',   label: 'Diambil'),
    (status: 'in_service',       label: 'Dikerjakan'),
    (status: 'ready_for_return', label: 'Siap'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_ServiceOrder> _byStatus(String status) =>
      _orders.where((o) => o.status == status).toList();

  String _fmt(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';

  void _transition(String id, String from, String to, String actionLabel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(actionLabel),
        content: Text('Update status order ke "$to"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              // TODO: call API
              setState(() {
                final order = _orders.firstWhere((o) => o.id == id);
                order.status = to;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$actionLabel berhasil'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Jasa'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) {
            final count = _byStatus(t.status).length;
            return Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t.label),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  CircleAvatar(radius: 9, backgroundColor: KuwrirColors.primary, child: Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white))),
                ],
              ]),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _buildOrderList(_byStatus(t.status), t.status)).toList(),
      ),
    );
  }

  Widget _buildOrderList(List<_ServiceOrder> orders, String status) {
    if (orders.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text('Tidak ada order ${_statusLabel(status)}', style: const TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (_, i) => _buildOrderCard(orders[i]),
    );
  }

  Widget _buildOrderCard(_ServiceOrder o) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.orderNumber, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  Text(o.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(o.customerPhone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ),
              _statusBadge(o.status),
            ]),
            const Divider(height: 16),

            // Items
            ...o.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.arrow_right, size: 16, color: Colors.grey),
                Text(item, style: const TextStyle(fontSize: 13)),
              ]),
            )),
            if (o.weightKg > 0)
              Text('Berat: ${o.weightKg} kg', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (o.serviceNotes.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade200)),
                child: Row(children: [
                  const Icon(Icons.note, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(child: Text(o.serviceNotes, style: const TextStyle(fontSize: 12))),
                ]),
              ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(o.total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: KuwrirColors.primary)),
                if (o.scheduledAt != null)
                  Text('Jemput: ${o.scheduledAt!.hour}:${o.scheduledAt!.minute.toString().padLeft(2,'0')}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            Text('📍 ${o.pickupAddress}', style: const TextStyle(color: Colors.grey, fontSize: 12)),

            // Action buttons
            const SizedBox(height: 10),
            _buildActionButton(o),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(_ServiceOrder o) {
    switch (o.status) {
      case 'confirmed':
        return const Row(children: [
          Expanded(child: SizedBox()),
          Icon(Icons.delivery_dining, color: Colors.orange, size: 16),
          SizedBox(width: 4),
          Text('Menunggu kurir jemput barang', style: TextStyle(color: Colors.orange, fontSize: 13)),
        ]);

      case 'item_picked_up':
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.build, size: 16),
            label: const Text('Mulai Kerjakan'),
            onPressed: () => _transition(o.id, 'item_picked_up', 'in_service', 'Mulai Kerjakan'),
          ),
        );

      case 'in_service':
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('Tandai Selesai'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => _transition(o.id, 'in_service', 'ready_for_return', 'Tandai Selesai'),
          ),
        );

      case 'ready_for_return':
        return Row(children: [
          const Icon(Icons.pending_actions, color: Colors.blue, size: 16),
          const SizedBox(width: 6),
          const Expanded(child: Text('Menunggu kurir untuk antar balik ke customer', style: TextStyle(color: Colors.blue, fontSize: 13))),
        ]);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _statusBadge(String status) {
    final cfg = {
      'confirmed':        (label: 'Dikonfirmasi',    color: Colors.blue),
      'awaiting_pickup':  (label: 'Kurir Menuju',    color: Colors.orange),
      'item_picked_up':   (label: 'Barang Diambil',  color: Colors.purple),
      'in_service':       (label: 'Dikerjakan',      color: Colors.indigo),
      'ready_for_return': (label: 'Siap Kirim',      color: Colors.green),
    };
    final c = cfg[status] ?? (label: status, color: Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(c.label, style: TextStyle(color: c.color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  String _statusLabel(String status) {
    const labels = {
      'confirmed': 'dikonfirmasi', 'item_picked_up': 'barang diambil',
      'in_service': 'sedang dikerjakan', 'ready_for_return': 'siap dikembalikan',
    };
    return labels[status] ?? status;
  }
}
