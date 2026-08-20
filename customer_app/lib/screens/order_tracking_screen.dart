import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'chat_screen.dart';
import 'order_modification_screen.dart';
import 'payment_webview_screen.dart';
import '../cubits/cart_cubit.dart';
import '../cubits/chat_cubit.dart' show ChatChannel;
import '../cubits/order_tracking_cubit.dart';
import '../widgets/review_sheet.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _payingNow = false;
  bool _cancelling = false;
  bool _reordering = false;

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

  /// Confirms before cancelling — the button used to fire the cancel
  /// request the instant it was tapped, no "are you sure", so a mis-tap
  /// permanently cancelled a real order with no recovery path.
  Future<void> _cancelOrder(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Batalkan pesanan ini?'),
        content: Text(
          order.paymentType != 'cash' && order.paymentStatus == 'paid'
              ? 'Pesanan #${order.orderNumber} akan dibatalkan dan dana akan dikembalikan ke wallet kamu.'
              : 'Pesanan #${order.orderNumber} akan dibatalkan. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KuwrirColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _cancelling = true);
    try {
      await context.read<ApiClient>().cancelOrder(order.id);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membatalkan pesanan')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _rateOrder(BuildContext context, Order order) async {
    final submitted = await showReviewSheet(
      context,
      orderId: order.id,
      hasDriver: order.driverId != null,
    );
    if (submitted && context.mounted) {
      context.read<OrderTrackingCubit>().refreshNow(order.id);
    }
  }

  /// Re-adds this order's items to the cart from the merchant's *current*
  /// live menu (not a blind replay of the old snapshot) — an item may have
  /// since gone unavailable, left its visibility window, or been removed
  /// entirely, so each is matched by product id against a fresh menu fetch
  /// and silently skipped (with a summary snackbar) rather than added stale.
  Future<void> _reorder(BuildContext context, Order order) async {
    final merchantId = order.merchantId;
    if (merchantId == null) return;

    final cart = context.read<CartCubit>();
    if (cart.state.merchantId != null &&
        cart.state.merchantId != merchantId &&
        cart.state.items.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Ganti keranjang?'),
          content: Text(
            'Keranjang kamu saat ini berisi pesanan dari toko lain. '
            'Memesan lagi dari ${order.merchantName ?? "toko ini"} akan '
            'mengganti isi keranjang.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ganti'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    setState(() => _reordering = true);
    try {
      final categories = await context.read<ApiClient>().getMerchantMenu(
        merchantId,
      );
      final liveProducts = {
        for (final cat in categories)
          for (final p in cat.products) p.id: p,
      };

      var skipped = 0;
      for (final item in order.items) {
        final product = item.productId != null
            ? liveProducts[item.productId]
            : null;
        if (product == null || !product.isAvailable || !product.isVisibleNow) {
          skipped++;
          continue;
        }
        cart.addItem(
          product,
          merchantId: merchantId,
          merchantName: order.merchantName,
          merchantImageUrl: order.merchantLogoUrl,
          quantity: item.quantity,
        );
      }

      if (!context.mounted) return;
      if (skipped > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$skipped item tidak lagi tersedia dan dilewati'),
          ),
        );
      }
      Navigator.pushNamed(context, '/cart');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal memuat menu toko')));
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
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
        final modificationRequest = state is OrderTracking
            ? state.modificationRequest
            : null;
        final isDelivered =
            state is OrderTrackingDelivered || order.status == 'delivered';

        return Scaffold(
          appBar: AppBar(
            title: Text('Pesanan ${order.orderNumber}'),
            actions: [
              if (order.canChatMerchant)
                IconButton(
                  icon: _AppBarChatIcon(
                    icon: HugeIcons.strokeRoundedStore01,
                    unreadCount: (c) => c.forOrder(order.id, 'merchant'),
                  ),
                  tooltip: 'Chat dengan Merchant',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        orderId: order.id,
                        orderNumber: order.orderNumber,
                        channel: ChatChannel.merchant,
                        counterpartLabel: order.merchantName ?? 'Merchant',
                        itemSummary: _itemSummary(order),
                        total: order.total,
                        statusLabel: _statusLabel(order.status),
                      ),
                    ),
                  ),
                ),
              if (order.canChatDriver)
                IconButton(
                  icon: _AppBarChatIcon(
                    icon: HugeIcons.strokeRoundedChat,
                    unreadCount: (c) => c.forOrder(order.id, 'driver'),
                  ),
                  tooltip: 'Chat dengan Driver',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        orderId: order.id,
                        orderNumber: order.orderNumber,
                        itemSummary: _itemSummary(order),
                        total: order.total,
                        statusLabel: _statusLabel(order.status),
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
                  // Status card — order progress headline. Payment clarity
                  // lives in its own badge below, kept visually distinct so
                  // "is this paid?" never has to be inferred from the order
                  // status text (see _PaymentBadge).
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: KuwrirColors.surface,
                      borderRadius: BorderRadius.circular(20),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                (order.status == 'cancelled'
                                        ? KuwrirColors.error
                                        : isDelivered
                                        ? KuwrirColors.success
                                        : KuwrirColors.primary)
                                    .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(
                            icon: order.status == 'cancelled'
                                ? HugeIcons.strokeRoundedCancelCircle
                                : isDelivered
                                ? HugeIcons.strokeRoundedCheckmarkCircle02
                                : HugeIcons.strokeRoundedDeliveryBox01,
                            size: 22,
                            color: order.status == 'cancelled'
                                ? KuwrirColors.error
                                : isDelivered
                                ? KuwrirColors.success
                                : KuwrirColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusLabel(order.status),
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (order.merchantName != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  order.merchantName!,
                                  style: TextStyle(
                                    color: KuwrirColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (order.status == 'cancelled' &&
                                  order.cancellationReason != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  order.cancellationReason!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: KuwrirColors.textHint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isDelivered && order.status != 'cancelled')
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: KuwrirColors.textHint,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment clarity — the one thing customers ask about
                  // most, given its own badge instead of being inferred
                  // from the order status text.
                  _PaymentBadge(
                    order: order,
                    paying: _payingNow,
                    onPayNow: () => _payNow(context, order),
                    fmtDeadline: _fmtDeadline,
                  ),
                  const SizedBox(height: 24),

                  if (modificationRequest != null) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderModificationScreen(
                              orderId: order.id,
                              modificationRequest: modificationRequest,
                            ),
                          ),
                        );
                        if (context.mounted) {
                          context.read<OrderTrackingCubit>().refreshNow(
                            order.id,
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: KuwrirColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: KuwrirColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedAlert02,
                              color: KuwrirColors.warning,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Ada item yang tidak tersedia. Pilih pengganti atau batalkan pesanan.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Horizontal progress tracker — mirrors the condensed
                  // Gojek/Grab step pattern (order placed → prepared →
                  // on the way → delivered) rather than the app's full
                  // 6-status state machine, which is one status finer than
                  // a customer needs to see at a glance.
                  if (order.status != 'cancelled') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: KuwrirColors.surface,
                        borderRadius: BorderRadius.circular(20),
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
                      child: _HorizontalTracker(status: order.status),
                    ),
                    const SizedBox(height: 24),
                  ],

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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel button (only if still cancellable)
                  if (order.isCancellable)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: _cancelling
                            ? null
                            : () => _cancelOrder(context, order),
                        child: _cancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              )
                            : const Text('Batalkan Pesanan'),
                      ),
                    ),

                  if (isDelivered) ...[
                    if (!order.hasReview)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _rateOrder(context, order),
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedStar,
                          ),
                          label: const Text('Beri Rating'),
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _reordering
                            ? null
                            : () => _reorder(context, order),
                        icon: _reordering
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const HugeIcon(
                                icon: HugeIcons.strokeRoundedRefresh01,
                              ),
                        label: const Text('Pesan Lagi'),
                      ),
                    ),
                  ],
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

  String _itemSummary(Order order) {
    if (order.items.isEmpty) return order.merchantName ?? '-';
    final first = order.items.first;
    final extra = order.items.length - 1;
    final label = '${first.quantity}x ${first.itemName}';
    return extra > 0 ? '$label +$extra lainnya' : label;
  }

  // Deliberately payment-agnostic: Order.status stays 'pending' while an
  // online order is unpaid (the merchant never even sees it — see
  // ActiveOrders' payment_status filter backend-side), so this can't say
  // "waiting on the merchant" without risking a false claim. Payment state
  // is its own, separately-badged concern (see _PaymentBadge) rather than
  // folded into this label.
  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pesanan Dibuat';
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
}

