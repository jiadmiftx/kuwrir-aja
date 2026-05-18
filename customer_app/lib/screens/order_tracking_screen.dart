import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderNumber;
  final String merchantName;
  final double total;

  const OrderTrackingScreen({
    super.key,
    required this.orderNumber,
    required this.merchantName,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order $orderNumber')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.delivery_dining, size: 48, color: KuwrirColors.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'Your order is being prepared',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(merchantName, style: TextStyle(color: KuwrirColors.textSecondary)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: KuwrirColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Estimated: 20-25 min',
                        style: TextStyle(color: KuwrirColors.warning, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Timeline
            const Text('Order Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            _TimelineStep(title: 'Order Placed', subtitle: '10:12 AM', isCompleted: true, isFirst: true),
            _TimelineStep(title: 'Merchant Confirmed', subtitle: '10:13 AM', isCompleted: true),
            _TimelineStep(title: 'Preparing Product', subtitle: 'In progress...', isCompleted: false, isActive: true),
            _TimelineStep(title: 'Ready for Pickup', subtitle: '', isCompleted: false),
            _TimelineStep(title: 'Driver Picked Up', subtitle: '', isCompleted: false),
            _TimelineStep(title: 'Delivered', subtitle: '', isCompleted: false, isLast: true),

            const SizedBox(height: 24),

            // Payment info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.payments, size: 18, color: KuwrirColors.warning),
                            const SizedBox(width: 8),
                            const Text('Cash on Delivery'),
                          ],
                        ),
                        Text(
                          'IDR ${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: KuwrirColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;
  final bool isFirst;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.isActive = false,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? KuwrirColors.success : (isActive ? KuwrirColors.primary : KuwrirColors.border);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot and line
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isCompleted ? color : (isActive ? color : Colors.transparent),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: isCompleted ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: isCompleted ? KuwrirColors.success : KuwrirColors.border,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: (isCompleted || isActive) ? FontWeight.w600 : FontWeight.normal,
                    color: (isCompleted || isActive) ? null : KuwrirColors.textHint,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: isActive ? KuwrirColors.primary : KuwrirColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
