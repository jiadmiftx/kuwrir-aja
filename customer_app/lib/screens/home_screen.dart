import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/home_cubit.dart';
import '../cubits/location_cubit.dart';
import '../cubits/session_cubit.dart';
import '../cubits/address_cubit.dart';
import '../widgets/floating_cart_button.dart';
import 'addresses_screen.dart';
import 'banner_detail_screen.dart';
import 'phone_verification_gate.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import '../utils/auth_guard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    final loc = context.read<LocationCubit>().state;
    context.read<HomeCubit>().load(lat: loc.lat, lng: loc.lng);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPhoneVerified());
    _refreshUnreadCount();
    // Only logged-in users have saved addresses — this powers the
    // "Rumah"/"Kantor" label shown in the app bar instead of the raw
    // geocoded address when the active location matches a saved one.
    if (context.read<SessionCubit>().state.user != null) {
      context.read<AddressCubit>().load();
    }
  }

  Future<void> _refreshUnreadCount() async {
    final count = await NotificationService.unreadCount();
    if (mounted) setState(() => _unreadNotifications = count);
  }

  Future<void> _openNotifications() async {
    if (!await ensureLoggedIn(context) || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    _refreshUnreadCount();
  }

  void _checkPhoneVerified() {
    final user = context.read<SessionCubit>().state.user;
    if (user != null && !user.isPhoneVerified) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PhoneVerificationGate(), fullscreenDialog: true),
      );
    }
  }

  Future<void> _useLocation(double lat, double lng, String address) async {
    await context.read<LocationCubit>().setLocation(lat, lng, address);
    if (context.mounted) {
      context.read<HomeCubit>().load(lat: lat, lng: lng);
    }
  }

  /// Tapping the location chip opens the saved-addresses picker first
  /// (matching Gojek's "Pilih alamat" flow — saved places take priority,
  /// with a map pick as the fallback for a one-off destination), instead
  /// of jumping straight into the raw map every time.
  Future<void> _openLocationPicker(LocationState loc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressesScreen(
          onPick: (a) {
            _useLocation(a.latitude, a.longitude, a.address);
            Navigator.pop(context);
          },
          onPickAdHoc: (address, lat, lng) {
            _useLocation(lat, lng, address);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    final loc = context.read<LocationCubit>().state;
    await context.read<HomeCubit>().load(lat: loc.lat, lng: loc.lng);
  }

  /// Finds the saved address (if any) whose pin matches the currently
  /// active [LocationCubit] coordinates, within a small tolerance for
  /// floating point drift — used so the app bar can show "Rumah"/"Kantor"
  /// instead of the raw geocoded address once that saved place is active.
  static const _sameLocationEpsilon = 0.0006; // ~ 60m

  SavedAddress? _matchingSavedAddress(List<SavedAddress> addresses, LocationState loc) {
    if (!loc.hasLocation) return null;
    for (final a in addresses) {
      if ((a.latitude - loc.lat!).abs() < _sameLocationEpsilon &&
          (a.longitude - loc.lng!).abs() < _sameLocationEpsilon) {
        return a;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, LocationState>(
      listenWhen: (prev, curr) => !prev.hasLocation && curr.hasLocation,
      listener: (context, loc) => context.read<HomeCubit>().load(lat: loc.lat, lng: loc.lng),
      child: Scaffold(
        backgroundColor: KuwrirColors.surface,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              color: KuwrirColors.primary,
              child: CustomScrollView(
                slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              BlocBuilder<HomeCubit, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading || state is HomeInitial) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (state is HomeError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.wifi_off, size: 48, color: KuwrirColors.textHint),
                            const SizedBox(height: 16),
                            Text(state.message, style: TextStyle(color: KuwrirColors.textSecondary)),
                            const SizedBox(height: 12),
                            TextButton(onPressed: _refresh, child: const Text('Coba lagi')),
                          ],
                        ),
                      ),
                    );
                  }
                  final loaded = state as HomeLoaded;
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      if (loaded.banners.isNotEmpty)
                        _BannerCarousel(
                          banners: loaded.banners,
                          onTapBanner: (b) => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BannerDetailScreen(banner: b)),
                          ),
                        ),
                      if (loaded.categories.isNotEmpty)
                        _CategorySection(
                          categories: loaded.categories,
                          selectedId: loaded.selectedCategoryId,
                          onSelect: (id) => context.read<HomeCubit>().selectCategory(id),
                        ),
                      if (loaded.trending.isNotEmpty) ...[
                        const _SectionHeader(title: 'Sedang Rame Dipesan', emoji: '🔥'),
                        _TrendingSection(products: loaded.trending),
                        const SizedBox(height: 8),
                      ],
                      _SectionHeader(
                        title: 'Warung Terdekat',
                        onSeeAll: () => Navigator.pushNamed(context, '/search'),
                      ),
                      _NearbySection(merchants: loaded.nearby),
                      const SizedBox(height: 8),
                      _SectionHeader(
                        title: 'Warung Rating Tertinggi',
                        onSeeAll: () => Navigator.pushNamed(context, '/search'),
                      ),
                      _PopularSection(merchants: loaded.popular),
                      const SizedBox(height: 24),
                    ]),
                  );
                },
              ),
            ],
              ),
            ),
            const FloatingCartButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BlocBuilder<AddressCubit, AddressState>(
                  builder: (context, addressState) {
                    final addresses = addressState is AddressLoaded
                        ? addressState.addresses
                        : const <SavedAddress>[];
                    return BlocBuilder<LocationCubit, LocationState>(
                      builder: (context, loc) {
                        // Gojek/Grab-style: once the active location matches
                        // a saved address (picked from the list, or it's the
                        // default and hasn't been overridden), show its
                        // short label ("Rumah") instead of the full geocoded
                        // address string.
                        final matched = _matchingSavedAddress(addresses, loc);
                        final displayAddress = matched?.label ?? loc.address;
                        return GestureDetector(
                      onTap: () => _openLocationPicker(loc),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: KuwrirColors.primary, width: 1.6),
                            ),
                            child: const Icon(Icons.location_on_outlined,
                                color: KuwrirColors.primary, size: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: loc.detecting
                                ? Text('Mendeteksi lokasi...',
                                    style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 14))
                                : Text(
                                    displayAddress,
                                    style: const TextStyle(
                                        color: KuwrirColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded, color: KuwrirColors.textSecondary),
                        ],
                      ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openNotifications,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: KuwrirColors.border),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: KuwrirColors.background,
                        child: Icon(Icons.notifications_outlined, color: KuwrirColors.primary, size: 19),
                      ),
                      if (_unreadNotifications > 0)
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: KuwrirColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: KuwrirColors.surface, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  if (await ensureLoggedIn(context) && context.mounted) {
                    Navigator.pushNamed(context, '/profile');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: KuwrirColors.border),
                  ),
                  child: const CircleAvatar(
                    radius: 17,
                    backgroundColor: KuwrirColors.background,
                    child: Icon(Icons.person, color: KuwrirColors.primary, size: 19),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/search'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: KuwrirColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KuwrirColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: KuwrirColors.textHint, size: 20),
                  const SizedBox(width: 10),
                  Text('Cari warung atau menu...',
                      style: TextStyle(color: KuwrirColors.textHint, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner carousel ──────────────────────────────────────────────────────────
// Admin-managed image banners (GET /banners/active). Hidden entirely when
// there are none — no fabricated placeholder promo.

class _BannerCarousel extends StatefulWidget {
  final List<PromoBanner> banners;
  final ValueChanged<PromoBanner> onTapBanner;
  const _BannerCarousel({required this.banners, required this.onTapBanner});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

// Large multiple of any banner count so the user can swipe backward
// indefinitely too, not just forward — true index is `virtualPage % length`.
const _kInfiniteMultiplier = 10000;

class _BannerCarouselState extends State<_BannerCarousel> {
  late final PageController _controller;
  late int _page;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _page = _kInfiniteMultiplier * widget.banners.length ~/ 2;
    _controller = PageController(viewportFraction: 0.92, initialPage: _page);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.banners.length < 2) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 192,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.isEmpty ? 0 : _kInfiniteMultiplier * widget.banners.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _startAutoPlay(); // restart the countdown so a manual swipe doesn't get cut short
            },
            itemBuilder: (context, i) {
              final banner = widget.banners[i % widget.banners.length];
              return GestureDetector(
                onTap: () => widget.onTapBanner(banner),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: KuwrirColors.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (banner.imageUrl != null)
                        Image.network(
                          banner.imageUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      // Bottom-anchored scrim, not left-to-right — the
                      // content (title/subtitle bottom-left, CTA
                      // bottom-right) all lives in the bottom band now, so
                      // that's the region that needs to stay legible over
                      // any image, regardless of horizontal position.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          // Same hue as KuwrirColors.primaryDark (0xFF004024)
                          // at rising alpha — can't call .withValues() in a
                          // const context, so the stops are spelled out.
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x1A004024),
                              Color(0xE6004024),
                            ],
                            stops: [0.25, 0.6, 1.0],
                          ),
                        ),
                      ),
                      // Title/subtitle anchored bottom-left, CTA anchored
                      // bottom-right — two independent Positioned blocks
                      // instead of one stacked Column, so the button reads
                      // as a distinct tap target rather than just the last
                      // line of text.
                      Positioned(
                        left: 22,
                        right: banner.foodCategoryId != null ? 108 : 22,
                        bottom: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(banner.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    height: 1.15)),
                            if (banner.subtitle?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(banner.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12.5,
                                      height: 1.15)),
                            ],
                          ],
                        ),
                      ),
                      if (banner.foodCategoryId != null)
                        Positioned(
                          right: 18,
                          bottom: 18,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 90),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(banner.ctaText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: KuwrirColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page % widget.banners.length ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page % widget.banners.length ? KuwrirColors.primary : KuwrirColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Category section ─────────────────────────────────────────────────────────

// Rotating swatch of existing brand tokens (not arbitrary new hex values) so
// each category chip gets its own soft tint instead of one flat repeated
// color — a small, deliberate touch of variety for a food app that should
// feel appetizing, not a rainbow of unrelated colors.
const _kCategorySwatches = [
  KuwrirColors.primary,
  KuwrirColors.warning,
  KuwrirColors.accent,
  KuwrirColors.info,
  KuwrirColors.secondary,
];

class _CategorySection extends StatelessWidget {
  final List<FoodCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _CategorySection({required this.categories, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Kategori', topPadding: 24),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final c = categories[i];
              final selected = c.id == selectedId;
              final swatch = _kCategorySwatches[i % _kCategorySwatches.length];
              return GestureDetector(
                onTap: () => onSelect(selected ? null : c.id),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? swatch : swatch.withValues(alpha: 0.12),
                        border: selected ? Border.all(color: swatch, width: 2) : null,
                        boxShadow: selected
                            ? [BoxShadow(color: swatch.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))]
                            : null,
                      ),
                      child: Center(
                        child: Text(c.icon?.isNotEmpty == true ? c.icon! : '🍽️',
                            style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(c.name,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          color: selected ? swatch : KuwrirColors.textSecondary,
                        )),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final double topPadding;
  final String? emoji;
  const _SectionHeader({required this.title, this.onSeeAll, this.topPadding = 20, this.emoji});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 17)),
                const SizedBox(width: 6),
              ],
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold, color: KuwrirColors.textPrimary)),
            ],
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text('Lihat Semua',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: KuwrirColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: KuwrirColors.primary)),
            ),
        ],
      ),
    );
  }
}

