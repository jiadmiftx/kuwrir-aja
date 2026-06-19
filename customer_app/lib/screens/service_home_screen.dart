import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'service_booking_screen.dart';

// ─── Mock data ────────────────────────────────────────────────────────────────

class _ServiceMerchant {
  final String id, name, category, address, description;
  final double rating, lat, lng;
  final int totalReviews;
  final List<_ServiceItem> services;

  const _ServiceMerchant({
    required this.id, required this.name, required this.category,
    required this.address, required this.description,
    required this.rating, required this.totalReviews,
    required this.lat, required this.lng,
    required this.services,
  });
}

class _ServiceItem {
  final String id, name, description, priceUnit, durationEstimate;
  final double price;
  const _ServiceItem({
    required this.id, required this.name, required this.description,
    required this.price, required this.priceUnit, required this.durationEstimate,
  });
}

// Mock service merchants — in production fetched from GET /service-merchants
final _mockMerchants = [
  _ServiceMerchant(
    id: 'laundry-1', name: 'Laundry Bersih Kilat', category: 'laundry',
    address: 'Jl. Kuta No. 12, Lombok', description: 'Laundry kilat 1 hari, antar jemput gratis',
    rating: 4.8, totalReviews: 124, lat: -8.8953, lng: 116.2833,
    services: [
      _ServiceItem(id: 's1', name: 'Cuci + Setrika', description: 'Cuci bersih + disetrika rapi', price: 8000, priceUnit: 'per_kg', durationEstimate: '1 hari'),
      _ServiceItem(id: 's2', name: 'Cuci Kering', description: 'Cuci tanpa setrika', price: 5000, priceUnit: 'per_kg', durationEstimate: '1 hari'),
      _ServiceItem(id: 's3', name: 'Express (6 jam)', description: 'Selesai dalam 6 jam', price: 12000, priceUnit: 'per_kg', durationEstimate: '6 jam'),
      _ServiceItem(id: 's4', name: 'Cuci Sepatu', description: 'Sepatu dibersihkan manual', price: 35000, priceUnit: 'per_item', durationEstimate: '2 hari'),
    ],
  ),
  _ServiceMerchant(
    id: 'bengkel-1', name: 'Bengkel Motor Pak Dedi', category: 'bengkel',
    address: 'Jl. Raya Kuta No. 45, Lombok', description: 'Servis motor panggilan, teknisi berpengalaman',
    rating: 4.6, totalReviews: 87, lat: -8.8970, lng: 116.2850,
    services: [
      _ServiceItem(id: 's5', name: 'Servis Ringan', description: 'Ganti oli + filter + cek rem', price: 85000, priceUnit: 'per_service', durationEstimate: '1-2 jam'),
      _ServiceItem(id: 's6', name: 'Ganti Oli', description: 'Ganti oli mesin + filter oli', price: 45000, priceUnit: 'per_service', durationEstimate: '30 menit'),
      _ServiceItem(id: 's7', name: 'Tune Up', description: 'Tune up lengkap busi + karburator + rem', price: 150000, priceUnit: 'per_service', durationEstimate: '2-3 jam'),
      _ServiceItem(id: 's8', name: 'Tambal Ban', description: 'Tambal ban tubeless/biasa', price: 25000, priceUnit: 'per_item', durationEstimate: '30 menit'),
    ],
  ),
  _ServiceMerchant(
    id: 'cleaning-1', name: 'Clean Pro Lombok', category: 'cleaning',
    address: 'Jl. Pariwisata No. 8, Lombok', description: 'Jasa cuci AC, kamar mandi, rumah',
    rating: 4.7, totalReviews: 56, lat: -8.8940, lng: 116.2820,
    services: [
      _ServiceItem(id: 's9', name: 'Cuci AC (1 unit)', description: 'Cuci filter + coil AC split', price: 120000, priceUnit: 'per_service', durationEstimate: '1 jam'),
      _ServiceItem(id: 's10', name: 'Bersih Kamar Mandi', description: 'Deep cleaning kamar mandi', price: 100000, priceUnit: 'per_service', durationEstimate: '2 jam'),
    ],
  ),
  _ServiceMerchant(
    id: 'salon-1', name: 'Salon Kecantikan Dewi', category: 'salon',
    address: 'Jl. Pantai Kuta No. 3, Lombok', description: 'Salon panggilan ke rumah',
    rating: 4.9, totalReviews: 203, lat: -8.8960, lng: 116.2840,
    services: [
      _ServiceItem(id: 's11', name: 'Creambath + Blow', description: 'Perawatan rambut lengkap', price: 150000, priceUnit: 'per_service', durationEstimate: '1.5 jam'),
      _ServiceItem(id: 's12', name: 'Manicure + Pedicure', description: 'Perawatan kuku tangan & kaki', price: 120000, priceUnit: 'per_service', durationEstimate: '1 jam'),
    ],
  ),
];

