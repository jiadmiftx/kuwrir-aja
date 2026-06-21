import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/merchant_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'screens/search_screen.dart';
import 'screens/chat_screen.dart';
import 'cubits/merchant_list_cubit.dart';
import 'cubits/merchant_detail_cubit.dart';
import 'cubits/cart_cubit.dart';
import 'cubits/order_cubit.dart';
import 'cubits/order_tracking_cubit.dart';
import 'cubits/location_cubit.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.init();
  NotificationService.setupForegroundHandler();
  runApp(const KuwrirCustomerApp());
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
          BlocProvider(create: (_) => MerchantListCubit(apiClient)),
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
    final token = await ApiClient().isAuthenticated();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, token ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delivery_dining, size: 72, color: KuwrirColors.primary),
            SizedBox(height: 16),
            Text('KUWRIR', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
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

class _PromoScreen extends StatelessWidget {
  const _PromoScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Promo segera hadir!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Pantau terus untuk penawaran terbaik',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _ChatListScreen extends StatelessWidget {
  const _ChatListScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Belum ada chat aktif',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Chat tersedia saat pesanan sedang diantar',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

