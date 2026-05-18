import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Mock order for display
class _MockOrder {
  final String id;
  final String orderNumber;
  final String customerName;
  final double total;
  final int itemCount;
  final String deliveryType; // 'platform' or 'self'
  String status; // pending, confirmed, preparing, ready

  _MockOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.total,
    required this.itemCount,
    required this.status,
    this.deliveryType = 'platform',
  });
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final List<_MockOrder> _orders = [
    _MockOrder(
      id: '1', orderNumber: 'KWR-260507091015',
      customerName: 'John Tourist', total: 72500, itemCount: 3, status: 'pending',
    ),
    _MockOrder(
      id: '2', orderNumber: 'KWR-260507094522',
      customerName: 'Maria Guest', total: 61000, itemCount: 2, status: 'confirmed',
      deliveryType: 'self', // Self-delivery order!
    ),
    _MockOrder(
      id: '3', orderNumber: 'KWR-260507101200',
      customerName: 'Budi Lombok', total: 89500, itemCount: 4, status: 'preparing',
    ),
  ];

  bool _isOpen = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Orders',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => setState(() => _isOpen = !_isOpen),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_isOpen ? KuwrirColors.success : KuwrirColors.error).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: _isOpen ? KuwrirColors.success : KuwrirColors.error, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(_isOpen ? 'Store Open' : 'Store Closed', style: TextStyle(color: _isOpen ? KuwrirColors.success : KuwrirColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Order list
          Expanded(
            child: _orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: KuwrirColors.textHint),
                        const SizedBox(height: 16),
                        Text('No active orders', style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      return _OrderCard(
                        order: order,
                        onAction: () {
                          setState(() {
                            switch (order.status) {
                              case 'pending':
                                order.status = 'confirmed';
                                break;
                              case 'confirmed':
                                order.status = 'preparing';
                                break;
                              case 'preparing':
                                order.status = 'ready';
                                break;
                              case 'ready':
                                if (order.deliveryType == 'self') {
                                  // Self-delivery: merchant picks up
                                  order.status = 'picked_up';
                                } else {
                                  _orders.removeAt(index); // Picked up by driver
                                }
                                break;
                              case 'picked_up':
                                _orders.removeAt(index); // Delivered by merchant
                                break;
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final _MockOrder order;
  final VoidCallback onAction;

  const _OrderCard({required this.order, required this.onAction});

  @override
  Widget build(BuildContext context) {
    // For self-delivery orders with 'ready' status, use special config
    _StatusConfig config;
    if (order.deliveryType == 'self' && order.status == 'ready') {
      config = _StatusConfig(label: 'Ready', color: KuwrirColors.primary, actionIcon: Icons.delivery_dining, actionLabel: 'Antar Sendiri');
    } else if (order.status == 'picked_up') {
      config = _StatusConfig(label: 'Sedang Diantar', color: const Color(0xFF0EA5E9), actionIcon: Icons.check_circle, actionLabel: 'Pesanan Sampai');
    } else {
      config = _statusConfig[order.status]!;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                ),
                if (order.deliveryType == 'self')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: KuwrirColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Self-Delivery', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: KuwrirColors.primary)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: config.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(config.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: config.color)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer + items
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: KuwrirColors.textSecondary),
                const SizedBox(width: 4),
                Text(order.customerName, style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
                const Spacer(),
                Text('${order.itemCount} items', style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'IDR ${order.total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: KuwrirColors.primary),
            ),
            const SizedBox(height: 12),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(config.actionIcon, size: 18),
                label: Text(config.actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.color,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusConfig {
  final String label;
  final Color color;
  final IconData actionIcon;
  final String actionLabel;

  _StatusConfig({required this.label, required this.color, required this.actionIcon, required this.actionLabel});
}

final Map<String, _StatusConfig> _statusConfig = {
  'pending': _StatusConfig(label: 'New Order', color: KuwrirColors.warning, actionIcon: Icons.check_circle, actionLabel: 'Accept Order'),
  'confirmed': _StatusConfig(label: 'Confirmed', color: KuwrirColors.info, actionIcon: Icons.store, actionLabel: 'Start Preparing'),
  'preparing': _StatusConfig(label: 'Preparing', color: const Color(0xFF8B5CF6), actionIcon: Icons.check, actionLabel: 'Mark Ready'),
  'ready': _StatusConfig(label: 'Ready', color: KuwrirColors.success, actionIcon: Icons.delivery_dining, actionLabel: 'Waiting for Driver'),
};