/// Payment status, badged separately from order progress so "is this paid?"
/// is never something a customer has to infer from a status word. Three
/// distinct states get three distinct treatments: cash is informational
/// (nothing blocks progress), paid is a quiet confirmation, unpaid is the
/// one that needs an actual call to action.
class _PaymentBadge extends StatelessWidget {
  final Order order;
  final bool paying;
  final VoidCallback onPayNow;
  final String Function(DateTime) fmtDeadline;

  const _PaymentBadge({
    required this.order,
    required this.paying,
    required this.onPayNow,
    required this.fmtDeadline,
  });

  @override
  Widget build(BuildContext context) {
    final isCash = order.paymentType == 'cash';
    final isPaid = order.paymentStatus == 'paid';

    final Color color;
    final List<List<dynamic>> icon;
    final String title;
    String? subtitle;
    if (isCash) {
      color = KuwrirColors.primary;
      icon = HugeIcons.strokeRoundedCash01;
      title = 'Bayar Tunai ke Driver';
      subtitle = 'Siapkan uang pas saat pesanan tiba';
    } else if (isPaid) {
      color = KuwrirColors.success;
      icon = HugeIcons.strokeRoundedCheckmarkCircle02;
      title = 'Sudah Dibayar';
    } else {
      color = KuwrirColors.warning;
      icon = HugeIcons.strokeRoundedQrCode01;
      title = 'Menunggu Pembayaran';
      subtitle = order.paymentExpiredAt != null
          ? 'Bayar sebelum ${fmtDeadline(order.paymentExpiredAt!)}'
          : null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: KuwrirColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!isCash && !isPaid) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: paying ? null : onPayNow,
                style: FilledButton.styleFrom(backgroundColor: color),
                icon: paying
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const HugeIcon(
                        icon: HugeIcons.strokeRoundedPayment01,
                        size: 17,
                      ),
                label: const Text('Bayar Sekarang'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _StepState { pending, active, done }

/// Condensed 4-step horizontal tracker (Dipesan → Diproses → Diantar →
/// Selesai), mirroring the Gojek/Grab order-tracking pattern rather than
/// the backend's full 6-status state machine — a customer glancing at this
/// mid-delivery doesn't need to distinguish "ready" from "picked_up".
class _HorizontalTracker extends StatelessWidget {
  final String status;
  const _HorizontalTracker({required this.status});

  static const _labels = ['Dipesan', 'Diproses', 'Diantar', 'Selesai'];
  static const _icons = [
    HugeIcons.strokeRoundedReceiptText,
    HugeIcons.strokeRoundedChefHat,
    HugeIcons.strokeRoundedMotorbike01,
    HugeIcons.strokeRoundedPackageDelivered,
  ];

  int get _currentIndex {
    switch (status) {
      case 'confirmed':
      case 'preparing':
        return 1;
      case 'ready':
      case 'picked_up':
        return 2;
      case 'delivered':
        return 3;
      case 'pending':
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              _StepDot(
                icon: _icons[i],
                state: i < current
                    ? _StepState.done
                    : i == current
                    ? _StepState.active
                    : _StepState.pending,
              ),
              if (i != _labels.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < current
                        ? KuwrirColors.primary
                        : KuwrirColors.border,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              SizedBox(
                width: 40,
                child: Text(
                  _labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == current
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i == current
                        ? KuwrirColors.primary
                        : i < current
                        ? KuwrirColors.textSecondary
                        : KuwrirColors.textHint,
                  ),
                ),
              ),
              if (i != _labels.length - 1) const Expanded(child: SizedBox()),
            ],
          ],
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final List<List<dynamic>> icon;
  final _StepState state;
  const _StepDot({required this.icon, required this.state});

  @override
  Widget build(BuildContext context) {
    final filled = state != _StepState.pending;
    final isActive = state == _StepState.active;
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Container(
          width: isActive ? 34 : 30,
          height: isActive ? 34 : 30,
          decoration: BoxDecoration(
            color: filled ? KuwrirColors.primary : KuwrirColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: filled ? KuwrirColors.primary : KuwrirColors.border,
              width: isActive ? 2.5 : 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: KuwrirColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: HugeIcon(
            icon: state == _StepState.done
                ? HugeIcons.strokeRoundedTick01
                : icon,
            size: 15,
            color: filled ? Colors.white : KuwrirColors.textHint,
          ),
        ),
      ),
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

/// AppBar chat icon with an unread-count badge — [unreadCount] picks the
/// relevant channel count for this order out of [ChatUnreadCount].
class _AppBarChatIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  final int Function(ChatUnreadCount) unreadCount;
  const _AppBarChatIcon({required this.icon, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ChatUnreadService>();
    return ValueListenableBuilder<ChatUnreadCount>(
      valueListenable: service.count,
      builder: (context, count, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          HugeIcon(icon: icon),
          Positioned(
            right: -4,
            top: -4,
            child: UnreadBadge(count: unreadCount(count)),
          ),
        ],
      ),
    );
  }
}
