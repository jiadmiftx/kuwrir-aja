import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cubits/location_cubit.dart';
import '../widgets/floating_cart_button.dart';

class SearchScreen extends StatefulWidget {
  final String? initialCategoryId;
  final bool initialDiscount;
  final bool initialFreeDelivery;

  const SearchScreen({
    super.key,
    this.initialCategoryId,
    this.initialDiscount = false,
    this.initialFreeDelivery = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  static const _kRecentSearchesKey = 'recent_searches';

  final _controller = TextEditingController();
  bool _hasQuery = false;
  late final TabController _tabController;

  List<String> _recentSearches = [];

  late String? _categoryId = widget.initialCategoryId;
  late bool _discountOnly = widget.initialDiscount;
  late bool _freeDeliveryOnly = widget.initialFreeDelivery;

  bool get _hasActiveFilter =>
      _categoryId != null || _discountOnly || _freeDeliveryOnly;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller.addListener(() {
      final hasQuery = _controller.text.trim().isNotEmpty;
      if (hasQuery != _hasQuery) setState(() => _hasQuery = hasQuery);
    });
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kRecentSearchesKey) ?? [];
    if (mounted) setState(() => _recentSearches = saved);
  }

  Future<void> _saveSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = [trimmed, ..._recentSearches.where((s) => s != trimmed)]
        .take(8)
        .toList();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearchesKey);
    if (mounted) setState(() => _recentSearches = []);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _hasQuery || _hasActiveFilter;
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
            autofocus: widget.initialCategoryId == null &&
                !widget.initialDiscount &&
                !widget.initialFreeDelivery,
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
            onSubmitted: _saveSearch,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: KuwrirColors.border),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Delivery address widget
              _DeliveryAddressBar(),

              _FilterBar(
                categoryId: _categoryId,
                discountOnly: _discountOnly,
                freeDeliveryOnly: _freeDeliveryOnly,
                onChanged: (categoryId, discount, freeDelivery) => setState(() {
                  _categoryId = categoryId;
                  _discountOnly = discount;
                  _freeDeliveryOnly = freeDelivery;
                }),
              ),

              // Content
              Expanded(
                child: showResults
                    ? _SearchResults(
                        tabController: _tabController,
                        query: _controller.text.trim(),
                        categoryId: _categoryId,
                        discountOnly: _discountOnly,
                        freeDeliveryOnly: _freeDeliveryOnly,
                      )
                    : _EmptyState(
                        recentSearches: _recentSearches,
                        onTap: (s) {
                          _controller.text = s;
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: s.length),
                          );
                          _saveSearch(s);
                        },
                        onClearRecent: _clearRecentSearches,
                      ),
              ),
            ],
          ),
          const FloatingCartButton(),
        ],
      ),
    );
  }
}

// ─── Filter Bar ──────────────────────────────────────────────────────────────
// "Diskon"/"Gratis Ongkir" toggle chips plus a horizontal category picker —
// selecting any of these alone (with an empty search box) is enough to show
// filtered results, so a banner CTA can land here pre-filtered.

class _FilterBar extends StatefulWidget {
  final String? categoryId;
  final bool discountOnly;
  final bool freeDeliveryOnly;
  final void Function(String? categoryId, bool discount, bool freeDelivery) onChanged;

