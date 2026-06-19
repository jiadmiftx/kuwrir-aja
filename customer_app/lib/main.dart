import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'screens/home_screen.dart';
import 'screens/merchant_detail_screen.dart';
import 'screens/search_screen.dart';
import 'screens/service_home_screen.dart';

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
    return MaterialApp(
      title: 'KUWRIR',
      debugShowCheckedModeBanner: false,
      theme: KuwrirTheme.light,
      darkTheme: KuwrirTheme.dark,
      themeMode: ThemeMode.light,
      home: const CustomerHome(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
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
          default:
            return null;
        }
      },
    );
  }
}

/// Root scaffold with bottom navigation: Makanan | Jasa | Orders | Profile
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
          HomeScreen(),          // Makanan (food delivery)
          ServiceHomeScreen(),   // Jasa (laundry, bengkel, dll)
          _OrdersPlaceholder(),  // My Orders
          _ProfilePlaceholder(), // Profile
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Makanan'),
          NavigationDestination(icon: Icon(Icons.handyman_outlined), selectedIcon: Icon(Icons.handyman), label: 'Jasa'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pesanan'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _OrdersPlaceholder extends StatelessWidget {
  const _OrdersPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Daftar Pesanan (coming soon)')),
  );
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Profil (coming soon)')),
  );
}
