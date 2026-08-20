import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/store_orders_cubit.dart';
import '../widgets/reason_dialog.dart';
import 'chat_screen.dart';
import 'package:hugeicons/hugeicons.dart';

/// Which of the tabs below an order's status belongs under. "Pesanan Masuk"
/// is a live working list, not full order history — ActiveOrders on the
/// backend only ever returns pre-pickup orders plus cancellations from the
/// last 3 days, so "Semua" means "everything still active" and cancelled
/// orders get their own tab rather than cluttering it.
enum _OrderTab { all, newOrder, processing, ready, cancelled }

const _orderTabLabels = {
  _OrderTab.all: 'Semua',
  _OrderTab.newOrder: 'Baru',
  _OrderTab.processing: 'Diproses',
  _OrderTab.ready: 'Siap Dikirim',
  _OrderTab.cancelled: 'Dibatalkan',
};

bool _orderMatchesTab(String status, _OrderTab tab) {
  switch (tab) {
    case _OrderTab.all:
      return status != 'cancelled';
    case _OrderTab.newOrder:
      return status == 'pending';
    case _OrderTab.processing:
      return status == 'confirmed' || status == 'preparing';
    case _OrderTab.ready:
      return status == 'ready' || status == 'picked_up';
    case _OrderTab.cancelled:
      return status == 'cancelled';
  }
}

/// Dashboard's stat-card deep links (see dashboard_screen.dart's
/// `_openOrders`) used to hard-filter this screen to one status forever —
/// now they just pick which tab opens first, so the merchant can still
/// switch to see everything else without navigating back and re-entering.
_OrderTab _initialTabFor(Set<String>? filter) {
  if (filter == null) return _OrderTab.all;
  if (filter.contains('pending')) return _OrderTab.newOrder;
  if (filter.contains('confirmed') || filter.contains('preparing')) {
    return _OrderTab.processing;
  }
  if (filter.contains('ready') || filter.contains('picked_up')) {
    return _OrderTab.ready;
  }
  return _OrderTab.all;
}

List<Map<String, dynamic>> _newestFirst(List<Map<String, dynamic>> orders) {
  final sorted = List<Map<String, dynamic>>.from(orders);
  sorted.sort((a, b) {
    final ta =
        DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(0);
    final tb =
        DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(0);
    return tb.compareTo(ta);
  });
  return sorted;
}

String _chatItemSummary(List<dynamic> items) {
  if (items.isEmpty) return '-';
  final first = items.first as Map<String, dynamic>;
  final extra = items.length - 1;
  final label = '${first['quantity']}x ${first['item_name']}';
  return extra > 0 ? '$label +$extra lainnya' : label;
}

class OrdersScreen extends StatefulWidget {
  /// Which tab opens first (used by Dashboard's stat-card deep links) —
  /// otherwise the screen opens on "Semua".
  final Set<String>? initialStatusFilter;

