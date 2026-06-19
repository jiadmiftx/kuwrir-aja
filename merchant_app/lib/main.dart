import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/store_screen.dart';
import 'screens/kasir_screen.dart';
import 'screens/kasir_reports_screen.dart';
import 'screens/kasir_receivables_screen.dart';
import 'screens/kasir_payables_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const KuwrirMerchantApp());
}

class KuwrirMerchantApp extends StatelessWidget {
  const KuwrirMerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KUWRIR Merchant',
      debugShowCheckedModeBanner: false,
      theme: KuwrirTheme.light,
      darkTheme: KuwrirTheme.dark,
      themeMode: ThemeMode.light,
      initialRoute: '/login',
      routes: {
        '/login':    (_) => const MerchantLoginScreen(),
        '/register': (_) => const MerchantRegisterScreen(),
        '/pending':  (_) => const MerchantPendingScreen(),
        '/home':     (_) => const MerchantHome(),
      },
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
            OrdersScreen(),
            MenuScreen(),
            KasirHub(),   // Phase 6: POS / Kasir
            StoreScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
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
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Kasir',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
            label: 'Store',
          ),
        ],
      ),
    );
  }
}

/// KasirHub is the entry point for all POS/Kasir features.
/// Provides quick-access tiles to: POS Terminal, Piutang, Hutang, Laporan.
class KasirHub extends StatelessWidget {
  const KasirHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primary action — POS Terminal
            SizedBox(
              width: double.infinity,
              height: 72,
              child: FilledButton.icon(
                icon: const Icon(Icons.point_of_sale, size: 28),
                label: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buka Kasir / POS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Catat transaksi penjualan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                  ],
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KasirScreen())),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Keuangan Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 12),

            // 2x2 grid of financial features
            Row(
              children: [
                Expanded(child: _hubTile(context, Icons.trending_up, 'Laporan', 'Laba Rugi · Arus Kas · Stok', Colors.green, const KasirReportsScreen())),
                const SizedBox(width: 12),
                Expanded(child: _hubTile(context, Icons.arrow_forward, 'Piutang', 'Tab & kredit pelanggan', Colors.blue, const KasirReceivablesScreen())),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _hubTile(context, Icons.arrow_back, 'Hutang', 'Pembelian bahan supplier', Colors.red, const KasirPayablesScreen())),
                const SizedBox(width: 12),
                Expanded(child: _hubTile(context, Icons.inventory, 'Stok', 'Cek & sesuaikan stok', Colors.orange, const KasirReportsScreen())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hubTile(BuildContext context, IconData icon, String title, String subtitle, Color color, Widget screen) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
