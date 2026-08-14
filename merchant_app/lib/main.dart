import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/store_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/incoming_order_screen.dart';
import 'cubits/store_orders_cubit.dart';
import 'cubits/menu_cubit.dart';
import 'cubits/store_cubit.dart';
import 'cubits/dashboard_cubit.dart';
import 'cubits/wallet_cubit.dart';
import 'package:hugeicons/hugeicons.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Builds and shows the local notification here (not just persisting it) —
  // required for the new-order alarm, sent data-only specifically so this
  // background isolate is what runs (in every app state, including fully
  // killed) rather than Android's own auto-display, which can't attach a
  // full-screen intent. See NotificationService.handleBackgroundMessage.
  await NotificationService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const KuwrirMerchantApp());
  await NotificationService.init();
  NotificationService.setupForegroundHandler();
}

/// App-wide navigator key so the incoming-order alarm screen can be pushed
/// from NotificationService's push listener, which fires outside any
/// widget's BuildContext (foreground push arrives while the merchant could
/// be on any screen, or the app could just be cold-starting).
final navigatorKey = GlobalKey<NavigatorState>();

class KuwrirMerchantApp extends StatelessWidget {
  const KuwrirMerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final storeOrdersCubit = StoreOrdersCubit(apiClient);

    // Push already tells us the moment something about an order changes
    // (new order, customer resolving an item-replacement request, customer
    // cancelling, etc. — see backend's `type` field on each SendToUser call)
    // — use that as the primary refresh trigger instead of waiting on the
    // slow poll fallback in StoreOrdersCubit. Only 'new_order' also pops
    // the full-screen incoming-order alarm; 'order_status' (customer
    // replaced/cancelled an item, etc.) just needs the list to refresh so
    // it's not left showing a stale item list or total.
    NotificationService.onPushData.addListener(() {
      final data = NotificationService.onPushData.value;
      final type = data?['type'];
      if (type != 'new_order' && type != 'order_status') return;
      storeOrdersCubit.load();
      if (type != 'new_order') return;
      final orderId = data?['order_id'] as String?;
      final nav = navigatorKey.currentState;
      if (orderId != null && nav != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => IncomingOrderScreen(orderId: orderId),
            fullscreenDialog: true,
          ),
        );
      }
    });

    return MultiRepositoryProvider(
      providers: [RepositoryProvider<ApiClient>.value(value: apiClient)],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: storeOrdersCubit),
          BlocProvider(create: (_) => MenuCubit(apiClient)),
          BlocProvider(create: (_) => StoreCubit(apiClient)),
          BlocProvider(create: (_) => DashboardCubit(apiClient)),
          BlocProvider(create: (_) => MerchantWalletCubit(apiClient)),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Cocourir Merchant',
          debugShowCheckedModeBanner: false,
          theme: KuwrirTheme.light,
          darkTheme: KuwrirTheme.dark,
          themeMode: ThemeMode.light,
          home: const _SplashRouter(),
          routes: {
            '/login': (_) => const MerchantLoginScreen(),
            '/register': (_) => const MerchantRegisterScreen(),
            '/pending': (_) => const MerchantPendingScreen(),
            '/home': (_) => const AppLockGate(child: MerchantHome()),
            '/wallet': (_) => const WalletScreen(),
            '/notifications': (_) => const NotificationsScreen(),
          },
        ),
      ),
    );
  }
}

class MerchantHome extends StatefulWidget {
  const MerchantHome({super.key});

  @override
  State<MerchantHome> createState() => _MerchantHomeState();
}

class _MerchantHomeState extends State<MerchantHome> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            DashboardScreen(),
            OrdersScreen(),
            MenuScreen(),
            WalletScreen(),
            StoreScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedDashboardSquare01),
            selectedIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedDashboardSquare01,
            ),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedInvoice01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedInvoice01),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedPackage),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedPackage),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedWallet01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedWallet01),
            label: 'Keuangan',
          ),
          NavigationDestination(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedStore01),
            selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedStore01),
            label: 'Toko',
          ),
        ],
      ),
    );
  }
}

// ─── Splash Router ────────────────────────────────────────────────────────────
// Checks saved token on startup; routes to /home, /pending, or /login.

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

    // Validate token + check merchant status
    try {
      final res = await api.get('/auth/me');
      if (!mounted) return;
      final role = res['user']?['role'];

      if (role != 'merchant') {
        await api.clearTokens();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Account exists but the store form was never finished — send them
      // back into it instead of a dead end on Home/Pending, which both
      // assume a store already exists.
      final hasMerchantProfile = res['has_merchant_profile'] ?? false;
      if (!hasMerchantProfile) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MerchantRegisterScreen(startAtStep: 1),
          ),
        );
        return;
      }

      // user.is_active only means "this login account is enabled" — it's
      // true from account creation and says nothing about store approval.
      // The actual gate is the Merchant row's own verification status.
      var approved = false;
      try {
        final statusRes = await api.get('/my-store/status');
        approved =
            statusRes['status'] == 'approved' && statusRes['is_active'] == true;
      } catch (_) {
        // Treat an unreachable status check as not-yet-approved rather
        // than silently granting Home access.
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, approved ? '/home' : '/pending');

      // Re-upload the FCM token on every app start, not just fresh login —
      // login_screen.dart's upload only fires the moment credentials are
      // entered, so a persisted session that skips straight to /home here
      // (the common case: reopening the app, or a debug reinstall that got
      // a new token) would otherwise never register a current token, and
      // SendToUser on the backend silently no-ops when the stored token is
      // empty/stale.
      unawaited(NotificationService.uploadToken(api));

      // Cold start via tapping the new-order full-screen notification while
      // the app was fully killed — onMessageOpenedApp (used for the
      // backgrounded-not-killed case) never fires for this path, so it
      // needs its own check. Set after the /home navigation above so the
      // onPushData listener (registered in KuwrirMerchantApp.build, which
      // already ran before this async gap) is there to catch it.
      if (approved) {
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null && initialMessage.data.isNotEmpty) {
          NotificationService.onPushData.value = initialMessage.data;
        }
      }
    } catch (_) {
      await api.clearTokens();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedStore01,
              size: 72,
              color: KuwrirColors.primary,
            ),
            SizedBox(height: 16),
            Text(
              'Cocourir Merchant',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
