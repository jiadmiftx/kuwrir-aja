import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/merchant_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'screens/search_screen.dart';
import 'screens/service_home_screen.dart';
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
          ServiceHomeScreen(),
          _OrdersScreen(),
          _ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu),
              label: 'Makanan'),
          NavigationDestination(
              icon: Icon(Icons.handyman_outlined),
              selectedIcon: Icon(Icons.handyman),
              label: 'Jasa'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Pesanan'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
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

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await context.read<ApiClient>().clearTokens();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
