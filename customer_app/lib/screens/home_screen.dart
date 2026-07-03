import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/home_cubit.dart';
import '../cubits/location_cubit.dart';
import 'location_picker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final loc = context.read<LocationCubit>().state;
    context.read<HomeCubit>().load(lat: loc.lat, lng: loc.lng);
  }

  Future<void> _openLocationPicker(LocationState loc) async {
    final initial = loc.hasLocation ? LatLng(loc.lat!, loc.lng!) : null;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: initial)),
    );
    if (result != null && context.mounted) {
      final latlng = result['latlng'] as LatLng;
      final address = result['address'] as String;
      await context.read<LocationCubit>().setLocation(
            latlng.latitude, latlng.longitude, address);
      if (context.mounted) {
        context.read<HomeCubit>().load(lat: latlng.latitude, lng: latlng.longitude);
      }
    }
  }

  Future<void> _refresh() async {
    final loc = context.read<LocationCubit>().state;
    await context.read<HomeCubit>().load(lat: loc.lat, lng: loc.lng);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, LocationState>(
      listenWhen: (prev, curr) => !prev.hasLocation && curr.hasLocation,
      listener: (context, loc) => context.read<HomeCubit>().load(lat: loc.lat, lng: loc.lng),
      child: Scaffold(
        backgroundColor: KuwrirColors.background,
        body: RefreshIndicator(
          onRefresh: _refresh,
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
                            Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(state.message, style: const TextStyle(color: Colors.grey)),
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
                      if (loaded.promotions.isNotEmpty) _PromoCarousel(promotions: loaded.promotions),
                      if (loaded.categories.isNotEmpty)
                        _CategoryChips(
                          categories: loaded.categories,
                          selectedId: loaded.selectedCategoryId,
                          onSelect: (id) => context.read<HomeCubit>().selectCategory(id),
                        ),
                      _SectionHeader(title: 'Warung Terdekat'),
                      _NearbySection(merchants: loaded.nearby),
                      const SizedBox(height: 8),
                      _SectionHeader(title: 'Warung Rating Tertinggi'),
                      _PopularSection(merchants: loaded.popular),
                      const SizedBox(height: 24),
                    ]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: KuwrirColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BlocBuilder<LocationCubit, LocationState>(
                  builder: (context, loc) {
                    return GestureDetector(
                      onTap: () => _openLocationPicker(loc),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: loc.detecting
                                ? const Text('Mendeteksi lokasi...',
                                    style: TextStyle(color: Colors.white70, fontSize: 13))
                                : Text(
                                    loc.address,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Mau pesan apa hari ini?',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/search'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text('Cari restoran atau menu...',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Promo carousel ──────────────────────────────────────────────────────────
// Real active coupons from the backend (GET /promotions/active). Section
// simply doesn't render when there are none — no fabricated fallback copy.

class _PromoCarousel extends StatefulWidget {
  final List<Promotion> promotions;
  const _PromoCarousel({required this.promotions});

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _valueLabel(Promotion p) {
    switch (p.type) {
      case 'percentage':
        return 'Diskon ${p.value.toStringAsFixed(0)}%';
      case 'fixed':
        return 'Potongan Rp ${p.value.toStringAsFixed(0)}';
      case 'free_delivery':
        return 'Gratis Ongkir';
      default:
        return p.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.promotions.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final promo = widget.promotions[i];
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [KuwrirColors.primary, KuwrirColors.primaryLight],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(Icons.local_offer,
                          size: 110, color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: KuwrirColors.warning,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(promo.code,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          Text(_valueLabel(promo),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
                          const SizedBox(height: 2),
                          Text(promo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.promotions.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.promotions.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? KuwrirColors.primary : KuwrirColors.border,
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

// ── Category chips ──────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final List<FoodCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _CategoryChips({required this.categories, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final c = categories[i];
            final selected = c.id == selectedId;
            return GestureDetector(
              onTap: () => onSelect(selected ? null : c.id),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: selected ? KuwrirColors.primary : KuwrirColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: selected ? Border.all(color: KuwrirColors.primary, width: 2) : null,
                    ),
                    child: Center(
                      child: Text(c.icon?.isNotEmpty == true ? c.icon! : '🍽️',
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(c.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? KuwrirColors.primary : KuwrirColors.textSecondary,
                      )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: KuwrirColors.textPrimary)),
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
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text('Belum ada warung di sekitar lokasimu',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text('Belum ada warung dengan rating di area ini',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: merchants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
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

// ── Merchant Card (vertical, full width — Nearby) ───────────────────────────

class _MerchantCard extends StatelessWidget {
  final Merchant merchant;
  final VoidCallback onTap;
  const _MerchantCard({required this.merchant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 130,
              width: double.infinity,
              color: KuwrirColors.primary.withValues(alpha: 0.08),
              child: merchant.logoUrl != null
                  ? Image.network(merchant.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.store, size: 48, color: KuwrirColors.primary)))
                  : Center(child: Icon(Icons.store, size: 48, color: KuwrirColors.primary)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
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
                              color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                          child: const Text('Tutup', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 160,
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
                padding: const EdgeInsets.all(10),
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
      ),
    );
  }
}
