import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/merchant_list_cubit.dart';
import '../cubits/order_tracking_cubit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            _HomeTab(),
            _OrdersTab(),
            _ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// --- Home Tab ---
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  void initState() {
    super.initState();
    context.read<MerchantListCubit>().loadMerchants();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: KuwrirColors.primary, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      'Kuta, Lombok',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/search'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: KuwrirColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KuwrirColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: KuwrirColors.textHint, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Cari restoran atau menu...',
                          style: TextStyle(color: KuwrirColors.textHint, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Restoran Terdekat',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),

        // Merchant list from API
        BlocBuilder<MerchantListCubit, MerchantListState>(
          builder: (context, state) {
            if (state is MerchantListLoading) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (state is MerchantListError) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(state.message, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.read<MerchantListCubit>().loadMerchants(),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (state is MerchantListLoaded) {
              if (state.merchants.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Belum ada restoran di area ini')),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == state.merchants.length) return const SizedBox(height: 24);
                      final m = state.merchants[index];
                      return _MerchantCard(
                        merchant: m,
                        onTap: () => Navigator.pushNamed(context, '/merchant',
                            arguments: {'id': m.id, 'name': m.name}),
                      );
                    },
                    childCount: state.merchants.length + 1,
                  ),
                ),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
        ),
      ],
    );
  }
}

// --- Merchant Card ---
class _MerchantCard extends StatelessWidget {
  final Merchant merchant;
  final VoidCallback onTap;

  const _MerchantCard({required this.merchant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: KuwrirColors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: merchant.logoUrl != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(merchant.logoUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.store, size: 48, color: KuwrirColors.primary)),
                    )
                  : Center(child: Icon(Icons.store, size: 48, color: KuwrirColors.primary)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(merchant.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      if (!merchant.isOpen)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Tutup', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(merchant.address,
                      style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: KuwrirColors.warning),
                      const SizedBox(width: 2),
                      Text('${merchant.rating.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(' (${merchant.totalReviews})',
                          style: TextStyle(fontSize: 11, color: KuwrirColors.textSecondary)),
                      if (merchant.distanceKm != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.location_on_outlined, size: 13, color: KuwrirColors.textSecondary),
                        Text('${merchant.distanceKm!.toStringAsFixed(1)} km',
                            style: TextStyle(fontSize: 11, color: KuwrirColors.textSecondary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Orders Tab ---
class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final orders = await api.getMyOrders();
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat riwayat pesanan';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            TextButton(onPressed: _loadOrders, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada pesanan', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, i) {
          final order = _orders[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.receipt_outlined),
              title: Text(order.orderNumber),
              subtitle: Text(order.merchantName ?? order.pickupAddress ?? ''),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(order.status),
                  Text('Rp ${order.total.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
              onTap: () => Navigator.pushNamed(context, '/tracking',
                  arguments: {'order_id': order.id}),
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'delivered':
      case 'returned':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'preparing':
      case 'ready':
      case 'picked_up':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status.replaceAll('_', ' '),
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// --- Profile Tab ---
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Profile', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () async {
              final api = context.read<ApiClient>();
              await api.clearTokens();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
