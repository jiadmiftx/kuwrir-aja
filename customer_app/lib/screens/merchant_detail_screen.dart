import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class MerchantDetailScreen extends StatelessWidget {
  final String merchantId;
  final String merchantName;

  const MerchantDetailScreen({
    super.key,
    required this.merchantId,
    required this.merchantName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                merchantName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              background: Container(
                color: KuwrirColors.primary.withValues(alpha: 0.15),
                child: const Center(
                  child: Icon(Icons.store, size: 64, color: KuwrirColors.primary),
                ),
              ),
            ),
          ),

          // Merchant info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, size: 18, color: KuwrirColors.warning),
                      const SizedBox(width: 4),
                      const Text('4.8', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(' (124 reviews)', style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: KuwrirColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Open',
                          style: TextStyle(color: KuwrirColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: KuwrirColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Jl. Raya Kuta, Lombok Tengah', style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: KuwrirColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('15-20 min · 0.8 km', style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
                      const SizedBox(width: 12),
                      Icon(Icons.delivery_dining, size: 16, color: KuwrirColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('IDR 15,000', style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          // Menu items
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Makanan Utama',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KuwrirColors.primary,
                      ),
                    ),
                  ),
                  _ProductCard(
                    name: 'Nasi Campur Spesial',
                    description: 'Nasi putih dengan ayam suwir, sate lilit, lawar, sambal matah',
                    price: 57500, // Already includes 15% markup
                    onAdd: () {},
                  ),
                  _ProductCard(
                    name: 'Ayam Bakar Taliwang',
                    description: 'Ayam kampung bakar bumbu khas Lombok, pedas',
                    price: 46000,
                    onAdd: () {},
                  ),
                  _ProductCard(
                    name: 'Plecing Kangkung',
                    description: 'Kangkung rebus dengan sambal tomat khas Lombok',
                    price: 17250,
                    onAdd: () {},
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Minuman',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KuwrirColors.primary,
                      ),
                    ),
                  ),
                  _ProductCard(
                    name: 'Es Kelapa Muda',
                    description: 'Kelapa muda segar dengan es',
                    price: 17250,
                    onAdd: () {},
                  ),
                  _ProductCard(
                    name: 'Jus Mangga',
                    description: 'Jus mangga segar tanpa gula',
                    price: 14950,
                    onAdd: () {},
                  ),
                  const SizedBox(height: 100), // Space for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom cart bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            // TODO: Navigate to cart
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 20),
                SizedBox(width: 8),
                Text('View Cart'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Menu Item Card ---
class _ProductCard extends StatelessWidget {
  final String name;
  final String description;
  final double price;
  final VoidCallback onAdd;

  const _ProductCard({
    required this.name,
    required this.description,
    required this.price,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image placeholder
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: KuwrirColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_bag, color: KuwrirColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'IDR ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: KuwrirColors.primary,
                        ),
                      ),
                      GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: KuwrirColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
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