  const OrdersScreen({super.key, this.initialStatusFilter});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: _OrderTab.values.length,
    vsync: this,
    initialIndex: _OrderTab.values.indexOf(
      _initialTabFor(widget.initialStatusFilter),
    ),
  );

  @override
  void initState() {
    super.initState();
    context.read<StoreOrdersCubit>().startPolling();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreOrdersCubit, StoreOrdersState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: KuwrirColors.background,
          appBar: AppBar(
            title: const Text('Pesanan Masuk'),
            backgroundColor: KuwrirColors.background,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: KuwrirColors.primary,
              unselectedLabelColor: KuwrirColors.textSecondary,
              indicatorColor: KuwrirColors.primary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
              ),
              tabs: _OrderTab.values
                  .map((t) => Tab(text: _orderTabLabels[t]))
                  .toList(),
            ),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, StoreOrdersState state) {
    if (state is StoreOrdersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is StoreOrdersError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.message,
              style: TextStyle(color: KuwrirColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<StoreOrdersCubit>().load(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (state is StoreOrdersLoaded) {
      final active = _newestFirst(
        state.orders,
      ).where((o) => o['status'] != 'delivered').toList();

      return TabBarView(
        controller: _tabController,
        children: _OrderTab.values
            .map(
              (tab) => _OrdersTabList(
                orders: active
                    .where(
                      (o) => _orderMatchesTab(
                        o['status'] as String? ?? 'pending',
                        tab,
                      ),
                    )
                    .toList(),
                tab: tab,
                onRefresh: () => context.read<StoreOrdersCubit>().load(),
              ),
            )
            .toList(),
      );
    }

    return const SizedBox.shrink();
  }
}

class _OrdersTabList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final _OrderTab tab;
  final Future<void> Function() onRefresh;

  const _OrdersTabList({
    required this.orders,
    required this.tab,
    required this.onRefresh,
  });

  static const _emptyCopy = {
    _OrderTab.all: (
      'Tidak ada pesanan aktif',
      'Pesanan baru akan muncul di sini otomatis',
    ),
    _OrderTab.newOrder: (
      'Belum ada pesanan baru',
      'Pesanan yang baru masuk akan muncul di sini',
    ),
    _OrderTab.processing: (
      'Tidak ada pesanan diproses',
      'Pesanan yang sedang disiapkan muncul di sini',
    ),
    _OrderTab.ready: (
      'Tidak ada pesanan siap dikirim',
      'Pesanan yang menunggu driver muncul di sini',
    ),
    _OrderTab.cancelled: (
      'Belum ada pesanan dibatalkan',
      'Pesanan yang dibatalkan 3 hari terakhir muncul di sini',
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      final (title, subtitle) = _emptyCopy[tab]!;
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: KuwrirColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: KuwrirColors.success.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                        size: 36,
                        color: KuwrirColors.success,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: KuwrirColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: KuwrirColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: KuwrirColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: orders.length,
        itemBuilder: (context, i) => _OrderCard(order: orders[i]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'pending';
    final items = order['items'] as List<dynamic>? ?? [];
    final customer = order['customer'] as Map<String, dynamic>?;
    final customerName = customer?['name'] as String? ?? 'Customer';
    final orderNumber = order['order_number'] as String? ?? '-';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    // What the merchant actually receives — base item price only, already
    // net of platform markup/delivery/tax. `total` (used for chat context
    // above) is the customer-facing full amount and would overstate this
    // card's number, which is the one merchants check to reconcile payout.
    final merchantPayout =
        (order['merchant_payout'] as num?)?.toDouble() ?? total;
    final deliveryType = order['delivery_type'] as String? ?? 'platform';
    final lastModification =
        order['last_modification'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KuwrirColors.border),
        boxShadow: [
          BoxShadow(
            color: KuwrirColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KuwrirColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedInvoice01,
                    color: KuwrirColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    orderNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (status == 'confirmed' ||
                    status == 'preparing' ||
                    status == 'ready')
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            orderId: order['id'] as String,
                            orderNumber: orderNumber,
                            customerName: customerName,
                            itemSummary: _chatItemSummary(items),
                            total: total,
                            statusLabel: status.toUpperCase(),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: _ChatIconWithBadge(
                          orderId: order['id'] as String,
                        ),
                      ),
                    ),
                  ),
                _StatusBadge(status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedUserCircle02,
                  size: 14,
                  color: KuwrirColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  customerName,
                  style: TextStyle(
                    fontSize: 13,
                    color: KuwrirColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                HugeIcon(
                  icon: deliveryType == 'self'
                      ? HugeIcons.strokeRoundedStore01
                      : HugeIcons.strokeRoundedDeliveryBox01,
                  size: 14,
                  color: KuwrirColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  deliveryType == 'self' ? 'Antar sendiri' : 'Platform',
                  style: TextStyle(
                    fontSize: 12,
                    color: KuwrirColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (status == 'cancelled' &&
                (order['cancellation_reason'] as String?)?.isNotEmpty ==
                    true) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 14,
                    color: KuwrirColors.error,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order['cancellation_reason'] as String,
                      style: TextStyle(fontSize: 12, color: KuwrirColors.error),
                    ),
                  ),
                ],
              ),
            ],
            if (lastModification != null &&
                lastModification['status'] == 'replaced') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: KuwrirColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedReload,
                      size: 14,
                      color: KuwrirColors.info,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Customer sudah pilih item pengganti'
                        '${_resolvedAtLabel(lastModification['resolved_at'] as String?)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: KuwrirColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Divider(height: 1, color: KuwrirColors.border),
            const SizedBox(height: 10),

            // Items
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${item['quantity']}x ${item['item_name']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: KuwrirColors.textPrimary,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // Total + accept/progress action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pendapatan',
                      style: TextStyle(
                        fontSize: 12,
                        color: KuwrirColors.textSecondary,
                      ),
                    ),
                    Text(
                      'IDR ${_fmt(merchantPayout)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: KuwrirColors.primary,
                      ),
                    ),
                  ],
                ),
                _ActionButton(orderId: order['id'] as String, status: status),
              ],
            ),

            // Correcting the order (an item ran out) is the expected first
            // move once accepted — cancelling the whole order is the
            // fallback for when the order genuinely can't be fulfilled at
            // all, not the default reach when just one item is unavailable.
            if (status == 'confirmed' || status == 'preparing') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _flagAnyItemUnavailable(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KuwrirColors.warning,
                    side: BorderSide(
                      color: KuwrirColors.warning.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 16,
                    color: KuwrirColors.warning,
                  ),
                  label: const Text(
                    'Ada Item Tidak Tersedia?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: () => _cancelOrder(context),
                  child: Text(
                    'Pesanan tidak bisa diproses sama sekali? Batalkan',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: KuwrirColors.textHint,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: KuwrirColors.textHint,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  String _resolvedAtLabel(String? resolvedAt) {
    final t = DateTime.tryParse(resolvedAt ?? '');
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return ' • baru saja';
    if (diff.inMinutes < 60) return ' • ${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return ' • ${diff.inHours} jam lalu';
    return ' • ${diff.inDays} hari lalu';
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final result = await showReasonDialog(
      context,
      title: 'Batalkan seluruh pesanan?',
      confirmLabel: 'Ya, Batalkan Semua',
    );
    if (result == null) return;
    final cubit = context.read<StoreOrdersCubit>();
    try {
      await cubit.cancelAccepted(
        order['id'] as String,
        reason: _combineReason(result),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  /// Entry point for the "Ada Item Tidak Tersedia?" button — single-item
  /// orders skip straight to the reason dialog, multi-item orders need to
  /// know which one is out first.
  Future<void> _flagAnyItemUnavailable(BuildContext context) async {
    final items = (order['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (items.isEmpty) return;
    if (items.length == 1) {
      await _flagItemUnavailable(context, items.first);
      return;
    }
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Item mana yang tidak tersedia?'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item['quantity']}x ${item['item_name']}'),
                  trailing: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                  ),
                  onTap: () => Navigator.pop(ctx, item),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    await _flagItemUnavailable(context, picked);
  }

  Future<void> _flagItemUnavailable(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final itemName = item['item_name'] as String? ?? 'Item ini';
    final result = await showReasonDialog(
      context,
      title: '$itemName tidak tersedia?',
      confirmLabel: 'Minta Customer Ganti',
      confirmColor: KuwrirColors.warning,
    );
    if (result == null) return;
    final cubit = context.read<StoreOrdersCubit>();
    try {
      await cubit.requestItemChange(
        order['id'] as String,
        itemId: item['id'] as String,
        reasonCategory: result.category,
        reason: result.reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer diminta memilih pengganti')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _combineReason(ReasonResult result) {
    final label = reasonCategoryLabel(result.category);
    if (result.reason.isEmpty) return label;
    return '$label: ${result.reason}';
  }
}

class _ActionButton extends StatefulWidget {
  final String orderId;
  final String status;

  const _ActionButton({required this.orderId, required this.status});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _loading = false;

  Future<void> _act(BuildContext context) async {
    setState(() => _loading = true);
    final cubit = context.read<StoreOrdersCubit>();
    try {
      switch (widget.status) {
        case 'pending':
          await cubit.accept(widget.orderId);
          break;
        case 'confirmed':
          await cubit.markPreparing(widget.orderId);
          break;
        case 'preparing':
          await cubit.markReady(widget.orderId);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (widget.status) {
      case 'pending':
        label = 'Terima Pesanan';
        color = KuwrirColors.success;
        break;
      case 'confirmed':
        label = 'Mulai Masak';
        color = KuwrirColors.warning;
        break;
      case 'preparing':
        label = 'Siap Dikirim';
        color = KuwrirColors.primary;
        break;
      default:
        return const SizedBox.shrink();
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _loading ? null : () => _act(context),
      child: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'pending':
        color = KuwrirColors.warning;
        break;
      case 'confirmed':
        color = KuwrirColors.info;
        break;
      case 'preparing':
        color = KuwrirColors.accent;
        break;
      case 'ready':
        color = KuwrirColors.success;
        break;
      case 'cancelled':
        color = KuwrirColors.error;
        break;
      default:
        color = KuwrirColors.textHint;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Chat icon with an unread-count badge for one order's merchant-channel
/// thread — used on the order list's chat action.
class _ChatIconWithBadge extends StatelessWidget {
  final String orderId;
  const _ChatIconWithBadge({required this.orderId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ChatUnreadService>();
    return ValueListenableBuilder<ChatUnreadCount>(
      valueListenable: service.count,
      builder: (context, count, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedChat,
            size: 18,
            color: KuwrirColors.textSecondary,
          ),
          Positioned(
            right: -4,
            top: -4,
            child: UnreadBadge(count: count.forOrder(orderId, 'merchant')),
          ),
        ],
      ),
    );
  }
}
