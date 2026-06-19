import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'service_home_screen.dart';
import 'service_tracking_screen.dart';

/// Service booking screen — select services, input weight/qty, set pickup schedule
class ServiceBookingScreen extends StatefulWidget {
  final ServiceMerchantData merchant;
  const ServiceBookingScreen({super.key, required this.merchant});

  @override
  State<ServiceBookingScreen> createState() => _ServiceBookingScreenState();
}

class _ServiceBookingScreenState extends State<ServiceBookingScreen> {
  // Cart: serviceId → quantity
  final Map<String, int> _cart = {};
  final Map<String, double> _customWeight = {}; // for per_kg services

  double _weightKg = 3.0;
  final _addressCtrl = TextEditingController(text: 'Jl. Pantai Kuta No. 5, Lombok');
  final _notesCtrl = TextEditingController();
  DateTime? _scheduledAt;
  bool _loading = false;

  ServiceMerchantData get _merchant => widget.merchant;

  bool get _hasPerKgService => _merchant.services.any(
    (s) => (_cart[s.id] ?? 0) > 0 && s.priceUnit == 'per_kg',
  );

  double _serviceTotal() {
    double total = 0;
    for (final s in _merchant.services) {
      final qty = _cart[s.id] ?? 0;
      if (qty == 0) continue;
      if (s.priceUnit == 'per_kg') {
        total += s.price * _weightKg;
      } else {
        total += s.price * qty;
      }
    }
    return total;
  }

  double _markup() => _serviceTotal() * 0.15;
  double _deliveryFee() => 20000; // round-trip flat
  double _grandTotal() => _serviceTotal() + _markup() + _deliveryFee();

  String _fmt(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';

  int _cartCount() => _cart.values.fold(0, (s, q) => s + q);

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
      helpText: 'Pilih tanggal jemput',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Pilih jam jemput',
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _placeOrder() async {
    if (_cartCount() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu layanan'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat penjemputan wajib diisi'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Confirm dialog
    final confirmed = await _showConfirmDialog();
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      // TODO: POST /service-orders via ApiClient
      await Future.delayed(const Duration(seconds: 1)); // simulate API call

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceTrackingScreen(
            orderNumber: 'SVC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
            merchantName: _merchant.name,
            category: _merchant.category,
            totalCod: _grandTotal(),
            scheduledAt: _scheduledAt,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _showConfirmDialog() => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Konfirmasi Pesanan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_merchant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._merchant.services
              .where((s) => (_cart[s.id] ?? 0) > 0)
              .map((s) {
            final qty = _cart[s.id] ?? 0;
            final price = s.priceUnit == 'per_kg' ? s.price * _weightKg : s.price * qty;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${s.name}${s.priceUnit == 'per_kg' ? ' (${_weightKg}kg)' : ' ×$qty'}'),
                Text(_fmt(price)),
              ]),
            );
          }),
          const Divider(),
          _row('Markup (15%)', _markup()),
          _row('Ongkir PP', _deliveryFee()),
          const Divider(),
          _row('Total COD saat barang kembali', _grandTotal(), bold: true, color: KuwrirColors.primary),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue),
              SizedBox(width: 6),
              Expanded(child: Text('Bayar COD saat kurir mengantar barang kembali', style: TextStyle(fontSize: 12, color: Colors.blue))),
            ]),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pesan')),
      ],
    ),
  );

  Widget _row(String label, double v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(_fmt(v), style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
    ]),
  );

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_merchant.name),
        actions: [
          if (_cartCount() > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text('${_cartCount()} dipilih · ${_fmt(_grandTotal())}'),
                backgroundColor: KuwrirColors.primary.withOpacity(0.1),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Merchant info
            Row(children: [
              Icon(Icons.star, size: 16, color: Colors.amber.shade600),
              const SizedBox(width: 4),
              Text('${_merchant.rating} (${_merchant.totalReviews} ulasan)', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(child: Text(_merchant.address, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 16),

            // Services list
            const Text('Pilih Layanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._merchant.services.map((s) => _buildServiceTile(s)),

            // Weight input for per_kg services
            if (_hasPerKgService) ...[
              const SizedBox(height: 16),
              const Text('Estimasi Berat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Berat (kg)'),
                      Text('${_weightKg.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KuwrirColors.primary)),
                    ]),
                    Slider(
                      value: _weightKg,
                      min: 1, max: 20, divisions: 38,
                      onChanged: (v) => setState(() => _weightKg = (v * 2).round() / 2),
                    ),
                    const Text('Berat estimasi — harga final dihitung saat barang ditimbang', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                  ]),
                ),
              ),
            ],

            // Pickup schedule
            const SizedBox(height: 16),
            const Text('Jadwal Penjemputan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule, color: KuwrirColors.primary),
                title: Text(
                  _scheduledAt != null
                      ? '${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year} pukul ${_scheduledAt!.hour.toString().padLeft(2,'0')}:${_scheduledAt!.minute.toString().padLeft(2,'0')}'
                      : 'Secepatnya (driver akan segera dikirim)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: _scheduledAt != null ? null : const Text('Atau pilih waktu spesifik'),
                trailing: TextButton(
                  onPressed: _pickSchedule,
                  child: Text(_scheduledAt != null ? 'Ubah' : 'Jadwalkan'),
                ),
              ),
            ),

            // Pickup address
            const SizedBox(height: 16),
            const Text('Alamat Penjemputan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                hintText: 'Alamat lengkap untuk jemput barang',
              ),
            ),

            // Notes
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Instruksi Khusus (opsional)',
                hintText: 'e.g. Pisahkan baju putih, ganti oli mesin Castrol',
                prefixIcon: Icon(Icons.note),
              ),
            ),

            // Pricing summary
            const SizedBox(height: 16),
            Card(
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _row('Subtotal layanan', _serviceTotal()),
                  _row('Markup platform (15%)', _markup()),
                  _row('Ongkir antar jemput', _deliveryFee()),
                  const Divider(),
                  _row('Total COD saat barang dikembalikan', _grandTotal(), bold: true, color: KuwrirColors.primary),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.payments_outlined, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    const Text('Bayar tunai saat barang diantar balik ke rumah', style: TextStyle(color: Colors.green, fontSize: 12)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _cartCount() == 0 || _loading ? null : _placeOrder,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _cartCount() == 0
                          ? 'Pilih Layanan Dulu'
                          : 'Pesan — COD ${_fmt(_grandTotal())}',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile(ServiceItemData s) {
    final qty = _cart[s.id] ?? 0;
    final unitLabel = s.priceUnit == 'per_kg' ? '/kg' : s.priceUnit == 'per_item' ? '/item' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(s.description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(_fmt(s.price) + unitLabel, style: TextStyle(color: KuwrirColors.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                      child: Text('⏱ ${s.durationEstimate}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ]),
                ],
              ),
            ),
            // Qty controls
            if (s.priceUnit == 'per_kg')
              // For per-kg, just a toggle (weight controlled via slider)
              Switch(
                value: qty > 0,
                onChanged: (v) => setState(() => _cart[s.id] = v ? 1 : 0),
                activeColor: KuwrirColors.primary,
              )
            else
              Row(children: [
                if (qty > 0) ...[
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: KuwrirColors.primary,
                    onPressed: () => setState(() { _cart[s.id] = qty - 1; if (_cart[s.id] == 0) _cart.remove(s.id); }),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                ],
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: KuwrirColors.primary,
                  onPressed: () => setState(() => _cart[s.id] = qty + 1),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
