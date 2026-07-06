import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/store_orders_cubit.dart';

class OrdersScreen extends StatefulWidget {
  /// When set, only orders whose status is in this set are shown (used by
  /// Dashboard's stat-card deep links) — otherwise the default "everything
  /// except delivered/cancelled" view.
  final Set<String>? initialStatusFilter;

  const OrdersScreen({super.key, this.initialStatusFilter});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<StoreOrdersCubit>().startPolling();
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
            Text(state.message, style: TextStyle(color: KuwrirColors.textSecondary)),
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
      final filter = widget.initialStatusFilter;
      final active = state.orders
          .where((o) => filter != null
              ? filter.contains(o['status'])
              : !['delivered', 'cancelled'].contains(o['status']))
          .toList();

      if (active.isEmpty) {
        return Center(
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
                  child: Icon(Icons.check_circle_outline, size: 36, color: KuwrirColors.success),
                ),
                const SizedBox(height: 20),
                const Text('Tidak ada pesanan aktif',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KuwrirColors.textPrimary)),
                const SizedBox(height: 6),
                Text('Pesanan baru akan muncul di sini otomatis',
                    style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => context.read<StoreOrdersCubit>().load(),
        color: KuwrirColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: active.length,
          itemBuilder: (context, i) {
            final order = active[i];
            return _OrderCard(order: order);
          },
        ),
      );
    }

    return const SizedBox.shrink();
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
    final deliveryType = order['delivery_type'] as String? ?? 'platform';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                _StatusBadge(status),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: KuwrirColors.textSecondary),
                const SizedBox(width: 4),
                Text(customerName,
                    style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
                const SizedBox(width: 12),
                Icon(
                  deliveryType == 'self' ? Icons.store_outlined : Icons.delivery_dining,
                  size: 14,
                  color: KuwrirColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  deliveryType == 'self' ? 'Antar sendiri' : 'Platform',
                  style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Items
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${item['quantity']}x ${item['item_name']}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),

            const SizedBox(height: 10),

            // Total + action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
                    Text(
                      'IDR ${_fmt(total)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                _ActionButton(orderId: order['id'] as String, status: status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
        color = Colors.orange;
        break;
      case 'confirmed':
        color = Colors.blue;
        break;
      case 'preparing':
        color = Colors.purple;
        break;
      case 'ready':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(),
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
