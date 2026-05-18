import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'screens/orders_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/store_screen.dart';

void main() {
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
      home: const MerchantHome(),
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
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
            label: 'Store',
          ),
        ],
      ),
    );
  }
}
