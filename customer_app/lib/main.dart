import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'cubits/chat_cubit.dart' show ChatChannel;
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/addresses_screen.dart';
import 'screens/wallet_screen.dart';
import 'utils/auth_guard.dart';
import 'cubits/home_cubit.dart';
import 'cubits/merchant_detail_cubit.dart';
import 'cubits/cart_cubit.dart';
import 'cubits/order_cubit.dart';
import 'cubits/order_tracking_cubit.dart';
import 'cubits/location_cubit.dart';
import 'cubits/session_cubit.dart';
import 'cubits/address_cubit.dart';
import 'cubits/wallet_cubit.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final notification = message.notification;
  if (notification != null) {
    await NotificationService.persist(
      notification.title ?? '',
      notification.body ?? '',
    );
  }
}

// Customer-app-only typography: `KuwrirTheme` (shared/kuwrir_shared) declares
// `fontFamily: 'Inter'` but never bundles the font, so it silently falls
// back to the platform default everywhere across all 3 apps. Rather than
// touch the shared theme (driver_app/merchant_app aren't part of this
// redesign), layer Plus Jakarta Sans on top here via `copyWith` — a
// geometric, slightly more distinctive face than Inter that reads as
// premium rather than "default SaaS", without a font-asset pipeline.
ThemeData _customerTheme(ThemeData base) {
  final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: KuwrirColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
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
    // App-lifetime singleton, same as apiClient above (no dispose — this
    // widget only ever builds once at the app root in practice).
    final chatUnread = ChatUnreadService(
      fetch: apiClient.getChatUnreadCount,
      pushSignal: NotificationService.onPushData,
    )..start();
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: apiClient),
        RepositoryProvider<ChatUnreadService>.value(value: chatUnread),
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
          BlocProvider(create: (_) => AddressCubit(apiClient)),
          BlocProvider(create: (_) => CustomerWalletCubit(apiClient)),
        ],
        child: MaterialApp(
          title: 'Cocourir',
          debugShowCheckedModeBanner: false,
          theme: _customerTheme(KuwrirTheme.light),
          darkTheme: _customerTheme(KuwrirTheme.dark),
          themeMode: ThemeMode.light,
          home: const _SplashRouter(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/login':
                return MaterialPageRoute(
                  builder: (_) => const CustomerLoginScreen(),
                );
              case '/home':
                final homeArgs = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (_) => AppLockGate(
                    child: CustomerHome(
                      initialTab: homeArgs?['tab'] as int? ?? 0,
                    ),
                  ),
                );
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
                  builder: (ctx) =>
                      OrderTrackingScreen(orderId: args['order_id'] as String),
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
                return MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                );
              case '/addresses':
                return MaterialPageRoute(
                  builder: (_) => const AddressesScreen(),
                );
              case '/wallet':
                return MaterialPageRoute(builder: (_) => const WalletScreen());
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

      // Re-upload the FCM token on every app start, not just fresh login —
      // login_screen.dart's upload only fires the moment credentials are
      // entered, so a persisted session that skips straight to /home here
      // (the common case: reopening the app) would otherwise never
      // register a current token, and SendToUser on the backend silently
      // no-ops when the stored token is empty/stale. Same fix merchant_app
      // already has (see its _SplashRouterState._checkAuth).
      unawaited(NotificationService.uploadToken(api));
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
  final int initialTab;
  const CustomerHome({super.key, this.initialTab = 0});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  late int _idx = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _idx,
        children: const [
          HomeScreen(),
          CartScreen(),
          _OrdersScreen(),
          _ChatListScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) async {
          // Orders (2) and Chat (3) require a session; Home/Cart stay
          // browsable for guests.
          if ((i == 2 || i == 3) && !await ensureLoggedIn(context)) return;
          if (mounted) setState(() => _idx = i);
        },
        destinations: [
          const NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedHome01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedHome01),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: _CartTabIcon(icon: HugeIcons.strokeRoundedShoppingBag02),
            selectedIcon: _CartTabIcon(
              icon: HugeIcons.strokeRoundedShoppingBag02,
            ),
            label: 'Keranjang',
          ),
          const NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedInvoice01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedInvoice01),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: _ChatTabIcon(icon: HugeIcons.strokeRoundedChat),
            selectedIcon: _ChatTabIcon(icon: HugeIcons.strokeRoundedChat01),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}

