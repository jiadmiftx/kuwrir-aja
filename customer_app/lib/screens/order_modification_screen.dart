import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/merchant_detail_cubit.dart';
import '../cubits/order_tracking_cubit.dart';
import 'payment_webview_screen.dart';
import 'product_variant_sheet.dart';

/// Reached from a "Menunggu customer pilih pengganti" banner on
/// [OrderTrackingScreen] once the merchant has flagged an item unavailable
/// on an already-accepted order (see `RequestItemChange` backend-side).
/// Lets the customer either pick any replacement product from the same
/// merchant's live menu, or cancel the whole order — mirroring the
/// GoFood/Grab flow this feature was modeled on.
class OrderModificationScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> modificationRequest;

  const OrderModificationScreen({
    super.key,
    required this.orderId,
    required this.modificationRequest,
  });

  @override
  State<OrderModificationScreen> createState() =>
      _OrderModificationScreenState();
}

class _OrderModificationScreenState extends State<OrderModificationScreen> {
  bool _loadingOrder = true;
  Order? _order;
  bool _submitting = false;

  Map<String, dynamic> get _req =>
      widget.modificationRequest['modification_request']
          as Map<String, dynamic>;
  Map<String, dynamic> get _removedItem =>
      widget.modificationRequest['removed_item'] as Map<String, dynamic>;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final order = await context.read<ApiClient>().getOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (_) {
      // Falls back to "Pesanan" title / no merchant menu if this fails —
      // the modification banner data itself already rendered fine.
    } finally {
      if (mounted) setState(() => _loadingOrder = false);
    }
  }

  String get _reasonLabel {
    const labels = {
      'stok_habis': 'Stok habis',
      'toko_tutup': 'Toko tutup',
      'item_tidak_tersedia': 'Item tidak tersedia',
      'lainnya': 'Lainnya',
    };
    final category = _req['reason_category'] as String? ?? '';
    final label = labels[category] ?? category;
    final reason = _req['reason'] as String?;
    if (reason == null || reason.isEmpty) return label;
    return '$label — $reason';
  }

  Duration get _timeLeft {
    final expiresAt = DateTime.tryParse(_req['expires_at'] as String? ?? '');
    if (expiresAt == null) return Duration.zero;
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _pickReplacement() async {
    final order = _order;
    final merchantId = order?.merchantId;
    if (merchantId == null) return;

    final picked = await Navigator.push<_PickedReplacement>(
      context,
      MaterialPageRoute(
        builder: (_) => _ReplacementPickerScreen(
          merchantId: merchantId,
          merchantName: order?.merchantName ?? 'Menu',
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final removedTotal = (_removedItem['total_price'] as num?)?.toDouble() ?? 0;
    final estDelta = picked.estimatedTotal - removedTotal;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Ganti item ini?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${picked.quantity}x ${picked.product.name}'),
            const SizedBox(height: 12),
            Text(
              estDelta.abs() < 0.01
                  ? 'Tidak ada selisih harga.'
                  : estDelta > 0
                  ? 'Perkiraan tambahan bayar: IDR ${_fmt(estDelta)}'
                  : 'Perkiraan refund: IDR ${_fmt(-estDelta)}',
              style: TextStyle(
                color: estDelta > 0
                    ? KuwrirColors.warning
                    : KuwrirColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total final dihitung ulang oleh sistem setelah dikonfirmasi.',
              style: TextStyle(fontSize: 11.5, color: KuwrirColors.textHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final resp = await context.read<ApiClient>().replaceOrderItem(
        widget.orderId,
        _req['id'] as String,
        productId: picked.product.id,
        quantity: picked.quantity,
        variantIds: picked.variants.map((v) => v.id).toList(),
      );
      final topupUrl = resp['topup_payment_url'] as String?;
      if (!mounted) return;
      if (topupUrl != null && topupUrl.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(
              paymentUrl: topupUrl,
              orderId: widget.orderId,
              returnMatchId: _req['id'] as String,
            ),
          ),
        );
      }
      if (!mounted) return;
      context.read<OrderTrackingCubit>().refreshNow(widget.orderId);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengganti item: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Batalkan pesanan?'),
        content: const Text(
          'Pesanan akan dibatalkan dan pembayaran (jika ada) akan direfund ke wallet kamu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KuwrirColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Batalkan Pesanan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await context.read<ApiClient>().cancelViaModificationRequest(
        widget.orderId,
        _req['id'] as String,
      );
      if (!mounted) return;
      context.read<OrderTrackingCubit>().refreshNow(widget.orderId);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membatalkan: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemName = _removedItem['item_name'] as String? ?? 'Item';
    final qty = (_removedItem['quantity'] as num?)?.toInt() ?? 1;
    final timeLeft = _timeLeft;

    return Scaffold(
      appBar: AppBar(title: const Text('Item Tidak Tersedia')),
      body: _loadingOrder
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: KuwrirColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedAlert02,
                              color: KuwrirColors.warning,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$qty x $itemName tidak tersedia',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _reasonLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: KuwrirColors.textSecondary,
                          ),
                        ),
                        if (timeLeft > Duration.zero) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Pilih dalam ${timeLeft.inMinutes} menit lagi, atau pesanan otomatis dibatalkan + direfund.',
                            style: TextStyle(
                              fontSize: 12,
                              color: KuwrirColors.textHint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_submitting)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _order?.merchantId == null
                            ? null
                            : _pickReplacement,
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedShoppingBag01,
                        ),
                        label: const Text('Pilih Pengganti dari Menu'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KuwrirColors.error,
                        ),
                        onPressed: _cancelOrder,
                        child: const Text('Batalkan Pesanan Ini'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}

class _PickedReplacement {
  final Product product;
  final List<ProductVariant> variants;
  final int quantity;
  final double estimatedTotal;

  const _PickedReplacement({
    required this.product,
    required this.variants,
    required this.quantity,
    required this.estimatedTotal,
  });
}

/// Free-browse picker over the merchant's live menu — deliberately not
/// limited to a merchant-suggested shortlist (the customer's own choice
/// per the approved flow). Reuses [MerchantDetailCubit] (already a
/// top-level provider) and [VariantSelectionSheet] rather than building a
/// second menu-fetch/render/variant-picking path from scratch.
class _ReplacementPickerScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;

  const _ReplacementPickerScreen({
    required this.merchantId,
    required this.merchantName,
  });

  @override
  State<_ReplacementPickerScreen> createState() =>
      _ReplacementPickerScreenState();
}

class _ReplacementPickerScreenState extends State<_ReplacementPickerScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MerchantDetailCubit>().load(widget.merchantId);
  }

  Future<void> _selectDirect(Product product) async {
    Navigator.pop(
      context,
      _PickedReplacement(
        product: product,
        variants: const [],
        quantity: 1,
        estimatedTotal: product.discountPrice ?? product.price,
      ),
    );
  }

  Future<void> _selectWithVariants(Product product) async {
    final result = await showModalBottomSheet<VariantSelectionResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VariantSelectionSheet(product: product),
    );
    if (result == null || !mounted) return;
    final base = product.discountPrice ?? product.price;
    final variantsSum = result.selectedVariants.fold(
      0.0,
      (sum, v) => sum + v.price,
    );
    Navigator.pop(
      context,
      _PickedReplacement(
        product: product,
        variants: result.selectedVariants,
        quantity: result.quantity,
        estimatedTotal: (base + variantsSum) * result.quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantDetailCubit, MerchantDetailState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text('Pilih dari ${widget.merchantName}')),
          body: switch (state) {
            MerchantDetailLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            MerchantDetailError(:final message) => Center(child: Text(message)),
            MerchantDetailLoaded(:final categories) =>
              categories.isEmpty
                  ? const Center(child: Text('Menu tidak tersedia'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final cat in categories) ...[
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: KuwrirColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final product in cat.products)
                            if (product.isAvailable && product.isVisibleNow)
                              _PickerProductTile(
                                product: product,
                                onTap: () => product.variants.isEmpty
                                    ? _selectDirect(product)
                                    : _selectWithVariants(product),
                              ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

class _PickerProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _PickerProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = product.discountPrice ?? product.price;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: KuwrirColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: product.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(product.imageUrl!, fit: BoxFit.cover),
                )
              : const HugeIcon(
                  icon: HugeIcons.strokeRoundedShoppingBag01,
                  color: KuwrirColors.primary,
                ),
        ),
        title: Text(product.name),
        subtitle: Text(
          'IDR ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
