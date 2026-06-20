import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/merchant_detail_cubit.dart';
import '../cubits/cart_cubit.dart';

class MerchantDetailScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;

  const MerchantDetailScreen({
    super.key,
    required this.merchantId,
    required this.merchantName,
  });

  @override
  State<MerchantDetailScreen> createState() => _MerchantDetailScreenState();
}

class _MerchantDetailScreenState extends State<MerchantDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MerchantDetailCubit>().load(widget.merchantId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantDetailCubit, MerchantDetailState>(
      builder: (context, state) {
        return Scaffold(
          body: _buildBody(context, state),
          bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
            builder: (context, cart) {
              if (cart.isEmpty || cart.merchantId != widget.merchantId) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -2)),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/cart'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                          'Lihat Keranjang (${cart.totalQuantity}) · IDR ${_formatPrice(cart.subtotal)}'),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, MerchantDetailState state) {
    if (state is MerchantDetailLoading) {
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.merchantName),
              background: Container(
                color: KuwrirColors.primary.withValues(alpha: 0.15),
                child: const Center(child: Icon(Icons.store, size: 64, color: KuwrirColors.primary)),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      );
    }

    if (state is MerchantDetailError) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.merchantName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(state.message, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.read<MerchantDetailCubit>().load(widget.merchantId),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is MerchantDetailLoaded) {
      final merchant = state.merchant;
      return DefaultTabController(
        length: state.categories.length,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(merchant.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                background: merchant.bannerUrl != null
                    ? Image.network(merchant.bannerUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              color: KuwrirColors.primary.withValues(alpha: 0.15),
                              child: const Center(
                                  child: Icon(Icons.store, size: 64, color: KuwrirColors.primary)),
                            ))
                    : Container(
                        color: KuwrirColors.primary.withValues(alpha: 0.15),
                        child: const Center(
                            child: Icon(Icons.store, size: 64, color: KuwrirColors.primary)),
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
                        Text(merchant.rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(' (${merchant.totalReviews} ulasan)',
                            style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (merchant.isOpen ? KuwrirColors.success : Colors.grey)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            merchant.isOpen ? 'Buka' : 'Tutup',
                            style: TextStyle(
                                color: merchant.isOpen ? KuwrirColors.success : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 16, color: KuwrirColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(merchant.address,
                              style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (state.categories.isNotEmpty)
                      TabBar(
                        isScrollable: true,
                        tabs: state.categories
                            .map((cat) => Tab(text: cat.name))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),

            // Product lists by category
            SliverToBoxAdapter(
              child: state.categories.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Belum ada menu tersedia'),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final cat in state.categories) ...[
                            const SizedBox(height: 16),
                            Text(cat.name,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: KuwrirColors.primary)),
                            const SizedBox(height: 8),
                            for (final product in cat.products)
                              if (product.isAvailable)
                                _ProductCard(
                                  product: product,
                                  onAdd: () {
                                    context.read<CartCubit>().addItem(
                                          product,
                                          merchantId: merchant.id,
                                          merchantName: merchant.name,
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${product.name} ditambahkan ke keranjang'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                          ],
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.merchantName)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  String _formatPrice(double price) {
    return price
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;

  const _ProductCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: KuwrirColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: product.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(product.imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.shopping_bag, color: KuwrirColors.primary, size: 28)),
                    )
                  : const Icon(Icons.shopping_bag, color: KuwrirColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (product.description != null) ...[
                    const SizedBox(height: 4),
                    Text(product.description!,
                        style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'IDR ${_formatPrice(product.price)}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold, color: KuwrirColors.primary),
                      ),
                      BlocBuilder<CartCubit, CartState>(
                        builder: (context, cart) {
                          final qty = cart.items
                              .where((i) => i.product.id == product.id)
                              .fold(0, (sum, i) => sum + i.quantity);
                          if (qty > 0) {
                            return Row(
                              children: [
                                _QtyBtn(
                                    icon: Icons.remove,
                                    onTap: () =>
                                        context.read<CartCubit>().decrementItem(product.id)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('$qty',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                                _QtyBtn(icon: Icons.add, onTap: onAdd),
                              ],
                            );
                          }
                          return GestureDetector(
                            onTap: onAdd,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: KuwrirColors.primary,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.add, color: Colors.white, size: 18),
                            ),
                          );
                        },
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

  String _formatPrice(double price) => price
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: KuwrirColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 18, color: KuwrirColors.primary),
      ),
    );
  }
}
