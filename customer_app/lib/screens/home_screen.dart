import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/merchant_list_cubit.dart';
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
    context.read<MerchantListCubit>().loadMerchants();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      body: RefreshIndicator(
        onRefresh: () => context.read<MerchantListCubit>().loadMerchants(),
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader()),

            // ── Service Menu ────────────────────────────────────────
            SliverToBoxAdapter(child: _buildServiceMenu()),

            // ── Promo Banner ────────────────────────────────────────
            SliverToBoxAdapter(child: _buildPromoBanner()),

            // ── CoFood Section Title ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Restoran Terdekat',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/search'),
                      child: const Text('Lihat semua'),
                    ),
                  ],
                ),
              ),
            ),

            // ── Merchant List ───────────────────────────────────────
            BlocBuilder<MerchantListCubit, MerchantListState>(
              builder: (context, state) {
                if (state is MerchantListLoading) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (state is MerchantListError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(state.message,
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () =>
                                context.read<MerchantListCubit>().loadMerchants(),
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (state is MerchantListLoaded) {
                  if (state.merchants.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                            child: Text('Belum ada restoran di area ini',
                                style: TextStyle(color: Colors.grey))),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final m = state.merchants[index];
                          return _MerchantCard(
                            merchant: m,
                            onTap: () => Navigator.pushNamed(context, '/merchant',
                                arguments: {'id': m.id, 'name': m.name}),
                          );
                        },
                        childCount: state.merchants.length,
                      ),
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),
          ],
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
          // Location row + profile icon
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
          // Search bar
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

  Widget _buildServiceMenu() {
    final services = [
      _Service('CoFood', Icons.restaurant_menu, KuwrirColors.primary, '/search'),
      _Service('Courier', Icons.delivery_dining, const Color(0xFF1976D2), null),
      _Service('Cocar', Icons.directions_car, const Color(0xFF6A1B9A), null),
      _Service('CoSend', Icons.send_rounded, const Color(0xFFE65100), null),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: services.map((s) => _ServiceIcon(service: s)).toList(),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 130,
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
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('PROMO',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                const Text('Gratis Ongkir\nPesanan Pertama!',
                    style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Service {
  final String label;
  final IconData icon;
  final Color color;
  final String? route;
  const _Service(this.label, this.icon, this.color, this.route);
}

class _ServiceIcon extends StatelessWidget {
  final _Service service;
  const _ServiceIcon({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (service.route != null) {
          Navigator.pushNamed(context, service.route!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${service.label} segera hadir!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: service.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(service.icon, color: service.color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(service.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Merchant Card ────────────────────────────────────────────────────────────

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
            // Banner image
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
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      if (!merchant.isOpen)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('Tutup',
                              style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                        Icon(Icons.location_on_outlined,
                            size: 13, color: KuwrirColors.textSecondary),
                        const SizedBox(width: 2),
                        Text('${merchant.distanceKm!.toStringAsFixed(1)} km',
                            style: TextStyle(
                                fontSize: 11, color: KuwrirColors.textSecondary)),
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
