import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/job_board_screen.dart';
import 'screens/active_delivery_screen.dart';
import 'screens/wallet_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const KuwrirDriverApp(),
    ),
  );
}

class KuwrirDriverApp extends StatelessWidget {
  const KuwrirDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kuwrir Driver',
      theme: KuwrirTheme.light,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const InitialRouter(),
        '/login': (context) => const LoginScreen(),
        '/job_board': (context) => const JobBoardScreen(),
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

    if (authProvider.isAuthenticated && authProvider.user?.role == 'driver') {
      Navigator.pushReplacementNamed(context, '/job_board');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