/// Cart tab icon with an item-count badge, so the tab itself signals "you
/// have stuff in here" the same way the Chat tab signals unread messages —
/// without this the only other cart-contents hint was the floating cart
/// button, which only appears on Home/Search/store pages.
class _CartTabIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  const _CartTabIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) => Stack(
        clipBehavior: Clip.none,
        children: [
          HugeIcon(icon: icon),
          if (cart.totalQuantity > 0)
            Positioned(
              right: -6,
              top: -4,
              child: UnreadBadge(count: cart.totalQuantity),
            ),
        ],
      ),
    );
  }
}

/// Chat tab icon with an unread-count badge — sums order-chat (driver +
/// merchant channels) and support unread from [ChatUnreadService].
class _ChatTabIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  const _ChatTabIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ChatUnreadService>();
    return ValueListenableBuilder<ChatUnreadCount>(
      valueListenable: service.count,
      builder: (context, count, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          HugeIcon(icon: icon),
          if (count.total > 0)
            Positioned(
              right: -6,
              top: -4,
              child: UnreadBadge(count: count.total),
            ),
        ],
      ),
    );
  }
}

/// The 44x44 leading icon used by every row in the Chat tab (support, chat
/// merchant, chat driver), with an unread-count badge overlaid top-right —
/// [unreadCount] picks the relevant number out of [ChatUnreadCount] so one
/// widget covers all three row kinds.
class _ChatEntryIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  final int Function(ChatUnreadCount) unreadCount;
  const _ChatEntryIcon({
    required this.icon,
    required this.color,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<ChatUnreadService>();
    return ValueListenableBuilder<ChatUnreadCount>(
      valueListenable: service.count,
      builder: (context, count, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(icon: icon, color: color, size: 20),
          ),
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

class _OrdersScreen extends StatefulWidget {
  const _OrdersScreen();

  @override
  State<_OrdersScreen> createState() => _OrdersScreenState();
}

/// Order status → which of the four tabs it belongs under. Mirrors
/// _StatusBadge's own status vocabulary so a badge color and its tab agree
/// on what "active"/"done" mean.
enum _OrderTab { all, active, completed, cancelled }

const _orderTabLabels = {
  _OrderTab.all: 'Semua',
  _OrderTab.active: 'Berlangsung',
  _OrderTab.completed: 'Selesai',
  _OrderTab.cancelled: 'Dibatalkan',
};

const _activeStatuses = {
  'pending',
  'confirmed',
  'preparing',
  'ready',
  'picked_up',
};

bool _orderMatchesTab(Order order, _OrderTab tab) {
  switch (tab) {
    case _OrderTab.all:
      return true;
    case _OrderTab.active:
      return _activeStatuses.contains(order.status);
    case _OrderTab.completed:
      return order.status == 'delivered' || order.status == 'returned';
    case _OrderTab.cancelled:
      return order.status == 'cancelled';
  }
}

class _OrdersScreenState extends State<_OrdersScreen>
    with SingleTickerProviderStateMixin {
  List<Order> _orders = [];
  bool _loading = false;
  bool _loaded = false;
  late final TabController _tabController = TabController(
    length: _OrderTab.values.length,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// This screen lives inside CustomerHome's IndexedStack, so it's mounted
  /// (and this fires) from app launch regardless of which tab is active or
  /// whether the user is logged in — guest browsing is a supported mode.
  /// Two things matter here:
  /// 1. Skip the network call entirely for guests (ApiClient.getMyOrders
  ///    would just 401) rather than firing a request that's guaranteed to
  ///    fail.
  /// 2. Always mark `_loaded = true` once this finishes, success or not.
  ///    build() below reschedules _load() via addPostFrameCallback as long
  ///    as `!_loaded && !_loading` — previously a failed fetch left
  ///    `_loaded` false forever, so every rebuild re-scheduled another
  ///    attempt with no delay, hammering /api/v1/orders in a tight loop.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiClient>();
      if (await api.isAuthenticated()) {
        _orders = await api.getMyOrders();
      }
    } catch (_) {}
    _loaded = true;
    if (mounted) setState(() => _loading = false);
  }

  /// Awaiting the push (rather than firing it and forgetting) is what picks
  /// up status changes made on the tracking screen — cancel, item-replacement,
  /// delivery progress — instead of leaving this list showing stale data
  /// once the customer comes back to it.
  Future<void> _openTracking(Order order) async {
    await Navigator.pushNamed(
      context,
      '/tracking',
      arguments: {'order_id': order.id},
    );
    if (mounted) _load();
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
        appBar: AppBar(
          title: const Text('Pesanan Saya'),
          backgroundColor: KuwrirColors.background,
        ),
        body: _EmptyState(
          icon: HugeIcons.strokeRoundedInvoice01,
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
      body: TabBarView(
        controller: _tabController,
        children: _OrderTab.values
            .map(
              (tab) => _OrdersTabView(
                orders: _orders.where((o) => _orderMatchesTab(o, tab)).toList(),
                tab: tab,
                onRefresh: _load,
                onTapOrder: _openTracking,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _OrdersTabView extends StatelessWidget {
  final List<Order> orders;
  final _OrderTab tab;
  final Future<void> Function() onRefresh;
  final void Function(Order) onTapOrder;

  const _OrdersTabView({
    required this.orders,
    required this.tab,
    required this.onRefresh,
    required this.onTapOrder,
  });

  static const _emptyCopy = {
    _OrderTab.all: (
      'Belum ada pesanan',
      'Pesanan yang kamu buat akan muncul di sini',
    ),
    _OrderTab.active: (
      'Tidak ada pesanan berlangsung',
      'Pesanan yang sedang diproses akan muncul di sini',
    ),
    _OrderTab.completed: (
      'Belum ada pesanan selesai',
      'Riwayat pesanan yang selesai akan muncul di sini',
    ),
    _OrderTab.cancelled: (
      'Tidak ada pesanan dibatalkan',
      'Pesanan yang dibatalkan akan muncul di sini',
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
            SizedBox(height: MediaQuery.of(context).size.height * 0.14),
            _EmptyState(
              icon: HugeIcons.strokeRoundedInvoice01,
              title: title,
              subtitle: subtitle,
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
        itemBuilder: (_, i) =>
            _OrderCard(order: orders[i], onTap: () => onTapOrder(orders[i])),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  String get _itemSummary {
    if (order.items.isEmpty)
      return order.merchantName ?? order.senderName ?? '-';
    final first = order.items.first.itemName;
    final extra = order.items.length - 1;
    return extra > 0 ? '$first +$extra lainnya' : first;
  }

  String? get _dateLabel {
    final t = order.createdAt;
    if (t == null) return null;
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: KuwrirColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          order.merchantLogoUrl != null &&
                              order.merchantLogoUrl!.isNotEmpty
                          ? Image.network(
                              order.merchantLogoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedStore01,
                                    color: KuwrirColors.primary,
                                    size: 17,
                                  ),
                            )
                          : HugeIcon(
                              icon: HugeIcons.strokeRoundedStore01,
                              color: KuwrirColors.primary,
                              size: 17,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.merchantName ?? order.senderName ?? 'Pesanan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '#${order.orderNumber}${_dateLabel != null ? ' · ${_dateLabel!}' : ''}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: KuwrirColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(order.status),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: KuwrirColors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _itemSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: KuwrirColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rp ${_fmt(order.total)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: KuwrirColors.primary,
                      ),
                    ),
                  ],
                ),
                // Chat straight from the list — the old design made a
                // customer open the full tracking screen just to reach a
                // button that's really about this row, and merchant vs
                // driver looked identical (same icon, no label) once you
                // finally got there. Two distinct, labeled chips instead,
                // each gated by Order.canChatMerchant/canChatDriver so
                // they only appear once there's actually someone to chat
                // with (mirrors the AppBar icons on the tracking screen).
                if (order.canChatMerchant || order.canChatDriver) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (order.canChatMerchant)
                        _ChatActionChip(
                          icon: HugeIcons.strokeRoundedStore01,
                          label: 'Chat Toko',
                          color: KuwrirColors.primary,
                          unreadCount: (c) => c.forOrder(order.id, 'merchant'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                orderId: order.id,
                                orderNumber: order.orderNumber,
                                channel: ChatChannel.merchant,
                                counterpartLabel: order.merchantName ?? 'Toko',
                                itemSummary: _itemSummary,
                                total: order.total,
                                statusLabel: _StatusBadge(order.status)._label,
                              ),
                            ),
                          ),
                        ),
                      if (order.canChatMerchant && order.canChatDriver)
                        const SizedBox(width: 8),
                      if (order.canChatDriver)
                        _ChatActionChip(
                          icon: HugeIcons.strokeRoundedMotorbike01,
                          label: 'Chat Driver',
                          color: KuwrirColors.info,
                          unreadCount: (c) => c.forOrder(order.id, 'driver'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                orderId: order.id,
                                orderNumber: order.orderNumber,
                                itemSummary: _itemSummary,
                                total: order.total,
                                statusLabel: _StatusBadge(order.status)._label,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small labeled, colored, badge-able action button — used for the two
/// chat entry points on each order card so "which chat is this" reads at
/// a glance (icon + label + color, not just an icon).
class _ChatActionChip extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final Color color;
  final int Function(ChatUnreadCount) unreadCount;
  final VoidCallback onTap;
  const _ChatActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<ChatUnreadService>();
    return ValueListenableBuilder<ChatUnreadCount>(
      valueListenable: service.count,
      builder: (context, count, _) {
        final unread = unreadCount(count);
        return Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(icon: icon, size: 15, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 6),
                    UnreadBadge(count: unread),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Consistent flat-tinted-surface empty state — replaces raw grey icon +
/// text pairs scattered per screen with one reusable, on-brand treatment.
class _EmptyState extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRefresh;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRefresh,
  });

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
              child: HugeIcon(
                icon: icon,
                size: 36,
                color: KuwrirColors.primary,
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary),
              textAlign: TextAlign.center,
            ),
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
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: KuwrirColors.textSecondary,
                        ),
                      ),
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

  Color get _color {
    switch (status) {
      case 'delivered':
      case 'returned':
        return KuwrirColors.success;
      case 'cancelled':
        return KuwrirColors.error;
      case 'pending':
      case 'preparing':
      case 'ready':
        return KuwrirColors.warning;
      case 'confirmed':
      case 'picked_up':
        return KuwrirColors.info;
      default:
        return KuwrirColors.textHint;
    }
  }

  String get _label {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Diproses';
      case 'ready':
        return 'Siap Diambil';
      case 'picked_up':
        return 'Dikirim';
      case 'delivered':
        return 'Selesai';
      case 'returned':
        return 'Dikembalikan';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        _label,
        style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w700),
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
      if (await api.isAuthenticated()) {
        final orders = await api.getMyOrders();
        _activeOrders = orders
            .where((o) => _chatStatuses.contains(o.status))
            .toList();
      }
    } catch (_) {}
    _loaded = true;
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: KuwrirColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _SoftListTile(
                    leading: _ChatEntryIcon(
                      icon: HugeIcons.strokeRoundedCustomerService01,
                      color: KuwrirColors.primary,
                      unreadCount: (c) => c.support,
                    ),
                    title: 'Bantuan & Support',
                    subtitle: 'Chat dengan tim admin Cocourir',
                    trailing: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      color: KuwrirColors.textHint,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportChatScreen(),
                      ),
                    ),
                  ),
                  if (_activeOrders.isEmpty) ...[
                    const SizedBox(height: 40),
                    _EmptyState(
                      icon: HugeIcons.strokeRoundedChat,
                      title: 'Tidak ada chat pesanan aktif',
                      subtitle: 'Chat muncul saat pesanan sedang diproses',
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                      child: Text(
                        'PESANAN AKTIF',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: KuwrirColors.textHint,
                        ),
                      ),
                    ),
                    for (final o in _activeOrders) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SoftListTile(
                          leading: _ChatEntryIcon(
                            icon: HugeIcons.strokeRoundedStore01,
                            color: KuwrirColors.primary,
                            unreadCount: (c) => c.forOrder(o.id, 'merchant'),
                          ),
                          title: o.merchantName ?? '-',
                          subtitle: '#${o.orderNumber} · Chat Merchant',
                          trailing: _StatusBadge(o.status),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                orderId: o.id,
                                orderNumber: o.orderNumber,
                                channel: ChatChannel.merchant,
                                counterpartLabel: o.merchantName ?? 'Merchant',
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SoftListTile(
                          leading: _ChatEntryIcon(
                            icon: HugeIcons.strokeRoundedDeliveryBox01,
                            color: KuwrirColors.warning,
                            unreadCount: (c) => c.forOrder(o.id, 'driver'),
                          ),
                          title: 'Driver',
                          subtitle: '#${o.orderNumber} · Chat Driver',
                          trailing: _StatusBadge(o.status),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                orderId: o.id,
                                orderNumber: o.orderNumber,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}
