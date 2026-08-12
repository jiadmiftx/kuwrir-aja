import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'chat_screen.dart';
import 'payment_webview_screen.dart';
import '../cubits/order_tracking_cubit.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _payingNow = false;

  @override
  void initState() {
    super.initState();
    context.read<OrderTrackingCubit>().startTracking(widget.orderId);
  }

  /// Reopens the existing payment link if one is still valid — minting a
  /// new one is a real Duitku transaction (new VA) every time, so this only
  /// calls createOrderPayment when there's genuinely nothing usable yet.
  Future<void> _payNow(BuildContext context, Order order) async {
    final existingUrl = order.paymentUrl;
    final expiredAt = order.paymentExpiredAt;
    if (existingUrl != null &&
        expiredAt != null &&
        expiredAt.isAfter(DateTime.now())) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PaymentWebViewScreen(paymentUrl: existingUrl, orderId: order.id),
        ),
      );
      return;
    }

    setState(() => _payingNow = true);
    try {
      final resp = await context.read<ApiClient>().createOrderPayment(
        orderId: order.id,
        paymentMethod: order.paymentType,
      );
      final url = resp['payment_url'] as String?;
      if (url != null && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PaymentWebViewScreen(paymentUrl: url, orderId: order.id),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka halaman pembayaran')),
        );
      }
    } finally {
      if (mounted) setState(() => _payingNow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderTrackingCubit, OrderTrackingState>(
      builder: (context, state) {
        if (state is OrderTrackingLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tracking Pesanan')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is OrderTrackingError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tracking Pesanan')),
            body: Center(
              child: Text(
                state.message,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        final order = state is OrderTracking
            ? state.order
            : (state as OrderTrackingDelivered).order;
        final isDelivered =
            state is OrderTrackingDelivered || order.status == 'delivered';
        // Order.status stays 'pending' while unpaid (the merchant never even
        // sees it — see ActiveOrders' payment_status filter backend-side),
        // so _statusLabel('pending') would misleadingly say "waiting on the
        // merchant" when the real blocker is payment.
        final isAwaitingPayment =
            order.paymentType != 'cash' && order.paymentStatus != 'paid';

        // Show chat button only when driver is assigned (order in transit)
        final canChat = [
          'picked_up',
          'confirmed',
          'preparing',
          'ready',
        ].contains(order.status);

        return Scaffold(
          appBar: AppBar(
            title: Text('Pesanan ${order.orderNumber}'),
            actions: [
              if (canChat)
                IconButton(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedChat),
                  tooltip: 'Chat dengan Driver',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        orderId: order.id,
                        orderNumber: order.orderNumber,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () =>
                context.read<OrderTrackingCubit>().refreshNow(widget.orderId),
            color: KuwrirColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: KuwrirColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: KuwrirColors.textPrimary.withValues(
                            alpha: 0.05,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                (isAwaitingPayment
                                        ? KuwrirColors.warning
                                        : isDelivered
                                        ? KuwrirColors.success
                                        : KuwrirColors.primary)
                                    .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(
                            icon: isAwaitingPayment
                                ? HugeIcons.strokeRoundedHourglass
                                : isDelivered
                                ? HugeIcons.strokeRoundedCheckmarkCircle02
                                : HugeIcons.strokeRoundedDeliveryBox01,
                            size: 30,
                            color: isAwaitingPayment
                                ? KuwrirColors.warning
                                : isDelivered
                                ? KuwrirColors.success
                                : KuwrirColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isAwaitingPayment
                              ? 'Menunggu Pembayaran'
                              : _statusLabel(order.status),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (order.merchantName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            order.merchantName!,
                            style: TextStyle(
                              color: KuwrirColors.textSecondary,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                        if (isAwaitingPayment &&
                            order.paymentExpiredAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Bayar sebelum ${_fmtDeadline(order.paymentExpiredAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: KuwrirColors.textHint,
                            ),
                          ),
                        ],
                        if (!isDelivered) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: KuwrirColors.warning.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: KuwrirColors.warning,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Memperbarui setiap 12 detik...',
                                  style: const TextStyle(
                                    color: KuwrirColors.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Timeline
                  const Text(
                    'Status Pesanan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _TimelineStep(
                    title: 'Pesanan Dibuat',
                    isCompleted: true,
                    isFirst: true,
                  ),
                  _TimelineStep(
                    title: 'Dikonfirmasi Merchant',
                    isCompleted: _isCompleted(order.status, 'confirmed'),
                    isActive: order.status == 'confirmed',
                  ),
                  _TimelineStep(
                    title: 'Sedang Diproses',
                    isCompleted: _isCompleted(order.status, 'preparing'),
                    isActive: order.status == 'preparing',
                  ),
                  _TimelineStep(
                    title: 'Siap Dikirim',
                    isCompleted: _isCompleted(order.status, 'ready'),
                    isActive: order.status == 'ready',
                  ),
                  _TimelineStep(
                    title: 'Driver Menjemput',
                    isCompleted: _isCompleted(order.status, 'picked_up'),
                    isActive: order.status == 'picked_up',
                  ),
                  _TimelineStep(
                    title: 'Terkirim',
                    isCompleted: isDelivered,
                    isActive: isDelivered,
                    isLast: true,
                  ),

                  const SizedBox(height: 24),

                  // Delivery info
                  if (order.dropoffAddress != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Pengiriman',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: HugeIcons.strokeRoundedLocation01,
                              label: 'Alamat',
                              value: order.dropoffAddress!,
                            ),
                            if (order.receiverName != null)
                              _InfoRow(
                                icon: HugeIcons.strokeRoundedUser,
                                label: 'Penerima',
                                value: order.receiverName!,
                              ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Payment summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rincian Pembayaran',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _PriceRow(
                            label: 'Subtotal menu',
                            amount: order.subtotal,
                          ),
                          if (order.taxAmount > 0)
                            _PriceRow(
                              label: 'Pajak (PPN)',
                              amount: order.taxAmount,
                            ),
                          _PriceRow(label: 'Ongkir', amount: order.deliveryFee),
                          if (order.appServiceFee > 0)
                            _PriceRow(
                              label: 'Biaya layanan',
                              amount: order.appServiceFee,
                            ),
                          const Divider(height: 16),
                          _PriceRow(
                            label: 'Total',
                            amount: order.total,
                            isBold: true,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              HugeIcon(
                                icon: order.paymentType == 'cash'
                                    ? HugeIcons.strokeRoundedPayment01
                                    : HugeIcons.strokeRoundedQrCode01,
                                size: 16,
                                color: KuwrirColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                order.paymentType == 'cash'
                                    ? 'Bayar tunai ke driver'
                                    : 'Bayar online (${order.paymentStatus})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: KuwrirColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pay Now button (only while a non-cash order is unpaid)
                  if (isAwaitingPayment)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _payingNow
                            ? null
                            : () => _payNow(context, order),
                        icon: _payingNow
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const HugeIcon(
                                icon: HugeIcons.strokeRoundedPayment01,
                              ),
                        label: const Text('Bayar Sekarang'),
                      ),
                    ),
                  if (isAwaitingPayment) const SizedBox(height: 16),

                  // Cancel button (only if still cancellable)
                  if (order.isCancellable)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          final api = context.read<ApiClient>();
                          try {
                            await api.cancelOrder(order.id);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gagal membatalkan pesanan'),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Batalkan Pesanan'),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmtDeadline(DateTime utc) {
    final local = utc.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu konfirmasi merchant';
      case 'confirmed':
        return 'Pesanan dikonfirmasi';
      case 'preparing':
        return 'Sedang disiapkan';
      case 'ready':
        return 'Menunggu driver';
      case 'picked_up':
        return 'Driver dalam perjalanan';
      case 'delivered':
        return 'Pesanan diterima!';
      case 'cancelled':
        return 'Pesanan dibatalkan';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  bool _isCompleted(String current, String target) {
    const order = [
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'picked_up',
      'delivered',
    ];
    final ci = order.indexOf(current);
    final ti = order.indexOf(target);
    return ci > ti;
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final bool isActive;
  final bool isFirst;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    this.isCompleted = false,
    this.isActive = false,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted || isActive
                    ? KuwrirColors.primary
                    : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: isCompleted
                    ? HugeIcons.strokeRoundedTick01
                    : HugeIcons.strokeRoundedCircle,
                size: 14,
                color: Colors.white,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isCompleted ? KuwrirColors.primary : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? KuwrirColors.primary
                    : isCompleted
                    ? Colors.black87
                    : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 16, color: KuwrirColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: KuwrirColors.textSecondary,
                  ),
                ),
                Text(value, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;

  const _PriceRow({
    required this.label,
    required this.amount,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: isBold ? 15 : 13,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: isBold ? null : KuwrirColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            'IDR ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
            style: style.copyWith(color: isBold ? KuwrirColors.primary : null),
          ),
        ],
      ),
    );
  }
}