// ─── Category definitions ─────────────────────────────────────────────────────

const _categories = [
  (id: 'all',      label: 'Semua',    emoji: '🔍'),
  (id: 'laundry',  label: 'Laundry',  emoji: '👕'),
  (id: 'bengkel',  label: 'Bengkel',  emoji: '🔧'),
  (id: 'cleaning', label: 'Cleaning', emoji: '🧹'),
  (id: 'salon',    label: 'Salon',    emoji: '💇'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class ServiceHomeScreen extends StatefulWidget {
  const ServiceHomeScreen({super.key});

  @override
  State<ServiceHomeScreen> createState() => _ServiceHomeScreenState();
}

class _ServiceHomeScreenState extends State<ServiceHomeScreen> {
  String _selectedCategory = 'all';

  List<_ServiceMerchant> get _filtered => _selectedCategory == 'all'
      ? _mockMerchants
      : _mockMerchants.where((m) => m.category == _selectedCategory).toList();

  String _fmt(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jasa Panggilan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat.id == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${cat.emoji} ${cat.label}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCategory = cat.id),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? const Center(child: Text('Tidak ada merchant jasa di kategori ini', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _buildMerchantCard(_filtered[i]),
            ),
    );
  }

  Widget _buildMerchantCard(_ServiceMerchant m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ServiceBookingScreen(merchant: m)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner placeholder
            Container(
              height: 120,
              color: _categoryColor(m.category).withOpacity(0.15),
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_categoryEmoji(m.category), style: const TextStyle(fontSize: 40)),
                  Text(m.category.toUpperCase(), style: TextStyle(color: _categoryColor(m.category), fontWeight: FontWeight.bold, letterSpacing: 1)),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      Icon(Icons.star, size: 16, color: Colors.amber.shade600),
                      const SizedBox(width: 2),
                      Text('${m.rating}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(' (${m.totalReviews})', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(m.description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text('📍 ${m.address}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  // Preview top 2 services
                  ...m.services.take(2).map((s) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Expanded(child: Text(s.name, style: const TextStyle(fontSize: 13))),
                      Text(
                        '${_fmt(s.price)}/${s.priceUnit == 'per_kg' ? 'kg' : s.priceUnit == 'per_item' ? 'item' : 'jasa'}',
                        style: TextStyle(fontSize: 13, color: KuwrirColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  )),
                  if (m.services.length > 2)
                    Text('+${m.services.length - 2} layanan lainnya', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceBookingScreen(merchant: m))),
                      child: const Text('Pesan Sekarang'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String cat) {
    const colors = {'laundry': Colors.blue, 'bengkel': Colors.orange, 'cleaning': Colors.green, 'salon': Colors.purple};
    return colors[cat] ?? KuwrirColors.primary;
  }

  String _categoryEmoji(String cat) {
    const emojis = {'laundry': '👕', 'bengkel': '🔧', 'cleaning': '🧹', 'salon': '💇'};
    return emojis[cat] ?? '🔧';
  }
}

// Re-export _ServiceMerchant and _ServiceItem for booking screen
// ignore: library_private_types_in_public_api
typedef ServiceMerchantData = _ServiceMerchant;
// ignore: library_private_types_in_public_api
typedef ServiceItemData = _ServiceItem;
