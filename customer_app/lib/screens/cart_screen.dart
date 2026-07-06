import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/cart_cubit.dart';
import '../cubits/location_cubit.dart';
import 'location_picker_screen.dart';
import 'addresses_screen.dart';
import 'order_summary_screen.dart';
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
    super.dispose();
  }

  Future<void> _editItemNotes(CartItem item) async {
    final ctrl = TextEditingController(text: item.notes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Catatan untuk ${item.product.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'cth. Pedas sedikit, tanpa bawang...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      context.read<CartCubit>().updateNotes(
        item.product.id,
        ctrl.text.trim(),
        variantKey: item.variantKey,
      );
    }
  }

  Future<void> _confirmClearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kosongkan keranjang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: KuwrirColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) context.read<CartCubit>().clear();
  }

  Future<void> _goToSummary(CartState cart) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan alamat pengiriman')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSummaryScreen(
          merchantId: cart.merchantId!,
          merchantName: cart.merchantName ?? '',
          items: cart.items,
          dropoffAddress: _addressCtrl.text.trim(),
          dropoffLat: _dropoffLat,
          dropoffLng: _dropoffLng,
          receiverName: _receiverCtrl.text.trim(),
          receiverPhone: _phoneCtrl.text.trim(),
          notes: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) {
        return Scaffold(
          backgroundColor: KuwrirColors.background,
          appBar: AppBar(
            title: const Text('Keranjang'),
            backgroundColor: KuwrirColors.background,
            actions: [
              if (!cart.isEmpty)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: KuwrirColors.error),
                  tooltip: 'Kosongkan keranjang',
                  onPressed: _confirmClearCart,
                ),
            ],
          ),
          body: cart.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: KuwrirColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            size: 36,
                            color: KuwrirColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Keranjang kosong',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: KuwrirColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Yuk mulai belanja dari warung favoritmu',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: KuwrirColors.textHint, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Merchant label
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: KuwrirColors.surface,
                        border: Border(
                          bottom: BorderSide(color: KuwrirColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: KuwrirColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.storefront_outlined,
                              size: 17,
                              color: KuwrirColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cart.merchantName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Item list
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PESANAN',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: KuwrirColors.textHint,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Items
                            ...cart.items.map(
                              (item) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: KuwrirColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: KuwrirColors.border,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: KuwrirColors.textPrimary
                                          .withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.product.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14.5,
                                                  ),
                                                ),
                                                if (item
                                                    .selectedVariants
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    item.selectedVariants
                                                        .map((v) => v.name)
                                                        .join(', '),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: KuwrirColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 5),
                                                Text(
                                                  'Rp ${_fmt(item.unitPrice)}',
                                                  style: const TextStyle(
                                                    color: KuwrirColors.primary,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: KuwrirColors.background,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: KuwrirColors.border,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                _QtyBtn(
                                                  icon: Icons.remove,
                                                  onTap: () => context
                                                      .read<CartCubit>()
                                                      .decrementItem(
                                                        item.product.id,
                                                        variantKey:
                                                            item.variantKey,
                                                      ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ),
                                                  child: Text(
                                                    '${item.quantity}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 14.5,
                                                    ),
                                                  ),
                                                ),
                                                _QtyBtn(
                                                  icon: Icons.add,
                                                  onTap: () => context
                                                      .read<CartCubit>()
                                                      .addItem(
                                                        item.product,
                                                        merchantId:
                                                            cart.merchantId,
                                                        merchantName:
                                                            cart.merchantName,
                                                        selectedVariants: item
                                                            .selectedVariants,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Divider(height: 1, color: KuwrirColors.border),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () => _editItemNotes(item),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit_note,
                                                size: 16,
                                                color: KuwrirColors.textHint,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  item.notes != null &&
                                                          item.notes!
                                                              .trim()
                                                              .isNotEmpty
                                                      ? item.notes!
                                                      : 'Tambah catatan untuk item ini',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        item.notes != null &&
                                                            item.notes!
                                                                .trim()
                                                                .isNotEmpty
                                                        ? KuwrirColors
                                                              .textSecondary
                                                        : KuwrirColors.textHint,
                                                    fontStyle:
                                                        item.notes != null &&
                                                            item.notes!
                                                                .trim()
                                                                .isNotEmpty
                                                        ? FontStyle.italic
                                                        : FontStyle.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),
                            // Delivery address
                            Text(
                              'ALAMAT PENGIRIMAN',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: KuwrirColors.textHint,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: KuwrirColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: KuwrirColors.border),
                              ),
                              child: TextField(
                                controller: _addressCtrl,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.location_on_outlined,
                                    color: KuwrirColors.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: false,
                                  hintText: 'Masukkan alamat pengiriman',
                                  hintStyle: TextStyle(color: KuwrirColors.textHint),
                                ),
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      if (!await ensureLoggedIn(context) ||
                                          !mounted)
                                        return;
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
                                                  .setLocation(
                                                    a.latitude,
                                                    a.longitude,
                                                    a.address,
                                                  );
                                              Navigator.pop(context);
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(color: KuwrirColors.border),
                                      foregroundColor: KuwrirColors.textPrimary,
                                    ),
                                    icon: Icon(
                                      Icons.bookmark_border,
                                      size: 18,
                                      color: KuwrirColors.primary,
                                    ),
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
                                      final result =
                                          await Navigator.push<
                                            Map<String, dynamic>
                                          >(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  LocationPickerScreen(
                                                    initial: initial,
                                                  ),
                                            ),
                                          );
                                      if (result != null && mounted) {
                                        final latlng =
                                            result['latlng'] as LatLng;
                                        final addr =
                                            result['address'] as String;
                                        setState(() {
                                          _dropoffLat = latlng.latitude;
                                          _dropoffLng = latlng.longitude;
                                          _addressCtrl.text = addr;
                                        });
                                        // Update saved location too
                                        if (mounted) {
                                          context
                                              .read<LocationCubit>()
                                              .setLocation(
                                                latlng.latitude,
                                                latlng.longitude,
                                                addr,
                                              );
                                        }
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(color: KuwrirColors.border),
                                      foregroundColor: KuwrirColors.textPrimary,
                                    ),
                                    icon: Icon(
                                      Icons.map_outlined,
                                      size: 18,
                                      color: KuwrirColors.primary,
                                    ),
                                    label: const Text('Pilih di Peta'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'PENERIMA',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: KuwrirColors.textHint,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: KuwrirColors.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: KuwrirColors.border),
                                    ),
                                    child: TextField(
                                      controller: _receiverCtrl,
                                      style: const TextStyle(fontSize: 13.5),
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(
                                          Icons.person_outline,
                                          color: KuwrirColors.textHint,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                        hintText: 'Nama penerima',
                                        hintStyle: TextStyle(color: KuwrirColors.textHint),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: KuwrirColors.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: KuwrirColors.border),
                                    ),
                                    child: TextField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      style: const TextStyle(fontSize: 13.5),
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(
                                          Icons.phone_outlined,
                                          color: KuwrirColors.textHint,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                        hintText: 'No. HP penerima',
                                        hintStyle: TextStyle(color: KuwrirColors.textHint),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // Summary + Continue
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      decoration: BoxDecoration(
                        color: KuwrirColors.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: KuwrirColors.textPrimary.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _PriceRow(
                            label: 'Subtotal menu',
                            amount: cart.subtotal - cart.packagingFeeTotal,
                          ),
                          if (cart.packagingFeeTotal > 0) ...[
                            const SizedBox(height: 6),
                            _PriceRow(
                              label: 'Biaya kemasan (dari merchant)',
                              amount: cart.packagingFeeTotal,
                            ),
                          ],
                          const SizedBox(height: 6),
                          _PriceRow(label: 'Ongkir (estimasi)', amount: 15000),
                          const SizedBox(height: 10),
                          Divider(height: 1, color: KuwrirColors.border),
                          const SizedBox(height: 10),
                          _PriceRow(
                            label: 'Est. total',
                            amount: cart.subtotal + 15000,
                            isBold: true,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: KuwrirColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: cart.isEmpty
                                  ? null
                                  : () => _goToSummary(cart),
                              child: const Text(
                                'Checkout',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  String _fmt(double price) => price
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
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
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: KuwrirColors.primary),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;

  const _PriceRow({
    required this.label,
    required this.amount,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: isBold ? 16.5 : 13.5,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
      color: isBold ? KuwrirColors.textPrimary : KuwrirColors.textSecondary,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
          style: style.copyWith(color: isBold ? KuwrirColors.primary : KuwrirColors.textSecondary),
        ),
      ],
    );
  }
}
