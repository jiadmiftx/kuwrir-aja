import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  bool _hasQuery = false;
  late final TabController _tabController;

  final List<String> _recentSearches = [
    'Ayam Taliwang',
    'Nasi Campur',
    'Sate Rembiga',
    'Es Kelapa',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller.addListener(() {
      final hasQuery = _controller.text.trim().isNotEmpty;
      if (hasQuery != _hasQuery) setState(() => _hasQuery = hasQuery);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        backgroundColor: KuwrirColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        title: Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: KuwrirColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: KuwrirColors.border),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Cari makanan atau warung...',
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              hintStyle:
                  TextStyle(color: KuwrirColors.textHint, fontSize: 14),
              prefixIcon: Icon(Icons.search,
                  color: KuwrirColors.textHint, size: 20),
              suffixIcon: _hasQuery
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: KuwrirColors.textSecondary,
                      onPressed: () => _controller.clear(),
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 14),
            onSubmitted: (_) {},
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: KuwrirColors.border),
        ),
      ),
      body: Column(
        children: [
          // Delivery address widget
          _DeliveryAddressBar(),

          // Content
          Expanded(
            child: _hasQuery ? _SearchResults(tabController: _tabController) : _EmptyState(
              recentSearches: _recentSearches,
              onTap: (s) {
                _controller.text = s;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: s.length),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Delivery Address Bar ────────────────────────────────────────────────────

class _DeliveryAddressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: KuwrirColors.surface,
      child: InkWell(
        onTap: () {
          // TODO: open address picker
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: KuwrirColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: KuwrirColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on,
                    color: KuwrirColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Antar ke',
                      style: TextStyle(
                        fontSize: 11,
                        color: KuwrirColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Jl. Pantai Kuta No. 12, Kuta, Lombok Tengah',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: KuwrirColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: KuwrirColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Ubah',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: KuwrirColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onTap;

  const _EmptyState({required this.recentSearches, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pencarian Terakhir',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: KuwrirColors.textPrimary,
                    ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: KuwrirColors.primary,
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Hapus semua', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recentSearches.map((search) {
              return InkWell(
                onTap: () => onTap(search),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: KuwrirColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: KuwrirColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history,
                          size: 14, color: KuwrirColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(search,
                          style: TextStyle(
                              fontSize: 13,
                              color: KuwrirColors.textPrimary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Text(
            'Populer di Kuta',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: KuwrirColors.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: const [
              _CategoryCard(emoji: '🍗', label: 'Ayam\nTaliwang', color: Color(0xFFFF6B35)),
              _CategoryCard(emoji: '🍚', label: 'Nasi\nCampur', color: Color(0xFF22C55E)),
              _CategoryCard(emoji: '🥘', label: 'Sate\nRembiga', color: Color(0xFFF59E0B)),
              _CategoryCard(emoji: '🥤', label: 'Es &\nMinuman', color: Color(0xFF3B82F6)),
              _CategoryCard(emoji: '🍰', label: 'Kue &\nDessert', color: Color(0xFFEC4899)),
              _CategoryCard(emoji: '🌶️', label: 'Makanan\nPedas', color: Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;

  const _CategoryCard({
    required this.emoji,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.85),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Search Results ───────────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  final TabController tabController;

  const _SearchResults({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: KuwrirColors.surface,
          child: TabBar(
            controller: tabController,
            indicatorColor: KuwrirColors.primary,
            indicatorWeight: 2.5,
            labelColor: KuwrirColors.primary,
            unselectedLabelColor: KuwrirColors.textSecondary,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(text: 'Restoran'),
              Tab(text: 'Menu'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _RestaurantResultList(),
              _MenuItemResultList(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Restaurant Result List ───────────────────────────────────────────────────

class _RestaurantResultList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Sample data — replace with API
    final restaurants = [
      _RestaurantData(
        name: 'Warung Nasi Campur Bu Eka',
        category: 'Masakan Indonesia',
        tags: ['Nasi', 'Lauk Pauk'],
        rating: 4.8,
        reviews: 124,
        distance: '0.8 km',
        deliveryTime: '15–20 mnt',
        priceRange: '8–25rb',
        emoji: '🍛',
        color: Color(0xFFFF6B35),
        isOpen: true,
        hasPromo: true,
      ),
      _RestaurantData(
        name: 'Ayam Taliwang Irama',
        category: 'Khas Lombok',
        tags: ['Ayam', 'Pedas'],
        rating: 4.5,
        reviews: 89,
        distance: '1.2 km',
        deliveryTime: '20–25 mnt',
        priceRange: '15–40rb',
        emoji: '🍗',
        color: Color(0xFFF59E0B),
        isOpen: true,
        hasPromo: false,
      ),
      _RestaurantData(
        name: 'Sate Rembiga Pak Haji',
        category: 'Sate & Bakar',
        tags: ['Sate', 'Bakar'],
        rating: 4.9,
        reviews: 210,
        distance: '1.5 km',
        deliveryTime: '25–30 mnt',
        priceRange: '20–50rb',
        emoji: '🥘',
        color: Color(0xFF22C55E),
        isOpen: false,
        hasPromo: false,
      ),
      _RestaurantData(
        name: 'Es Campur Madu Lombok',
        category: 'Minuman & Dessert',
        tags: ['Es', 'Minuman'],
        rating: 4.3,
        reviews: 56,
        distance: '0.5 km',
        deliveryTime: '10–15 mnt',
        priceRange: '5–15rb',
        emoji: '🥤',
        color: Color(0xFF3B82F6),
        isOpen: true,
        hasPromo: true,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: restaurants.length,
      itemBuilder: (context, i) =>
          _RestaurantResultCard(data: restaurants[i]),
    );
  }
}

class _RestaurantData {
  final String name, category, distance, deliveryTime, priceRange, emoji;
  final List<String> tags;
  final double rating;
  final int reviews;
  final Color color;
  final bool isOpen, hasPromo;

  const _RestaurantData({
    required this.name,
    required this.category,
    required this.tags,
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.deliveryTime,
    required this.priceRange,
    required this.emoji,
    required this.color,
    required this.isOpen,
    required this.hasPromo,
  });
}

class _RestaurantResultCard extends StatelessWidget {
  final _RestaurantData data;

  const _RestaurantResultCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/merchant',
              arguments: {'id': '1', 'name': data.name}),
          child: Column(
            children: [
              // Image area
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: data.color.withValues(alpha: 0.12),
                      child: Center(
                        child: Text(
                          data.emoji,
                          style: const TextStyle(fontSize: 52),
                        ),
                      ),
                    ),
                    // Top badges
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _OpenBadge(isOpen: data.isOpen),
                    ),
                    if (data.hasPromo)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: KuwrirColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PROMO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Info area
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: KuwrirColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Rating pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 13, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 2),
                              Text(
                                data.rating.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Tags
                    Wrap(
                      spacing: 5,
                      children: data.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: data.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: data.color.withValues(alpha: 0.85),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // Meta row
                    Row(
                      children: [
                        _MetaChip(
                          icon: Icons.access_time_rounded,
                          label: data.deliveryTime,
                        ),
                        const SizedBox(width: 12),
                        _MetaChip(
                          icon: Icons.location_on_outlined,
                          label: data.distance,
                        ),
                        const SizedBox(width: 12),
                        _MetaChip(
                          icon: Icons.payments_outlined,
                          label: data.priceRange,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.reviews_outlined,
                                size: 12,
                                color: KuwrirColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              '${data.reviews} ulasan',
                              style: TextStyle(
                                fontSize: 11,
                                color: KuwrirColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  final bool isOpen;

  const _OpenBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOpen
            ? KuwrirColors.success.withValues(alpha: 0.9)
            : Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOpen ? Colors.white : Colors.white60,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'Buka' : 'Tutup',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: KuwrirColors.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: KuwrirColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Menu Item Result List ────────────────────────────────────────────────────

class _MenuItemResultList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      _MenuItemData(
        name: 'Ayam Taliwang Pedas',
        restaurantName: 'Ayam Taliwang Irama',
        description: 'Ayam kampung bakar bumbu Taliwang khas Lombok, pedas gurih',
        price: 35000,
        originalPrice: 42000,
        rating: 4.7,
        emoji: '🍗',
        color: Color(0xFFF59E0B),
        tag: 'Terlaris',
      ),
      _MenuItemData(
        name: 'Nasi Campur Spesial',
        restaurantName: 'Warung Nasi Campur Bu Eka',
        description: 'Nasi putih dengan lauk pauk lengkap pilihan',
        price: 18000,
        rating: 4.8,
        emoji: '🍛',
        color: Color(0xFFFF6B35),
        tag: 'Favorit',
      ),
      _MenuItemData(
        name: 'Sate Rembiga 10 Tusuk',
        restaurantName: 'Sate Rembiga Pak Haji',
        description: 'Daging sapi pilihan bumbu merah khas Rembiga',
        price: 28000,
        rating: 4.9,
        emoji: '🥘',
        color: Color(0xFF22C55E),
        tag: null,
      ),
      _MenuItemData(
        name: 'Es Kelapa Muda',
        restaurantName: 'Es Campur Madu Lombok',
        description: 'Kelapa muda segar langsung dari petani Lombok',
        price: 12000,
        rating: 4.5,
        emoji: '🥥',
        color: Color(0xFF3B82F6),
        tag: 'Baru',
      ),
      _MenuItemData(
        name: 'Plecing Kangkung',
        restaurantName: 'Warung Nasi Campur Bu Eka',
        description: 'Kangkung segar dengan sambal tomat pedas khas Lombok',
        price: 10000,
        rating: 4.6,
        emoji: '🌿',
        color: Color(0xFF22C55E),
        tag: null,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, i) => _MenuItemCard(data: items[i]),
    );
  }
}

class _MenuItemData {
  final String name, restaurantName, description, emoji;
  final double rating;
  final int price;
  final int? originalPrice;
  final Color color;
  final String? tag;

  const _MenuItemData({
    required this.name,
    required this.restaurantName,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.rating,
    required this.emoji,
    required this.color,
    this.tag,
  });
}

class _MenuItemCard extends StatelessWidget {
  final _MenuItemData data;

  const _MenuItemCard({required this.data});

  String _formatPrice(int price) {
    if (price >= 1000) {
      return 'Rp ${(price / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp $price';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food image
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          data.emoji,
                          style: const TextStyle(fontSize: 36),
                        ),
                      ),
                    ),
                    if (data.tag != null)
                      Positioned(
                        top: -4,
                        left: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: data.tag == 'Terlaris'
                                ? KuwrirColors.primary
                                : data.tag == 'Baru'
                                    ? KuwrirColors.info
                                    : KuwrirColors.warning,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            data.tag!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.storefront_outlined,
                              size: 11,
                              color: KuwrirColors.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              data.restaurantName,
                              style: TextStyle(
                                fontSize: 11,
                                color: KuwrirColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: KuwrirColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Rating
                          Row(
                            children: [
                              Icon(Icons.star_rounded,
                                  size: 13,
                                  color: KuwrirColors.warning),
                              const SizedBox(width: 2),
                              Text(
                                data.rating.toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          // Price
                          if (data.originalPrice != null)
                            Text(
                              _formatPrice(data.originalPrice!),
                              style: TextStyle(
                                fontSize: 11,
                                color: KuwrirColors.textHint,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          if (data.originalPrice != null)
                            const SizedBox(width: 4),
                          Text(
                            _formatPrice(data.price),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: KuwrirColors.primary,
                            ),
                          ),
                          const Spacer(),
                          // Add button
                          GestureDetector(
                            onTap: () {
                              // TODO: add to cart
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: KuwrirColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
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
        ),
      ),
    );
  }
}
