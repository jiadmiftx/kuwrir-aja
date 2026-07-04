import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/merchant_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'screens/search_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/support_chat_screen.dart';
import 'screens/profile_screen.dart';
import 'cubits/home_cubit.dart';
import 'cubits/merchant_detail_cubit.dart';
import 'cubits/cart_cubit.dart';
import 'cubits/order_cubit.dart';
import 'cubits/order_tracking_cubit.dart';
import 'cubits/location_cubit.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const KuwrirCustomerApp());
  // Init notifications after runApp so Flutter renders first frame before
  // requesting Android 13+ POST_NOTIFICATIONS permission
  await NotificationService.init();
  NotificationService.setupForegroundHandler();
}

class KuwrirCustomerApp extends StatelessWidget {
  const KuwrirCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: apiClient),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => LocationCubit()..init()),
          BlocProvider(create: (_) => HomeCubit(apiClient)),
          BlocProvider(create: (_) => MerchantDetailCubit(apiClient)),
          BlocProvider(create: (_) => CartCubit()),
          BlocProvider(create: (_) => OrderCubit(apiClient)),
          BlocProvider(create: (_) => OrderTrackingCubit(apiClient)),
        ],
        child: MaterialApp(
          title: 'KUWRIR',
          debugShowCheckedModeBanner: false,
          theme: KuwrirTheme.light,
          darkTheme: KuwrirTheme.dark,
          themeMode: ThemeMode.light,
          home: const _SplashRouter(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/login':
                return MaterialPageRoute(builder: (_) => const CustomerLoginScreen());
              case '/register':
                return MaterialPageRoute(builder: (_) => const CustomerRegisterScreen());
              case '/home':
                return MaterialPageRoute(builder: (_) => const CustomerHome());
              case '/search':
                return MaterialPageRoute(builder: (_) => const SearchScreen());
              case '/merchant':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => MerchantDetailScreen(
                    merchantId: args['id'] as String,
                    merchantName: args['name'] as String,
                  ),
                );
              case '/cart':
                return MaterialPageRoute(builder: (_) => const CartScreen());
              case '/tracking':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (ctx) => OrderTrackingScreen(
                    orderId: args['order_id'] as String,
                  ),
                );
              case '/chat':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    orderId: args['order_id'] as String,
                    orderNumber: args['order_number'] as String,
                  ),
                );
              case '/profile':
                return MaterialPageRoute(builder: (_) => const ProfileScreen());
              default:
                return null;
            }
          },
        ),
      ),
    );
  }
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final api = ApiClient();
    final hasToken = await api.isAuthenticated();
    if (!mounted) return;
    if (!hasToken) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final res = await api.get('/auth/me');
      if (!mounted) return;
      final role = res['user']?['role'];
      if (role != 'customer') {
        await api.clearTokens();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      await api.clearTokens();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/images/logo_cocourir.svg', height: 64),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _idx,
        children: const [
          HomeScreen(),
          _PromoScreen(),
          _OrdersScreen(),
          _ChatListScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer),
              label: 'Promo'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chat'),
        ],
      ),
    );
  }
}

class _OrdersScreen extends StatefulWidget {
  const _OrdersScreen();

  @override
  State<_OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<_OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = false;
  bool _loaded = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiClient>();
      _orders = await api.getMyOrders();
      _loaded = true;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_orders.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pesanan Saya')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Belum ada pesanan', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Refresh')),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (_, i) {
          final o = _orders[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(o.merchantName ?? o.senderName ?? '-'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(o.status),
                  Text('Rp ${o.total.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              onTap: () =>
                  Navigator.pushNamed(context, '/tracking', arguments: {'order_id': o.id}),
            ),
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'delivered':
      case 'returned':
        c = Colors.green;
        break;
      case 'cancelled':
        c = Colors.red;
        break;
      case 'preparing':
      case 'ready':
      case 'picked_up':
        c = Colors.orange;
        break;
      default:
        c = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.replaceAll('_', ' '),
          style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
    );
  }
}

class _PromoScreen extends StatefulWidget {
  const _PromoScreen();

  @override
  State<_PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends State<_PromoScreen> {
  late Future<List<Promotion>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient().getActivePromotions();
  }

  Future<void> _refresh() async {
    setState(() => _future = ApiClient().getActivePromotions());
    await _future;
  }

  String _valueLabel(Promotion p) {
    switch (p.type) {
      case 'percentage':
        return 'Diskon ${p.value.toStringAsFixed(0)}%';
      case 'fixed':
        return 'Potongan Rp ${p.value.toStringAsFixed(0)}';
      case 'free_delivery':
        return 'Gratis Ongkir';
      default:
        return p.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promo')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Promotion>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final promos = snapshot.data ?? const [];
            if (promos.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_offer_outlined, size: 72, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('Belum ada promo aktif',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Text('Pantau terus untuk penawaran terbaik',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: promos.length,
              itemBuilder: (context, i) {
                final p = promos[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.imageUrl != null)
                        Image.network(p.imageUrl!,
                            height: 140, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: KuwrirColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(p.code,
                                      style: const TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.bold, color: KuwrirColors.primary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(_valueLabel(p),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(p.title, style: TextStyle(color: KuwrirColors.textSecondary)),
                            if (p.minOrder > 0) ...[
                              const SizedBox(height: 6),
                              Text('Min. belanja Rp ${p.minOrder.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 12, color: KuwrirColors.textHint)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChatListScreen extends StatefulWidget {
  const _ChatListScreen();

  @override
  State<_ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<_ChatListScreen> {
  List<Order> _activeOrders = [];
  bool _loading = false;
  bool _loaded = false;

  static const _chatStatuses = {'confirmed', 'preparing', 'ready', 'picked_up'};

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiClient>();
      final orders = await api.getMyOrders();
      _activeOrders = orders.where((o) => _chatStatuses.contains(o.status)).toList();
      _loaded = true;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Support chat tile
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: KuwrirColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.support_agent, color: KuwrirColors.primary),
                  ),
                  title: const Text('Bantuan & Support',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Chat dengan tim admin KUWRIR'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportChatScreen()),
                  ),
                ),
                const Divider(height: 1),
                if (_activeOrders.isEmpty) ...[
                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('Tidak ada chat pesanan aktif',
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        const Text('Chat muncul saat pesanan sedang diproses',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Pesanan Aktif',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: Colors.grey)),
                  ),
                  for (final o in _activeOrders)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.withValues(alpha: 0.12),
                        child: const Icon(Icons.delivery_dining, color: Colors.orange),
                      ),
                      title: Text('#${o.orderNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(o.merchantName ?? o.senderName ?? '-'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusBadge(o.status),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatScreen(orderId: o.id, orderNumber: o.orderNumber),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

