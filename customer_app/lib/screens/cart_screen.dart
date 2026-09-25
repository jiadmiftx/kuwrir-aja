import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/cart_cubit.dart';
import '../cubits/location_cubit.dart';
import '../cubits/session_cubit.dart';
import '../widgets/checkout_widgets.dart';
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
  bool _editingReceiver = false;

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
    // Pre-fill receiver name/phone from the account profile — most orders
    // are for the account owner, so default to a read-only summary and only
    // open the fields for editing if the profile is incomplete or the
    // customer explicitly taps "Ubah" (e.g. ordering for someone else).
    final user = context.read<SessionCubit>().state.user;
    _receiverCtrl.text = user?.name ?? '';
    _phoneCtrl.text = user?.phone ?? '';
    _editingReceiver = _receiverCtrl.text.isEmpty || _phoneCtrl.text.isEmpty;
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

  /// Deleting an item is only reachable by decrementing its own quantity
  /// down to zero (see `_CartItemCard.onDecrement` below) — there's no
  /// global "empty cart" shortcut, so this only ever confirms removing the
  /// one item the customer was already adjusting.
  Future<void> _confirmRemoveItem(CartItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${item.product.name}?'),
        content: const Text('Item ini akan dihapus dari keranjang.'),
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
    if (confirmed == true && mounted) {
      context.read<CartCubit>().removeItem(
        item.product.id,
        variantKey: item.variantKey,
      );
    }
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
          merchantImageUrl: cart.merchantImageUrl,
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
            title: Text(
              cart.isEmpty
                  ? 'Keranjang'
                  : 'Keranjang · ${cart.items.length} item',
            ),
            backgroundColor: KuwrirColors.background,
          ),
          body: cart.isEmpty ? _EmptyCart() : _buildCart(cart),
        );
      },
    );
  }

  Widget _buildCart(CartState cart) {
    return Column(
      children: [
        // Merchant header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: BoxDecoration(
            color: KuwrirColors.surface,
            boxShadow: [
              BoxShadow(
                color: KuwrirColors.textPrimary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: KuwrirColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    cart.merchantImageUrl != null &&
                        cart.merchantImageUrl!.isNotEmpty
                    ? Image.network(
                        cart.merchantImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => HugeIcon(
                          icon: HugeIcons.strokeRoundedStore01,
                          size: 26,
                          color: KuwrirColors.primary,
                        ),
                      )
                    : HugeIcon(
                        icon: HugeIcons.strokeRoundedStore01,
                        size: 26,
                        color: KuwrirColors.primary,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pesanan dari',
                      style: TextStyle(
                        fontSize: 12,
                        color: KuwrirColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cart.merchantName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Pesanan'),
                ...cart.items.map(
                  (item) => _CartItemCard(
                    item: item,
                    onEditNotes: () => _editItemNotes(item),
                    onIncrement: () => context.read<CartCubit>().addItem(
                      item.product,
                      merchantId: cart.merchantId,
                      merchantName: cart.merchantName,
                      selectedVariants: item.selectedVariants,
                    ),
                    onDecrement: () => item.quantity <= 1
                        ? _confirmRemoveItem(item)
                        : context.read<CartCubit>().decrementItem(
                            item.product.id,
                            variantKey: item.variantKey,
                          ),
                  ),
                ),

                const SizedBox(height: 26),
                const SectionLabel('Alamat Pengiriman'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KuwrirColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: KuwrirColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedLocation01,
                          size: 16,
                          color: KuwrirColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _addressCtrl,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                            ),
                            border: InputBorder.none,
                            filled: false,
                            hintText: 'Masukkan alamat pengiriman',
                            hintStyle: TextStyle(color: KuwrirColors.textHint),
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (!await ensureLoggedIn(context) || !mounted)
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
                                    context.read<LocationCubit>().setLocation(
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
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: KuwrirColors.border),
                            foregroundColor: KuwrirColors.textPrimary,
                          ),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedBookmark01,
                            size: 16,
                            color: KuwrirColors.primary,
                          ),
                          label: const Text(
                            'Alamat Tersimpan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final initial = _dropoffLat != 0
                                ? LatLng(_dropoffLat, _dropoffLng)
                                : null;
                            final result =
                                await Navigator.push<Map<String, dynamic>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LocationPickerScreen(initial: initial),
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
                              if (mounted) {
                                context.read<LocationCubit>().setLocation(
                                  latlng.latitude,
                                  latlng.longitude,
                                  addr,
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: KuwrirColors.border),
                            foregroundColor: KuwrirColors.textPrimary,
                          ),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedMaping,
                            size: 16,
                            color: KuwrirColors.primary,
                          ),
                          label: const Text(
                            'Pilih di Peta',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),
                SectionLabel(
                  'Penerima',
                  trailing: !_editingReceiver
                      ? GestureDetector(
                          onTap: () => setState(() => _editingReceiver = true),
                          child: Text(
                            'Ubah',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: KuwrirColors.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                if (_editingReceiver) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: KuwrirColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _receiverCtrl,
                            style: const TextStyle(fontSize: 13.5),
                            decoration: InputDecoration(
                              prefixIcon: HugeIcon(
                                icon: HugeIcons.strokeRoundedUser,
                                size: 18,
                                color: KuwrirColors.textHint,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              hintText: 'Nama penerima',
                              hintStyle: TextStyle(
                                color: KuwrirColors.textHint,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: KuwrirColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 13.5),
                            decoration: InputDecoration(
                              prefixIcon: HugeIcon(
                                icon: HugeIcons.strokeRoundedCall,
                                size: 18,
                                color: KuwrirColors.textHint,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              hintText: 'No. HP penerima',
                              hintStyle: TextStyle(
                                color: KuwrirColors.textHint,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_receiverCtrl.text.isNotEmpty &&
                      _phoneCtrl.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _editingReceiver = false),
                        child: Text(
                          'Selesai',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: KuwrirColors.primary,
                          ),
                        ),
                      ),
                    ),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KuwrirColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _receiverCtrl.text,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _phoneCtrl.text,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: KuwrirColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Summary + Continue
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: KuwrirColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              PriceRow(
                label: 'Subtotal',
                amount: cart.subtotal - cart.packagingFeeTotal,
              ),
              if (cart.packagingFeeTotal > 0)
                PriceRow(
                  label: 'Biaya kemasan',
                  amount: cart.packagingFeeTotal,
                ),
              const SizedBox(height: 2),
              Text(
                'Ongkir & total dihitung di langkah berikutnya',
                style: TextStyle(fontSize: 11.5, color: KuwrirColors.textHint),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KuwrirColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: cart.isEmpty ? null : () => _goToSummary(cart),
                  child: const Text(
                    'Checkout',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
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
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedShoppingCart01,
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
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onEditNotes;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;
  const _CartItemCard({
    required this.item,
    required this.onEditNotes,
    required this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final hasNotes = item.notes != null && item.notes!.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: KuwrirColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      if (item.selectedVariants.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.selectedVariants.map((v) => v.name).join(', '),
                          style: TextStyle(
                            fontSize: 12,
                            color: KuwrirColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        'Rp ${formatRupiah(item.unitPrice)}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: KuwrirColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      QtyStepButton(
                        icon: HugeIcons.strokeRoundedRemove01,
                        onTap: onDecrement,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      QtyStepButton(
                        icon: HugeIcons.strokeRoundedAdd01,
                        onTap: onIncrement,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: KuwrirColors.divider),
            const SizedBox(height: 8),
            InkWell(
              onTap: onEditNotes,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedNote03,
                      size: 16,
                      color: KuwrirColors.textHint,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasNotes
                            ? item.notes!
                            : 'Tambah catatan untuk item ini',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasNotes
                              ? KuwrirColors.textSecondary
                              : KuwrirColors.textHint,
                          fontStyle: hasNotes
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
    );
  }
}
