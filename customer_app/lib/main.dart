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
import 'screens/merchant_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'screens/search_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/support_chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'utils/auth_guard.dart';
import 'cubits/home_cubit.dart';
import 'cubits/merchant_detail_cubit.dart';
import 'cubits/cart_cubit.dart';
import 'cubits/order_cubit.dart';
import 'cubits/order_tracking_cubit.dart';
import 'cubits/location_cubit.dart';
import 'cubits/session_cubit.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final notification = message.notification;
  if (notification != null) {
    await NotificationService.persist(notification.title ?? '', notification.body ?? '');
  }
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
          BlocProvider(create: (_) => SessionCubit(apiClient)),
          BlocProvider(create: (_) => HomeCubit(apiClient)),
          BlocProvider(create: (_) => MerchantDetailCubit(apiClient)),
          BlocProvider(create: (_) => CartCubit()),
          BlocProvider(create: (_) => OrderCubit(apiClient)),
          BlocProvider(create: (_) => OrderTrackingCubit(apiClient)),
        ],
        child: MaterialApp(
          title: 'Cocourir',
          debugShowCheckedModeBanner: false,
          theme: KuwrirTheme.light,
          darkTheme: KuwrirTheme.dark,
          themeMode: ThemeMode.light,
          home: const _SplashRouter(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/login':
                return MaterialPageRoute(builder: (_) => const CustomerLoginScreen());
              case '/home':
                return MaterialPageRoute(builder: (_) => const AppLockGate(child: CustomerHome()));
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
              case '/notifications':
                return MaterialPageRoute(builder: (_) => const NotificationsScreen());
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
    final api = context.read<ApiClient>();
    final hasToken = await api.isAuthenticated();
    if (!mounted) return;
    if (!hasToken) {
      // No session yet — browse as guest; login is only required once a
      // gated action (orders, chat, checkout, profile) is attempted.
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    try {
      final sessionCubit = context.read<SessionCubit>();
      await sessionCubit.load();
      if (!mounted) return;
      final user = sessionCubit.state.user;
      if (user == null || user.role != 'customer') {
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
        onDestinationSelected: (i) async {
          // Orders (2) and Chat (3) require a session; Home/Promo stay
          // browsable for guests.
          if ((i == 2 || i == 3) && !await ensureLoggedIn(context)) return;
          if (mounted) setState(() => _idx = i);
        },
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
    if (_loading) {
      return Scaffold(
        backgroundColor: KuwrirColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_orders.isEmpty) {
      return Scaffold(
        backgroundColor: KuwrirColors.background,
        appBar: AppBar(title: const Text('Pesanan Saya'), backgroundColor: KuwrirColors.background),
        body: _EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Belum ada pesanan',
          subtitle: 'Pesanan yang kamu buat akan muncul di sini',
          onRefresh: _load,
        ),
      );
    }
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
        backgroundColor: KuwrirColors.background,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: KuwrirColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _orders.length,
          itemBuilder: (_, i) {
            final o = _orders[i];
            return _SoftListTile(
              margin: const EdgeInsets.only(bottom: 12),
              onTap: () => Navigator.pushNamed(context, '/tracking', arguments: {'order_id': o.id}),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KuwrirColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long_outlined, color: KuwrirColors.primary, size: 20),
              ),
              title: o.orderNumber,
              subtitle: o.merchantName ?? o.senderName ?? '-',
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(o.status),
                  const SizedBox(height: 4),
                  Text('Rp ${o.total.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Consistent flat-tinted-surface empty state — replaces raw grey icon +
/// text pairs scattered per screen with one reusable, on-brand treatment.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRefresh;
  const _EmptyState({required this.icon, required this.title, required this.subtitle, this.onRefresh});

  @override
  Widget build(BuildContext context) {
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
                color: KuwrirColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: KuwrirColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KuwrirColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary),
                textAlign: TextAlign.center),
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRefresh, child: const Text('Muat Ulang')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Flat bordered surface for tappable list rows — same soft-panel
/// language as the merchant Toko screen, used instead of boxy Material
/// Cards across the app.
class _SoftListTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final EdgeInsets margin;

  const _SoftListTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: KuwrirColors.textSecondary)),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
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
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(title: const Text('Promo'), backgroundColor: KuwrirColors.background),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: KuwrirColors.primary,
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
                    child: _EmptyState(
                      icon: Icons.local_offer_outlined,
                      title: 'Belum ada promo aktif',
                      subtitle: 'Pantau terus untuk penawaran terbaik',
                    ),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: promos.length,
              itemBuilder: (context, i) {
                final p = promos[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: KuwrirColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: KuwrirColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.imageUrl != null)
                        Image.network(p.imageUrl!,
                            height: 140, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: KuwrirColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(p.code,
                                      style: const TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.bold, color: KuwrirColors.primary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(_valueLabel(p),
                                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Text(p.title, style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13)),
                            if (p.minOrder > 0) ...[
                              const SizedBox(height: 8),
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
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: KuwrirColors.background,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SoftListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: KuwrirColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.support_agent, color: KuwrirColors.primary, size: 20),
                  ),
                  title: 'Bantuan & Support',
                  subtitle: 'Chat dengan tim admin Cocourir',
                  trailing: Icon(Icons.chevron_right, color: KuwrirColors.textHint),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportChatScreen()),
                  ),
                ),
                if (_activeOrders.isEmpty) ...[
                  const SizedBox(height: 40),
                  _EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Tidak ada chat pesanan aktif',
                    subtitle: 'Chat muncul saat pesanan sedang diproses',
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                    child: Text('PESANAN AKTIF',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: KuwrirColors.textHint)),
                  ),
                  for (final o in _activeOrders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SoftListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: KuwrirColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.delivery_dining, color: KuwrirColors.warning, size: 20),
                        ),
                        title: '#${o.orderNumber}',
                        subtitle: o.merchantName ?? o.senderName ?? '-',
                        trailing: _StatusBadge(o.status),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(orderId: o.id, orderNumber: o.orderNumber),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