// ── Nearby section (vertical, real distance) ────────────────────────────────

class _NearbySection extends StatelessWidget {
  final List<Merchant> merchants;
  const _NearbySection({required this.merchants});

  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text('Belum ada warung di sekitar lokasimu',
            style: TextStyle(color: KuwrirColors.textSecondary)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: merchants
            .map((m) => _MerchantCard(
                  merchant: m,
                  onTap: () => Navigator.pushNamed(context, '/merchant',
                      arguments: {'id': m.id, 'name': m.name}),
                ))
            .toList(),
      ),
    );
  }
}

// ── Popular section (horizontal, real rating) ───────────────────────────────

class _PopularSection extends StatelessWidget {
  final List<Merchant> merchants;
  const _PopularSection({required this.merchants});

  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text('Belum ada warung dengan rating di area ini',
            style: TextStyle(color: KuwrirColors.textSecondary)),
      );
    }
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: merchants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final m = merchants[i];
          return _MerchantCardCompact(
            merchant: m,
            onTap: () => Navigator.pushNamed(context, '/merchant',
                arguments: {'id': m.id, 'name': m.name}),
          );
        },
      ),
    );
  }
}

// ── Trending section (horizontal, most-ordered products) ───────────────────

class _TrendingSection extends StatelessWidget {
  final List<ProductSearchResult> products;
  const _TrendingSection({required this.products});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) => _TrendingProductCard(result: products[i]),
      ),
    );
  }
}

