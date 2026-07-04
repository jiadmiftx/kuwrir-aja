import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/dashboard_cubit.dart';
import 'orders_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardCubit>().load();
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  void _openOrders(Set<String> statuses) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrdersScreen(initialStatusFilter: statuses)),
    );
  }

  void _showNotifications(DashboardLoaded state) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aktivitas Hari Ini', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _NotifRow(icon: Icons.fiber_new, label: '${state.newOrders} pesanan baru masuk', color: Colors.orange),
              _NotifRow(icon: Icons.sync, label: '${state.processingOrders} pesanan sedang diproses', color: Colors.blue),
              _NotifRow(icon: Icons.delivery_dining, label: '${state.courierEnRoute} kurir dalam perjalanan', color: Colors.purple),
              _NotifRow(icon: Icons.check_circle, label: '${state.completedOrders} pesanan selesai', color: Colors.green),
              if (state.cancelledOrders > 0)
                _NotifRow(icon: Icons.cancel, label: '${state.cancelledOrders} pesanan dibatalkan', color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: KuwrirColors.background,
          appBar: AppBar(
            title: const Text('Dashboard'),
            backgroundColor: KuwrirColors.background,
            actions: [
              if (state is DashboardLoaded)
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _showNotifications(state),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<DashboardCubit>().load(),
              ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, DashboardState state) {
    if (state is DashboardLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is DashboardError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, style: TextStyle(color: KuwrirColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<DashboardCubit>().load(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    final s = state as DashboardLoaded;
    return RefreshIndicator(
      onRefresh: () => context.read<DashboardCubit>().load(),
      color: KuwrirColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Material(
            color: KuwrirColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pushNamed(context, '/wallet'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, color: KuwrirColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saldo Keuangan', style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
                          Text('Rp ${_fmt(s.walletBalance)}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: KuwrirColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
          _StatCard(
            icon: Icons.fiber_new_outlined,
            label: 'Order Baru',
            value: '${s.newOrders}',
            color: Colors.orange,
            onTap: () => _openOrders({'pending'}),
          ),
          _StatCard(
            icon: Icons.sync,
            label: 'Sedang Diproses',
            value: '${s.processingOrders}',
            color: Colors.blue,
            onTap: () => _openOrders({'confirmed', 'preparing'}),
          ),
          _StatCard(
            icon: Icons.delivery_dining_outlined,
            label: 'Kurir Dalam Perjalanan',
            value: '${s.courierEnRoute}',
            color: Colors.purple,
            onTap: () => _openOrders({'ready', 'picked_up'}),
          ),
          _StatCard(
            icon: Icons.check_circle_outline,
            label: 'Order Selesai',
            value: '${s.completedOrders}',
            color: Colors.green,
            onTap: () => _openOrders({'delivered'}),
          ),
          _StatCard(
            icon: Icons.payments_outlined,
            label: 'Pendapatan Hari Ini',
            value: 'Rp ${_fmt(s.todayRevenue)}',
            color: KuwrirColors.primary,
          ),
              _StatCard(
                icon: Icons.star_outline,
                label: 'Rating Merchant',
                value: '${s.rating.toStringAsFixed(1)} (${s.totalReviews})',
                color: Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _NotifRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
