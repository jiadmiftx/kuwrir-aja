import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
    await NotificationService.persist(notification.title ?? '', notification.body ?? '');
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
      titleTextStyle: GoogleFonts.plusJakartaSans(color: KuwrirColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
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
    return MultiRepositoryProvider(
      providers: [RepositoryProvider<ApiClient>.value(value: apiClient)],
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
                return MaterialPageRoute(builder: (_) => const CustomerLoginScreen());
              case '/home':
                final homeArgs = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (_) => AppLockGate(child: CustomerHome(initialTab: homeArgs?['tab'] as int? ?? 0)),
                );
              case '/search':
                return MaterialPageRoute(builder: (_) => const SearchScreen());
              case '/merchant':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => MerchantDetailScreen(merchantId: args['id'] as String, merchantName: args['name'] as String),
                );
              case '/cart':
                return MaterialPageRoute(builder: (_) => const CartScreen());
              case '/tracking':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(builder: (ctx) => OrderTrackingScreen(orderId: args['order_id'] as String));
              case '/chat':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => ChatScreen(orderId: args['order_id'] as String, orderNumber: args['order_number'] as String),
                );
              case '/profile':
                return MaterialPageRoute(builder: (_) => const ProfileScreen());
              case '/notifications':
                return MaterialPageRoute(builder: (_) => const NotificationsScreen());
              case '/addresses':
                return MaterialPageRoute(builder: (_) => const AddressesScreen());
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
    } catch (_) {
      await api.clearTokens();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [SvgPicture.asset('assets/images/logo_cocourir.svg', height: 64), const SizedBox(height: 24), const CircularProgressIndicator()]),
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
      body: IndexedStack(index: _idx, children: const [HomeScreen(), _PromoScreen(), _OrdersScreen(), _ChatListScreen()]),
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
            icon: HugeIcon(icon: HugeIcons.strokeRoundedHome01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedHome01),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedDiscountTag01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedDiscountTag01),
            label: 'Promo',
          ),
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedInvoice01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedInvoice01),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedChat),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedChat01),
            label: 'Chat',
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

class _OrdersScreenState extends State<_OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = false;
  bool _loaded = false;

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
        body: _EmptyState(icon: HugeIcons.strokeRoundedInvoice01, title: 'Belum ada pesanan', subtitle: 'Pesanan yang kamu buat akan muncul di sini', onRefresh: _load),
      );
    }
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(title: const Text('Pesanan Saya'), backgroundColor: KuwrirColors.background),
      body: RefreshIndicator(
        onRefresh: _load,
        color: KuwrirColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _orders.length,
          itemBuilder: (_, i) => _OrderCard(
            order: _orders[i],
            onTap: () => Navigator.pushNamed(context, '/tracking', arguments: {'order_id': _orders[i].id}),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  String get _itemSummary {
    if (order.items.isEmpty) return order.merchantName ?? order.senderName ?? '-';
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
                      decoration: BoxDecoration(color: KuwrirColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(11)),
                      clipBehavior: Clip.antiAlias,
                      child: order.merchantLogoUrl != null && order.merchantLogoUrl!.isNotEmpty
                          ? Image.network(
                              order.merchantLogoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => HugeIcon(icon: HugeIcons.strokeRoundedStore01, color: KuwrirColors.primary, size: 17),
                            )
                          : HugeIcon(icon: HugeIcons.strokeRoundedStore01, color: KuwrirColors.primary, size: 17),
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
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text('#${order.orderNumber}${_dateLabel != null ? ' · ${_dateLabel!}' : ''}', style: TextStyle(fontSize: 11.5, color: KuwrirColors.textHint)),
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
                        style: TextStyle(fontSize: 12.5, color: KuwrirColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rp ${_fmt(order.total)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: KuwrirColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
              decoration: BoxDecoration(color: KuwrirColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: HugeIcon(icon: icon, size: 36, color: KuwrirColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KuwrirColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRefresh != null) ...[const SizedBox(height: 16), TextButton(onPressed: onRefresh, child: const Text('Muat Ulang'))],
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

  const _SoftListTile({required this.leading, required this.title, required this.subtitle, this.trailing, required this.onTap, this.margin = EdgeInsets.zero});

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
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: KuwrirColors.textSecondary),
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
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
      child: Text(
        _label,
        style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w700),
      ),
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
    final future = ApiClient().getActivePromotions();
    setState(() {
      _future = future;
    });
    await future;
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
                    child: _EmptyState(icon: HugeIcons.strokeRoundedDiscountTag01, title: 'Belum ada promo aktif', subtitle: 'Pantau terus untuk penawaran terbaik'),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              itemCount: promos.length,
              itemBuilder: (context, i) => _PromoCard(promo: promos[i]),
            );
          },
        ),
      ),
    );
  }
}