class _TrendingProductCard extends StatelessWidget {
  final ProductSearchResult result;
  const _TrendingProductCard({required this.result});

  String _fmtPrice(double v) => v >= 1000 ? 'Rp ${(v / 1000).toStringAsFixed(0)}rb' : 'Rp ${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final product = result.product;
    final hasDiscount = product.discountPrice != null && product.discountPrice! > 0;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/merchant',
          arguments: {'id': result.merchantId, 'name': result.merchantName}),
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: KuwrirColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KuwrirColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  color: KuwrirColors.primary.withValues(alpha: 0.08),
                  child: product.imageUrl != null
                      ? Image.network(product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Center(child: Icon(Icons.restaurant, color: KuwrirColors.primary)))
                      : Center(child: Icon(Icons.restaurant, color: KuwrirColors.primary)),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: KuwrirColors.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('DISKON',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(result.merchantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: KuwrirColors.textSecondary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (hasDiscount) ...[
                        Text(_fmtPrice(product.price),
                            style: TextStyle(
                                fontSize: 10.5,
                                color: KuwrirColors.textHint,
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 4),
                      ],
                      Text(_fmtPrice(hasDiscount ? product.discountPrice! : product.price),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: KuwrirColors.primary)),
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

// ── Merchant Card (vertical, full width — Nearby) ───────────────────────────

class _MerchantCard extends StatelessWidget {
  final Merchant merchant;
  final VoidCallback onTap;
  const _MerchantCard({required this.merchant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: KuwrirColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: KuwrirColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  color: KuwrirColors.primary.withValues(alpha: 0.08),
                  child: (merchant.bannerUrl ?? merchant.logoUrl) != null
                      ? Image.network((merchant.bannerUrl ?? merchant.logoUrl)!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.store, size: 48, color: KuwrirColors.primary)))
                      : Center(child: Icon(Icons.store, size: 48, color: KuwrirColors.primary)),
                ),
                if (merchant.bannerUrl != null)
                  Positioned(
                    left: 14,
                    bottom: -18,
                    child: Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: KuwrirColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: ClipOval(
                        child: merchant.logoUrl != null
                            ? Image.network(merchant.logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    color: KuwrirColors.primary.withValues(alpha: 0.08),
                                    child: Icon(Icons.store, size: 20, color: KuwrirColors.primary)))
                            : Container(
                                color: KuwrirColors.primary.withValues(alpha: 0.08),
                                child: Icon(Icons.store, size: 20, color: KuwrirColors.primary)),
                      ),
                    ),
                  ),
              ],
            ),
            if (merchant.bannerUrl != null) const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(merchant.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      if (!merchant.isOpen)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: KuwrirColors.textHint.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(100)),
                          child: Text('Tutup',
                              style: TextStyle(fontSize: 11, color: KuwrirColors.textSecondary, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(merchant.address,
                      style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: Colors.amber[600]),
                      const SizedBox(width: 2),
                      Text(merchant.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(' (${merchant.totalReviews})',
                          style: TextStyle(fontSize: 11, color: KuwrirColors.textSecondary)),
                      if (merchant.distanceKm != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.location_on_outlined, size: 13, color: KuwrirColors.textSecondary),
                        const SizedBox(width: 2),
                        Text('${merchant.distanceKm!.toStringAsFixed(1)} km',
                            style: TextStyle(fontSize: 11, color: KuwrirColors.textSecondary)),
                      ],
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

// ── Merchant Card (compact, fixed width — Rating Tertinggi carousel) ───────

class _MerchantCardCompact extends StatelessWidget {
  final Merchant merchant;
  final VoidCallback onTap;
  const _MerchantCardCompact({required this.merchant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: KuwrirColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: KuwrirColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              width: double.infinity,
              color: KuwrirColors.primary.withValues(alpha: 0.08),
              child: merchant.logoUrl != null
                  ? Image.network(merchant.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.store, size: 36, color: KuwrirColors.primary)))
                  : Center(child: Icon(Icons.store, size: 36, color: KuwrirColors.primary)),
            ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(merchant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: Colors.amber[600]),
                      const SizedBox(width: 2),
                      Text(merchant.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text(' (${merchant.totalReviews})',
                          style: TextStyle(fontSize: 10, color: KuwrirColors.textSecondary)),
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
