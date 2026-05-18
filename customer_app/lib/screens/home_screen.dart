import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            _HomeTab(),
            _OrdersTab(),
            _ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// --- Home Tab ---
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header with location + search
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, color: KuwrirColors.primary, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      'Kuta, Lombok',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 20),
                  ],
                ),
                const SizedBox(height: 16),

                // Search bar
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/search'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: KuwrirColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KuwrirColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: KuwrirColors.textHint, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Search merchants or product...',
                          style: TextStyle(color: KuwrirColors.textHint, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Categories
                Text(
                  'Categories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      _CategoryChip(icon: Icons.store, label: 'All', isSelected: true),
                      _CategoryChip(icon: Icons.local_fire_department, label: 'Popular'),
                      _CategoryChip(icon: Icons.rice_bowl, label: 'Nasi'),
                      _CategoryChip(icon: Icons.kebab_dining, label: 'Sate'),
                      _CategoryChip(icon: Icons.local_drink, label: 'Drinks'),
                      _CategoryChip(icon: Icons.icecream, label: 'Dessert'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Nearby Merchants',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ),

        // Merchant list
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _MerchantCard(
                name: 'Warung Nasi Campur Bu Eka',
                category: 'Indonesian · Rice',
                rating: 4.8,
                reviews: 124,
                distance: '0.8 km',
                deliveryTime: '15-20 min',
                imageColor: KuwrirColors.primary,
                onTap: () => Navigator.pushNamed(context, '/merchant', arguments: {
                  'id': '1',
                  'name': 'Warung Nasi Campur Bu Eka',
                }),
              ),
              _MerchantCard(
                name: 'Ayam Taliwang Irama',
                category: 'Lombok · Spicy',
                rating: 4.5,
                reviews: 89,
                distance: '1.2 km',
                deliveryTime: '20-25 min',
                imageColor: KuwrirColors.accent,
                onTap: () => Navigator.pushNamed(context, '/merchant', arguments: {
                  'id': '2',
                  'name': 'Ayam Taliwang Irama',
                }),
              ),
              _MerchantCard(
                name: 'Sate Rembiga Pak Haji',
                category: 'Satay · Grilled',
                rating: 4.9,
                reviews: 210,
                distance: '1.5 km',
                deliveryTime: '25-30 min',
                imageColor: KuwrirColors.warning,
                onTap: () => Navigator.pushNamed(context, '/merchant', arguments: {
                  'id': '3',
                  'name': 'Sate Rembiga Pak Haji',
                }),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }
}

// --- Category Chip ---
class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;

  const _CategoryChip({
    required this.icon,
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected ? KuwrirColors.primary : KuwrirColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? KuwrirColors.primary : KuwrirColors.border,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : KuwrirColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? KuwrirColors.primary : KuwrirColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Merchant Card ---
class _MerchantCard extends StatelessWidget {
  final String name;
  final String category;
  final double rating;
  final int reviews;
  final String distance;
  final String deliveryTime;
  final Color imageColor;
  final VoidCallback onTap;

  const _MerchantCard({
    required this.name,
    required this.category,
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.deliveryTime,
    required this.imageColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: imageColor.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Icon(Icons.store, size: 48, color: imageColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: KuwrirColors.warning),
                      const SizedBox(width: 2),
                      Text('$rating', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(' ($reviews)', style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
                      const SizedBox(width: 12),
                      Icon(Icons.location_on_outlined, size: 14, color: KuwrirColors.textSecondary),
                      Text(distance, style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: KuwrirColors.textSecondary),
                      Text(deliveryTime, style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Placeholder Tabs ---
class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No orders yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Profile', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}
