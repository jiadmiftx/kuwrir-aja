import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/cart_cubit.dart';
import '../cubits/order_cubit.dart';

/// Confirmation step shown after Cart — shows the real delivery fee/tax/
/// total (Cart only ever shows a flat delivery-fee estimate) before the
/// customer actually commits to placing the order.
class OrderSummaryScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;
  final List<CartItem> items;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String receiverName;
  final String receiverPhone;
  final String notes;

  const OrderSummaryScreen({
    super.key,
    required this.merchantId,
    required this.merchantName,
    required this.items,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.receiverName,
    required this.receiverPhone,
    required this.notes,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  OrderQuote? _quote;
  String? _quoteError;
  bool _loadingQuote = true;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _loadingQuote = true;
      _quoteError = null;
    });
    try {
      final quote = await context.read<OrderCubit>().fetchQuote(
        merchantId: widget.merchantId,
        items: widget.items,
        dropoffLat: widget.dropoffLat,
        dropoffLng: widget.dropoffLng,
      );
      if (mounted) setState(() => _quote = quote);
    } catch (e) {
      if (mounted) {
        setState(
          () => _quoteError = e is ApiException
              ? e.message
              : 'Gagal menghitung ongkir',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingQuote = false);
    }
  }

  void _confirmOrder() {
    context.read<OrderCubit>().placeOrder(
      merchantId: widget.merchantId,
      items: widget.items,
      dropoffAddress: widget.dropoffAddress,
      dropoffLat: widget.dropoffLat,
      dropoffLng: widget.dropoffLng,
      receiverName: widget.receiverName,
      receiverPhone: widget.receiverPhone,
      paymentType: 'cash',
      notes: widget.notes,
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is OrderPlaced) {
          context.read<CartCubit>().clear();
          Navigator.pushReplacementNamed(
            context,
            '/tracking',
            arguments: {'order_id': state.order.id},
          );
        } else if (state is OrderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: KuwrirColors.error,
            ),
          );
          context.read<OrderCubit>().reset();
        }
      },
      child: Scaffold(
        backgroundColor: KuwrirColors.background,
        appBar: AppBar(
          title: const Text('Checkout'),
          backgroundColor: KuwrirColors.background,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionLabel('Toko'),
            const SizedBox(height: 10),
            _SoftPanel(
              child: Row(
                children: [
                  const _PanelIcon(Icons.storefront_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.merchantName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('Pesanan (${widget.items.length} item)'),
            const SizedBox(height: 10),
            _SoftPanel(
              child: Column(
                children: [
                  for (var i = 0; i < widget.items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: KuwrirColors.border),
                    _ItemRow(item: widget.items[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('Alamat Pengiriman'),
            const SizedBox(height: 10),
            _SoftPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PanelIcon(Icons.location_on_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.dropoffAddress,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.receiverName.isNotEmpty ||
                            widget.receiverPhone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              widget.receiverName,
                              widget.receiverPhone,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: KuwrirColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('Metode Pembayaran'),
            const SizedBox(height: 10),
            _SoftPanel(
              child: Row(
                children: [
                  const _PanelIcon(Icons.payments_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cash (COD)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        Text(
                          'Bayar tunai ke driver saat pesanan tiba',
                          style: TextStyle(
                            fontSize: 12,
                            color: KuwrirColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('Rincian Biaya'),
            const SizedBox(height: 10),
            _SoftPanel(
              child: _loadingQuote
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _quoteError != null
                  ? Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _quoteError!,
                            style: TextStyle(
                              color: KuwrirColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadQuote,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _PriceRow(
                          label: 'Subtotal menu',
                          amount: _quote!.subtotal,
                        ),
                        if (_quote!.packagingFee > 0)
                          _PriceRow(
                            label: 'Biaya kemasan',
                            amount: _quote!.packagingFee,
                          ),
                        _PriceRow(label: 'Ongkir', amount: _quote!.deliveryFee),
                        if (_quote!.appServiceFee > 0)
                          _PriceRow(
                            label: 'Biaya layanan',
                            amount: _quote!.appServiceFee,
                          ),
                        if (_quote!.taxAmount > 0)
                          _PriceRow(
                            label: 'Pajak (PPN)',
                            amount: _quote!.taxAmount,
                          ),
                        Divider(height: 20, color: KuwrirColors.border),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: KuwrirColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _PriceRow(
                            label: 'Total',
                            amount: _quote!.total,
                            isBold: true,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 28),
          ],
        ),
        bottomNavigationBar: BlocBuilder<OrderCubit, OrderState>(
          builder: (context, state) {
            final placing = state is OrderPlacing;
            final canConfirm = !_loadingQuote && _quote != null && !placing;
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                14 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: KuwrirColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: KuwrirColors.textPrimary.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: KuwrirColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: canConfirm ? _confirmOrder : null,
                  child: placing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _quote != null
                              ? 'Buat Pesanan · Rp ${_fmt(_quote!.total)}'
                              : 'Buat Pesanan',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: KuwrirColors.textHint,
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  final Widget child;
  const _SoftPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KuwrirColors.border),
        boxShadow: [
          BoxShadow(
            color: KuwrirColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelIcon extends StatelessWidget {
  final IconData icon;
  const _PanelIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KuwrirColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: KuwrirColors.primary, size: 19),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final CartItem item;
  const _ItemRow({required this.item});

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KuwrirColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: KuwrirColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                if (item.selectedVariants.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.selectedVariants.map((v) => v.name).join(', '),
                      style: TextStyle(
                        fontSize: 12,
                        color: KuwrirColors.textSecondary,
                      ),
                    ),
                  ),
                if (item.notes != null && item.notes!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Catatan: ${item.notes}',
                      style: TextStyle(
                        fontSize: 12,
                        color: KuwrirColors.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rp ${_fmt(item.lineTotal)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
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
      fontSize: isBold ? 16 : 14,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: isBold ? KuwrirColors.textPrimary : KuwrirColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
            style: style.copyWith(color: isBold ? KuwrirColors.primary : null),
          ),
        ],
      ),
    );
  }
}