/// Per-type accent + icon so a promo reads at a glance without parsing the
/// title text — percentage/fixed/free-delivery each get their own personality
/// instead of one flat green treatment for every card.
class _PromoStyle {
  final Color color;
  final List<List<dynamic>> icon;
  const _PromoStyle(this.color, this.icon);
}

_PromoStyle _promoStyle(String type) {
  switch (type) {
    case 'fixed':
      return const _PromoStyle(KuwrirColors.accent, HugeIcons.strokeRoundedSavings);
    case 'free_delivery':
      return const _PromoStyle(KuwrirColors.warning, HugeIcons.strokeRoundedDeliveryBox01);
    default:
      return const _PromoStyle(KuwrirColors.primary, HugeIcons.strokeRoundedPercent);
  }
}

class _PromoCard extends StatelessWidget {
  final Promotion promo;
  const _PromoCard({required this.promo});

  String get _valueLabel {
    switch (promo.type) {
      case 'percentage':
        return 'Diskon ${promo.value.toStringAsFixed(0)}%';
      case 'fixed':
        return 'Potongan Rp ${_fmt(promo.value)}';
      case 'free_delivery':
        return 'Gratis Ongkir';
      default:
        return promo.title;
    }
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: promo.code));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kode ${promo.code} disalin'), backgroundColor: KuwrirColors.primaryDark, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _promoStyle(promo.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KuwrirColors.border),
        boxShadow: [BoxShadow(color: KuwrirColors.textPrimary.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (promo.imageUrl != null)
            Image.network(
              promo.imageUrl!,
              height: 132,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _PromoHeroFallback(style: style),
            )
          else
            _PromoHeroFallback(style: style),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _valueLabel,
                  style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: style.color),
                ),
                const SizedBox(height: 4),
                Text(promo.title, style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13, height: 1.35)),
                if (promo.minOrder > 0 || (promo.type == 'percentage' && promo.maxDiscount > 0)) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (promo.minOrder > 0) _PromoInfoChip(text: 'Min. belanja Rp ${_fmt(promo.minOrder)}'),
                      if (promo.type == 'percentage' && promo.maxDiscount > 0) _PromoInfoChip(text: 'Maks. Rp ${_fmt(promo.maxDiscount)}'),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => _copyCode(context),
                  borderRadius: BorderRadius.circular(12),
                  child: DottedCodeChip(code: promo.code, color: style.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoInfoChip extends StatelessWidget {
  final String text;
  const _PromoInfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: KuwrirColors.background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: KuwrirColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A coupon-style code pill with a dashed border, doubling as the tap
/// target to copy the code — makes "Salin Kode" a real affordance instead
/// of a static label.
class DottedCodeChip extends StatelessWidget {
  final String code;
  final Color color;
  const DottedCodeChip({super.key, required this.code, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedTicket01, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              code,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5),
            ),
          ),
          HugeIcon(icon: HugeIcons.strokeRoundedCopy01, size: 15, color: color.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}

class _PromoHeroFallback extends StatelessWidget {
  final _PromoStyle style;
  const _PromoHeroFallback({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [style.color.withValues(alpha: 0.16), style.color.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: HugeIcon(icon: style.icon, size: 34, color: style.color),
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
        _activeOrders = orders.where((o) => _chatStatuses.contains(o.status)).toList();
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
      appBar: AppBar(title: const Text('Chat'), backgroundColor: KuwrirColors.background),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: KuwrirColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _SoftListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: KuwrirColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                      child: HugeIcon(icon: HugeIcons.strokeRoundedCustomerService01, color: KuwrirColors.primary, size: 20),
                    ),
                    title: 'Bantuan & Support',
                    subtitle: 'Chat dengan tim admin Cocourir',
                    trailing: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: KuwrirColors.textHint),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportChatScreen())),
                  ),
                  if (_activeOrders.isEmpty) ...[
                    const SizedBox(height: 40),
                    _EmptyState(icon: HugeIcons.strokeRoundedChat, title: 'Tidak ada chat pesanan aktif', subtitle: 'Chat muncul saat pesanan sedang diproses'),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                      child: Text(
                        'PESANAN AKTIF',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: KuwrirColors.textHint),
                      ),
                    ),
                    for (final o in _activeOrders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SoftListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: KuwrirColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: HugeIcon(icon: HugeIcons.strokeRoundedDeliveryBox01, color: KuwrirColors.warning, size: 20),
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
            ),
    );
  }
}
