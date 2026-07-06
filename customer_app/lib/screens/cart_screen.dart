import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/cart_cubit.dart';
import '../cubits/order_cubit.dart';
import '../cubits/location_cubit.dart';
import 'location_picker_screen.dart';
import 'addresses_screen.dart';
import '../utils/auth_guard.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addressCtrl = TextEditingController();
  final _receiverCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentType = 'cash';
  double _dropoffLat = 0;
  double _dropoffLng = 0;

  @override
  void initState() {
    super.initState();
    // Pre-fill delivery address from user's saved location
    final loc = context.read<LocationCubit>().state;
    if (loc.hasLocation) {
      _addressCtrl.text = loc.address;
      _dropoffLat = loc.lat!;
      _dropoffLng = loc.lng!;
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _receiverCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is OrderPlaced) {
          context.read<CartCubit>().clear();
          Navigator.pushReplacementNamed(context, '/tracking',
              arguments: {'order_id': state.order.id});
        } else if (state is OrderError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          context.read<OrderCubit>().reset();
        }
      },
      child: BlocBuilder<CartCubit, CartState>(
        builder: (context, cart) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Keranjang'),
              actions: [
                if (!cart.isEmpty)
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Kosongkan keranjang?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Batal')),
                            TextButton(
                              onPressed: () {
                                context.read<CartCubit>().clear();
                                Navigator.pop(ctx);
                              },
                              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Hapus semua', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            body: cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Keranjang kosong', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Merchant label
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: KuwrirColors.primary.withValues(alpha: 0.05),
                        child: Row(
                          children: [
                            const Icon(Icons.store, size: 18, color: KuwrirColors.primary),
                            const SizedBox(width: 8),
                            Text(cart.merchantName ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),

                      // Item list
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Items
                              ...cart.items.map((item) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item.product.name,
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.w600, fontSize: 14)),
                                                if (item.selectedVariants.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item.selectedVariants.map((v) => v.name).join(', '),
                                                    style: TextStyle(
                                                        fontSize: 12, color: KuwrirColors.textSecondary),
                                                  ),
                                                ],
                                                const SizedBox(height: 4),
                                                Text(
                                                  'IDR ${_fmt(item.unitPrice)}',
                                                  style: const TextStyle(
                                                      color: KuwrirColors.primary,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              _QtyBtn(
                                                icon: Icons.remove,
                                                onTap: () => context.read<CartCubit>().decrementItem(
                                                    item.product.id,
                                                    variantKey: item.variantKey),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                child: Text('${item.quantity}',
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold, fontSize: 16)),
                                              ),
                                              _QtyBtn(
                                                icon: Icons.add,
                                                onTap: () => context.read<CartCubit>().addItem(
                                                      item.product,
                                                      merchantId: cart.merchantId,
                                                      merchantName: cart.merchantName,
                                                      selectedVariants: item.selectedVariants,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),

                              const SizedBox(height: 20),
                              // Delivery address
                              const Text('Alamat Pengiriman',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _addressCtrl,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.location_on_outlined),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  hintText: 'Masukkan alamat pengiriman',
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        if (!await ensureLoggedIn(context) || !mounted) return;
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AddressesScreen(
                                              onPick: (a) {
                                                setState(() {
                                                  _addressCtrl.text = a.address;
                                                  _dropoffLat = a.latitude;
                                                  _dropoffLng = a.longitude;
                                                });
                                                context
                                                    .read<LocationCubit>()
                                                    .setLocation(a.latitude, a.longitude, a.address);
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.bookmark_border, size: 18),
                                      label: const Text('Alamat Tersimpan'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final initial = _dropoffLat != 0
                                            ? LatLng(_dropoffLat, _dropoffLng)
                                            : null;
                                        final result = await Navigator.push<Map<String, dynamic>>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => LocationPickerScreen(initial: initial),
                                          ),
                                        );
                                        if (result != null && mounted) {
                                          final latlng = result['latlng'] as LatLng;
                                          final addr = result['address'] as String;
                                          setState(() {
                                            _dropoffLat = latlng.latitude;
                                            _dropoffLng = latlng.longitude;
                                            _addressCtrl.text = addr;
                                          });
                                          // Update saved location too
                                          if (mounted) {
                                            context.read<LocationCubit>().setLocation(
                                                latlng.latitude, latlng.longitude, addr);
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.map_outlined, size: 18),
                                      label: const Text('Pilih di Peta'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _receiverCtrl,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.person_outline),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                        hintText: 'Nama penerima',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.phone_outlined),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                        hintText: 'No. HP penerima',
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                              // Payment method
                              const Text('Metode Pembayaran',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 8),
                              _PaymentOption(
                                label: 'Cash (COD)',
                                subtitle: 'Bayar tunai ke driver',
                                icon: Icons.payments_outlined,
                                selected: _paymentType == 'cash',
                                onTap: () => setState(() => _paymentType = 'cash'),
                              ),
                              _PaymentOption(
                                label: 'Transfer / QRIS',
                                subtitle: 'Bayar online via Duitku',
                                icon: Icons.qr_code_scanner,
                                selected: _paymentType == 'qris',
                                onTap: () => setState(() => _paymentType = 'qris'),
                              ),

                              const SizedBox(height: 20),
                              // Notes
                              TextField(
                                controller: _notesCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Catatan pesanan (opsional)',
                                  hintText: 'e.g. Pedas sedikit, tanpa bawang...',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),

                      // Summary + Place Order
                      BlocBuilder<OrderCubit, OrderState>(
                        builder: (context, orderState) {
                          final placing = orderState is OrderPlacing;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, -2))
                              ],
                            ),
                            child: Column(
                              children: [
                                _PriceRow(
                                    label: 'Subtotal menu',
                                    amount: cart.subtotal - cart.packagingFeeTotal),
                                if (cart.packagingFeeTotal > 0) ...[
                                  const SizedBox(height: 4),
                                  _PriceRow(
                                      label: 'Biaya kemasan (dari merchant)',
                                      amount: cart.packagingFeeTotal),
                                ],
                                const SizedBox(height: 4),
                                _PriceRow(label: 'Ongkir (estimasi)', amount: 15000),
                                const Divider(height: 12),
                                _PriceRow(
                                    label: 'Est. total',
                                    amount: cart.subtotal + 15000,
                                    isBold: true),
                                const SizedBox(height: 4),
                                Text(
                                  'Harga final + pajak + ongkir dihitung di server',
                                  style: TextStyle(
                                      fontSize: 11, color: KuwrirColors.textHint),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: placing || cart.isEmpty
                                        ? null
                                        : () => _submitOrder(context, cart),
                                    child: placing
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2, color: Colors.white))
                                        : const Text('Pesan Sekarang'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _submitOrder(BuildContext context, CartState cart) async {
    if (!await ensureLoggedIn(context)) return;
    if (!context.mounted) return;
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Masukkan alamat pengiriman')));
      return;
    }
    context.read<OrderCubit>().placeOrder(
          merchantId: cart.merchantId!,
          items: cart.items,
          dropoffAddress: _addressCtrl.text.trim(),
          dropoffLat: _dropoffLat,
          dropoffLng: _dropoffLng,
          receiverName: _receiverCtrl.text.trim(),
          receiverPhone: _phoneCtrl.text.trim(),
          paymentType: _paymentType,
          notes: _notesCtrl.text.trim(),
        );
  }

  String _fmt(double price) => price
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

class _PaymentOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? KuwrirColors.primary : KuwrirColors.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? KuwrirColors.primary : KuwrirColors.textSecondary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? KuwrirColors.primary : null)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
              ],
            ),
            const Spacer(),
            if (selected) const Icon(Icons.check_circle, color: KuwrirColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;

  const _PriceRow({required this.label, required this.amount, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: isBold ? 16 : 14,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: isBold ? null : KuwrirColors.textSecondary,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          'IDR ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
          style: style.copyWith(color: isBold ? KuwrirColors.primary : null),
        ),
      ],
    );
  }
}
