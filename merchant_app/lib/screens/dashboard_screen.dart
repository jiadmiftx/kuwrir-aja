import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/dashboard_cubit.dart';
import '../services/notification_service.dart';
import 'orders_screen.dart';
import 'notifications_screen.dart';
import 'package:hugeicons/hugeicons.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    context.read<DashboardCubit>().load();
    _refreshUnreadCount();
  }

  Future<void> _refreshUnreadCount() async {
    final count = await NotificationService.unreadCount();
    if (mounted) setState(() => _unreadNotifications = count);
  }

  Future<void> _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    _refreshUnreadCount();
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  void _openOrders(Set<String> statuses) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrdersScreen(initialStatusFilter: statuses)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: KuwrirColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody(context, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: KuwrirColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Pantau performa tokomu hari ini',
                    style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openNotifications,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: KuwrirColors.border),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: KuwrirColors.background,
                    child: HugeIcon(icon: HugeIcons.strokeRoundedNotification01, color: KuwrirColors.primary, size: 19),
                  ),
                  if (_unreadNotifications > 0)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: KuwrirColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: KuwrirColors.surface, width: 1.5),
                        ),
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
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
                    HugeIcon(icon: HugeIcons.strokeRoundedWallet01, color: KuwrirColors.primary),
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
                    HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: KuwrirColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('HARI INI',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: KuwrirColors.textHint)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _StatCard(
                icon: HugeIcons.strokeRoundedNewReleases,
                label: 'Order Baru',
                value: '${s.newOrders}',
                color: Colors.orange,
                onTap: () => _openOrders({'pending'}),
              ),
              _StatCard(
                icon: HugeIcons.strokeRoundedReload,
                label: 'Sedang Diproses',
                value: '${s.processingOrders}',
                color: Colors.blue,
                onTap: () => _openOrders({'confirmed', 'preparing'}),
              ),
              _StatCard(
                icon: HugeIcons.strokeRoundedDeliveryBox01,
                label: 'Kurir Dalam Perjalanan',
                value: '${s.courierEnRoute}',
                color: Colors.purple,
                onTap: () => _openOrders({'ready', 'picked_up'}),
              ),
              _StatCard(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                label: 'Order Selesai',
                value: '${s.completedOrders}',
                color: Colors.green,
                onTap: () => _openOrders({'delivered'}),
              ),
              _StatCard(
                icon: HugeIcons.strokeRoundedPayment01,
                label: 'Pendapatan Hari Ini',
                value: 'Rp ${_fmt(s.todayRevenue)}',
                color: KuwrirColors.primary,
              ),
              _StatCard(
                icon: HugeIcons.strokeRoundedStar,
                label: 'Rating Merchant',
                value: '${s.rating.toStringAsFixed(1)} (${s.totalReviews})',
                color: Colors.amber,
              ),
            ],
          ),
          if (s.topProducts.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('MENU TERLARIS',
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: KuwrirColors.textHint)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: KuwrirColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KuwrirColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < s.topProducts.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: KuwrirColors.border),
                    _TopProductRow(product: s.topProducts[i], rank: i + 1),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final List<List<dynamic>> icon;
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: HugeIcon(icon: icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(label,
                    style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  final TopProduct product;
  final int rank;
  const _TopProductRow({required this.product, required this.rank});

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.discountPrice != null && product.discountPrice! > 0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KuwrirColors.textHint)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: KuwrirColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: product.imageUrl != null
                ? Image.network(product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => HugeIcon(icon: HugeIcons.strokeRoundedRiceBowl01, color: KuwrirColors.primary, size: 20))
                : HugeIcon(icon: HugeIcons.strokeRoundedRiceBowl01, color: KuwrirColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (hasDiscount) ...[
                      Text('Rp ${_fmt(product.price)}',
                          style: TextStyle(
                              fontSize: 11.5, color: KuwrirColors.textHint, decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 5),
                    ],
                    Text('Rp ${_fmt(hasDiscount ? product.discountPrice! : product.price)}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: KuwrirColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          if (product.orderCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: KuwrirColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${product.orderCount}x terjual',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: KuwrirColors.success)),
            ),
        ],
      ),
    );
  }
}
