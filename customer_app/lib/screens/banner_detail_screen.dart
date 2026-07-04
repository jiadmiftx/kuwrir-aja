import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'search_screen.dart';

class BannerDetailScreen extends StatelessWidget {
  final PromoBanner banner;
  const BannerDetailScreen({super.key, required this.banner});

  void _onCtaTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          initialCategoryId: banner.promoType.isEmpty ? banner.foodCategoryId : null,
          initialDiscount: banner.promoType == 'discount',
          initialFreeDelivery: banner.promoType == 'free_delivery',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            backgroundColor: KuwrirColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (banner.imageUrl != null)
                    Image.network(
                      banner.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: KuwrirColors.primary),
                    )
                  else
                    Container(color: KuwrirColors.primary),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.45),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: KuwrirColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  if (banner.subtitle?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      banner.subtitle!,
                      style: TextStyle(fontSize: 15, color: KuwrirColors.textSecondary, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _onCtaTap(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KuwrirColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        banner.ctaText,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