  const _FilterBar({
    required this.categoryId,
    required this.discountOnly,
    required this.freeDeliveryOnly,
    required this.onChanged,
  });

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  List<FoodCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final api = context.read<ApiClient>();
      final cats = await api.getFoodCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KuwrirColors.surface,
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Diskon',
                  icon: Icons.local_offer_outlined,
                  selected: widget.discountOnly,
                  onTap: () => widget.onChanged(
                      widget.categoryId, !widget.discountOnly, widget.freeDeliveryOnly),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Gratis Ongkir',
                  icon: Icons.delivery_dining_outlined,
                  selected: widget.freeDeliveryOnly,
                  onTap: () => widget.onChanged(
                      widget.categoryId, widget.discountOnly, !widget.freeDeliveryOnly),
                ),
              ],
            ),
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categories.map((c) {
                  final selected = c.id == widget.categoryId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: '${c.icon ?? ''} ${c.name}'.trim(),
                      selected: selected,
                      onTap: () => widget.onChanged(
                          selected ? null : c.id, widget.discountOnly, widget.freeDeliveryOnly),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Divider(height: 1, color: KuwrirColors.border),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? KuwrirColors.primary : KuwrirColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? KuwrirColors.primary : KuwrirColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : KuwrirColors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : KuwrirColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Delivery Address Bar ────────────────────────────────────────────────────

class _DeliveryAddressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final address = context.select((LocationCubit c) => c.state.address);
    return Material(
      color: KuwrirColors.surface,
      child: InkWell(
        onTap: () => context.read<LocationCubit>().detectGps(),
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
                      address,
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

class _EmptyState extends StatefulWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onTap;
  final VoidCallback onClearRecent;

  const _EmptyState({
    required this.recentSearches,
    required this.onTap,
    required this.onClearRecent,
  });

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  List<Merchant> _popular = [];
  bool _loadingPopular = true;

  @override
  void initState() {
    super.initState();
    _loadPopular();
  }

  Future<void> _loadPopular() async {
    try {
      final api = context.read<ApiClient>();
      _popular = await api.getPopularMerchants();
    } catch (_) {}
    if (mounted) setState(() => _loadingPopular = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (widget.recentSearches.isNotEmpty) ...[
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
                  onPressed: widget.onClearRecent,
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
              children: widget.recentSearches.map((search) {
                return InkWell(
                  onTap: () => widget.onTap(search),
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
          ],
          Text(
            'Populer di Mataram',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: KuwrirColors.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          if (_loadingPopular)
            const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ))
          else if (_popular.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Belum ada merchant populer',
                  style: TextStyle(color: KuwrirColors.textSecondary)),
            )
          else
            ..._popular.map((m) => _PopularMerchantTile(merchant: m)),
        ],
      ),
    );
  }
}

class _PopularMerchantTile extends StatelessWidget {
  final Merchant merchant;
  const _PopularMerchantTile({required this.merchant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pushNamed(context, '/merchant',
              arguments: {'id': merchant.id, 'name': merchant.name}),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: KuwrirColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.storefront, color: KuwrirColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(merchant.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(merchant.address,
                          style: TextStyle(fontSize: 11, color: KuwrirColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text(merchant.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Search Results ───────────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  final TabController tabController;
  final String query;
  final String? categoryId;
  final bool discountOnly;
  final bool freeDeliveryOnly;

  const _SearchResults({
    required this.tabController,
    required this.query,
    required this.categoryId,
    required this.discountOnly,
    required this.freeDeliveryOnly,
  });

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
              _RestaurantResultList(query: query, freeDeliveryOnly: freeDeliveryOnly),
              _MenuItemResultList(
                query: query,
                categoryId: categoryId,
                discountOnly: discountOnly,
                freeDeliveryOnly: freeDeliveryOnly,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Restaurant Result List ───────────────────────────────────────────────────

class _RestaurantResultList extends StatefulWidget {
  final String query;
  final bool freeDeliveryOnly;
  const _RestaurantResultList({required this.query, required this.freeDeliveryOnly});

  @override
  State<_RestaurantResultList> createState() => _RestaurantResultListState();
}

class _RestaurantResultListState extends State<_RestaurantResultList> {
  List<Merchant> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RestaurantResultList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.freeDeliveryOnly != widget.freeDeliveryOnly) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final merchants = widget.query.isEmpty
          ? await api.getPopularMerchants()
          : await api.searchMerchants(widget.query);
      _results = widget.freeDeliveryOnly
          ? merchants.where((m) => m.isFreeDelivery).toList()
          : merchants;
    } catch (e) {
      _error = 'Gagal memuat warung';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: KuwrirColors.textSecondary)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('Tidak ada warung yang cocok',
            style: TextStyle(color: KuwrirColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _results.length,
      itemBuilder: (context, i) => _RestaurantResultCard(merchant: _results[i]),
    );
  }
}

class _RestaurantResultCard extends StatelessWidget {
  final Merchant merchant;

  const _RestaurantResultCard({required this.merchant});

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
              arguments: {'id': merchant.id, 'name': merchant.name}),
          child: Column(
            children: [
              // Image area
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    merchant.logoUrl != null
                        ? Image.network(
                            merchant.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: KuwrirColors.primary.withValues(alpha: 0.12),
                              child: Icon(Icons.storefront, size: 48, color: KuwrirColors.primary),
                            ),
                          )
                        : Container(
                            color: KuwrirColors.primary.withValues(alpha: 0.12),
                            child: Icon(Icons.storefront, size: 48, color: KuwrirColors.primary),
                          ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _OpenBadge(isOpen: merchant.isOpen),
                    ),
                    if (merchant.isFreeDelivery)
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
                            'GRATIS ONGKIR',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
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
                                merchant.name,
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
                                merchant.address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: KuwrirColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                                merchant.rating.toStringAsFixed(1),
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
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (merchant.distanceKm != null)
                          _MetaChip(
                            icon: Icons.location_on_outlined,
                            label: '${merchant.distanceKm!.toStringAsFixed(1)} km',
                          ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.reviews_outlined,
                                size: 12,
                                color: KuwrirColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              '${merchant.totalReviews} ulasan',
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

class _MenuItemResultList extends StatefulWidget {
  final String query;
  final String? categoryId;
  final bool discountOnly;
  final bool freeDeliveryOnly;

  const _MenuItemResultList({
    required this.query,
    required this.categoryId,
    required this.discountOnly,
    required this.freeDeliveryOnly,
  });

  @override
  State<_MenuItemResultList> createState() => _MenuItemResultListState();
}

class _MenuItemResultListState extends State<_MenuItemResultList> {
  List<ProductSearchResult> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MenuItemResultList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query ||
        oldWidget.categoryId != widget.categoryId ||
        oldWidget.discountOnly != widget.discountOnly ||
        oldWidget.freeDeliveryOnly != widget.freeDeliveryOnly) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      _results = await api.searchProducts(
        q: widget.query,
        foodCategoryId: widget.categoryId,
        discount: widget.discountOnly,
        freeDelivery: widget.freeDeliveryOnly,
      );
    } catch (e) {
      _error = 'Gagal memuat menu';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: KuwrirColors.textSecondary)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('Tidak ada menu yang cocok',
            style: TextStyle(color: KuwrirColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _results.length,
      itemBuilder: (context, i) => _MenuItemCard(result: _results[i]),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final ProductSearchResult result;

  const _MenuItemCard({required this.result});

  String _formatPrice(double price) {
    if (price >= 1000) {
      return 'Rp ${(price / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp ${price.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final product = result.product;
    final hasDiscount = product.discountPrice != null && product.discountPrice! > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/merchant',
              arguments: {'id': result.merchantId, 'name': result.merchantName}),
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
                        color: KuwrirColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: product.imageUrl != null
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.restaurant, color: KuwrirColors.primary),
                            )
                          : Icon(Icons.restaurant, color: KuwrirColors.primary),
                    ),
                    if (hasDiscount)
                      Positioned(
                        top: -4,
                        left: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: KuwrirColors.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'DISKON',
                            style: TextStyle(
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
                        product.name,
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
                              result.merchantName,
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
                      if (product.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: KuwrirColors.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (hasDiscount)
                            Text(
                              _formatPrice(product.price),
                              style: TextStyle(
                                fontSize: 11,
                                color: KuwrirColors.textHint,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          if (hasDiscount) const SizedBox(width: 4),
                          Text(
                            _formatPrice(hasDiscount ? product.discountPrice! : product.price),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: KuwrirColors.primary,
                            ),
                          ),
                          const Spacer(),
                          if (!result.merchantIsOpen)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text('Tutup',
                                  style: TextStyle(fontSize: 10, color: Colors.grey)),
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
