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
import 'cubits/store_orders_cubit.dart';
import 'cubits/menu_cubit.dart';
import 'cubits/store_cubit.dart';
import 'cubits/dashboard_cubit.dart';
import 'cubits/wallet_cubit.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const KuwrirMerchantApp());
  await NotificationService.init();
  NotificationService.setupForegroundHandler();
}

class KuwrirMerchantApp extends StatelessWidget {
  const KuwrirMerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    return MultiRepositoryProvider(
      providers: [RepositoryProvider<ApiClient>.value(value: apiClient)],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => StoreOrdersCubit(apiClient)),
          BlocProvider(create: (_) => MenuCubit(apiClient)),
          BlocProvider(create: (_) => StoreCubit(apiClient)),
          BlocProvider(create: (_) => DashboardCubit(apiClient)),
          BlocProvider(create: (_) => MerchantWalletCubit(apiClient)),
        ],
        child: MaterialApp(
          title: 'Cocourir Merchant',
          debugShowCheckedModeBanner: false,
          theme: KuwrirTheme.light,
          darkTheme: KuwrirTheme.dark,
          themeMode: ThemeMode.light,
          home: const _SplashRouter(),
          routes: {
            '/login':    (_) => const MerchantLoginScreen(),
            '/register': (_) => const MerchantRegisterScreen(),
            '/pending':  (_) => const MerchantPendingScreen(),
            '/home':     (_) => const AppLockGate(child: MerchantHome()),
            '/wallet':   (_) => const WalletScreen(),
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
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Keuangan',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
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

      // Account exists (via OTP/Google) but the store form was never
      // finished — send them back into it instead of a dead end on
      // Home/Pending, which both assume a store already exists.
      final hasMerchantProfile = res['has_merchant_profile'] ?? false;
      if (!hasMerchantProfile) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MerchantRegisterScreen(startAtStep: 1)),
        );
        return;
      }

      // user.is_active only means "this login account is enabled" — it's
      // true from account creation and says nothing about store approval.
      // The actual gate is the Merchant row's own verification status.
      var approved = false;
      try {
        final statusRes = await api.get('/my-store/status');
        approved = statusRes['status'] == 'approved' && statusRes['is_active'] == true;
      } catch (_) {
        // Treat an unreachable status check as not-yet-approved rather
        // than silently granting Home access.
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, approved ? '/home' : '/pending');
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
            Icon(Icons.store, size: 72, color: KuwrirColors.primary),
            SizedBox(height: 16),
            Text('Cocourir Merchant',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

