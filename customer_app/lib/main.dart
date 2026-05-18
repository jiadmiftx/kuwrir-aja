import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'screens/home_screen.dart';
import 'screens/merchant_detail_screen.dart';
import 'screens/search_screen.dart';

void main() {
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
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
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
            return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
      },
    );
  }
}
