import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'cubits/job_board_cubit.dart';
import 'cubits/active_delivery_cubit.dart';
import 'cubits/wallet_cubit.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/job_board_screen.dart';
import 'screens/active_delivery_screen.dart';
import 'screens/wallet_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final apiClient = ApiClient();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MultiRepositoryProvider(
        providers: [RepositoryProvider<ApiClient>.value(value: apiClient)],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => JobBoardCubit(apiClient)),
            BlocProvider(create: (_) => ActiveDeliveryCubit(apiClient)),
            BlocProvider(create: (_) => DriverWalletCubit(apiClient)),
          ],
          child: const KuwrirDriverApp(),
        ),
      ),
    ),
  );
  await NotificationService.init();
  NotificationService.setupForegroundHandler();
}

class KuwrirDriverApp extends StatelessWidget {
  const KuwrirDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cocourir Driver',
      theme: KuwrirTheme.light,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const InitialRouter(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const DriverRegisterScreen(),
        '/pending': (context) => const DriverPendingScreen(),
        '/job_board': (context) => const AppLockGate(child: JobBoardScreen()),
        '/active_delivery': (context) => const ActiveDeliveryScreen(),
        '/wallet': (context) => const WalletScreen(),
      },
    );
  }
}

class InitialRouter extends StatefulWidget {
  const InitialRouter({super.key});

  @override
  State<InitialRouter> createState() => _InitialRouterState();
}

class _InitialRouterState extends State<InitialRouter> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.checkAuthStatus();

    if (!mounted) return;

    if (!authProvider.isAuthenticated || authProvider.user?.role != 'driver') {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // authProvider.isAuthenticated only means the login account itself is
    // enabled — it says nothing about driver-application approval. The
    // real gate is GET /driver/application (same endpoint pending_screen
    // already polls); anything other than approved+active routes to
    // /pending instead of silently unlocking the job board.
    var approved = false;
    try {
      final res = await ApiClient().get('/driver/application');
      final application = res['application'];
      approved =
          application != null &&
          application['status'] == 'approved' &&
          res['is_active'] == true;
    } catch (_) {
      // Treat an unreachable status check as not-yet-approved.
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      approved ? '/job_board' : '/pending',
    );

    // Re-upload the FCM token on every app start, not just fresh login —
    // login_screen.dart's upload only fires the moment credentials are
    // entered, so a persisted session that skips straight past login here
    // (the common case: reopening the app) would otherwise never register
    // a current token, and SendToUser on the backend silently no-ops when
    // the stored token is empty/stale. Same fix merchant_app/customer_app
    // already have.
    unawaited(NotificationService.uploadToken(ApiClient()));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
