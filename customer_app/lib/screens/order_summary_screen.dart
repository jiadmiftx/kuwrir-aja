import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/cart_cubit.dart';
import '../cubits/order_cubit.dart';
import '../widgets/checkout_widgets.dart';
import 'payment_webview_screen.dart';

/// Confirmation step shown after Cart — shows the real delivery fee/tax/
/// total (Cart only ever shows a flat delivery-fee estimate) before the
/// customer actually commits to placing the order.
class OrderSummaryScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;
  final String? merchantImageUrl;
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
    this.merchantImageUrl,
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
  String _paymentType = 'cash';
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _loadingMethods = false;
  bool _showOtherMethods = false;

  final _promoCtrl = TextEditingController();
  String _appliedPromoCode = '';
  String? _promoError;
  bool _applyingPromo = false;

  // QRIS surfaces as its own option (most-used channel); everything else
  // (VA, e-wallet, card, retail, PayLater) sits behind a "Metode Lainnya"
  // dropdown so the default list stays short - Cash + QRIS.
  List<Map<String, dynamic>> get _qrisMethods =>
      _paymentMethods.where((m) => m['paymentName'] == 'QRIS').toList();
  List<Map<String, dynamic>> get _otherMethods =>
      _paymentMethods.where((m) => m['paymentName'] != 'QRIS').toList();

  String _feeSubtitle(Map<String, dynamic> method) {
    final fee = double.tryParse((method['totalFee'] as String?) ?? '0');
    return fee != null && fee > 0
        ? 'Biaya admin Rp ${formatRupiah(fee)}'
        : 'Tanpa biaya admin';
  }

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  /// Live channel list from Duitku, re-fetched once the real total is
  /// known (fees can vary per amount tier). QRIS is split out as its own
  /// option; everything else sits behind the "Metode Lainnya" dropdown
  /// (see `_qrisMethods`/`_otherMethods`). Best-effort: if the gateway
  /// isn't configured or the call fails, checkout just falls back to
  /// Cash (COD) only.
  Future<void> _loadPaymentMethods(double amount) async {
    setState(() => _loadingMethods = true);
    try {
      final methods = await context.read<ApiClient>().getPaymentMethods(amount);
      if (mounted) setState(() => _paymentMethods = methods);
    } catch (_) {
      if (mounted) setState(() => _paymentMethods = []);
    } finally {
      if (mounted) setState(() => _loadingMethods = false);
    }
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
        promoCode: _appliedPromoCode,
      );
      if (mounted) setState(() => _quote = quote);
      unawaited(_loadPaymentMethods(quote.total));
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

  /// Validates the typed code against the real total (server enforces
  /// min-order/usage-limit/merchant-scope) — a bad code shows inline under
  /// the input instead of blowing away the whole price breakdown, since
  /// delivery fee etc. are still valid regardless of promo validity.
  Future<void> _applyPromo() async {
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _applyingPromo = true;
      _promoError = null;
    });
    try {
      final quote = await context.read<OrderCubit>().fetchQuote(
        merchantId: widget.merchantId,
        items: widget.items,
        dropoffLat: widget.dropoffLat,
        dropoffLng: widget.dropoffLng,
        promoCode: code,
      );
      if (mounted) {
        setState(() {
          _quote = quote;
          _appliedPromoCode = code;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _promoError = e is ApiException
              ? e.message
              : 'Kode promo tidak valid',
        );
      }
    } finally {
      if (mounted) setState(() => _applyingPromo = false);
    }
  }

  void _removePromo() {
    setState(() {
      _appliedPromoCode = '';
      _promoCtrl.clear();
      _promoError = null;
    });
    _loadQuote();
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
      paymentType: _paymentType,
      notes: widget.notes,
      promoCode: _appliedPromoCode,
    );
  }

  /// Non-cash orders still need a Duitku payment link created after the
  /// order exists (order creation and payment-link creation are separate
  /// steps server-side) — rendered in-app via PaymentWebViewScreen, pushed
  /// on top of the tracking screen so back/close lands back on it.
  ///
  /// Takes the NavigatorState/ApiClient directly (captured before the
  /// stack-reset below) rather than a BuildContext — this screen's own
  /// context gets torn down by pushNamedAndRemoveUntil before the awaited
  /// createOrderPayment call resolves, but the NavigatorState itself stays
  /// alive as the app's root navigator.
  Future<void> _openPaymentWebView(
    NavigatorState navigator,
    ApiClient api,
    Order order,
    String paymentType,
  ) async {
    if (paymentType == 'cash') return;
    try {
      final resp = await api.createOrderPayment(
        orderId: order.id,
        paymentMethod: paymentType,
      );
      final url = resp['payment_url'] as String?;
      if (url != null && navigator.mounted) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                PaymentWebViewScreen(paymentUrl: url, orderId: order.id),
          ),
        );
      }
    } catch (_) {
      // Order is already placed regardless — customer can retry payment
      // from the "Bayar Sekarang" button on the tracking screen if this
      // fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is OrderPlaced) {
          context.read<CartCubit>().clear();
          final navigator = Navigator.of(context);
          final api = context.read<ApiClient>();
          final order = state.order;
          final paymentType = _paymentType;
          // Reset the stack to Home (Orders tab) -> Detail Order so the
          // payment WebView (pushed next) sits on a clean, predictable
          // back-stack instead of the now-irrelevant Cart/Checkout screens.
          navigator.pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
            arguments: {'tab': 2},
          );
          navigator.pushNamed('/tracking', arguments: {'order_id': order.id});
          unawaited(_openPaymentWebView(navigator, api, order, paymentType));
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
            const SectionLabel('Toko'),
            SoftPanel(
              child: Row(
                children: [
                  widget.merchantImageUrl != null &&
                          widget.merchantImageUrl!.isNotEmpty
                      ? Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: KuwrirColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            widget.merchantImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedStore01,
                                  color: KuwrirColors.primary,
                                  size: 19,
                                ),
                          ),
                        )
                      : const _PanelIcon(HugeIcons.strokeRoundedStore01),
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
            SectionLabel('Pesanan (${widget.items.length} item)'),
            SoftPanel(
              child: Column(
                children: [
                  for (var i = 0; i < widget.items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: KuwrirColors.divider),
                    _ItemRow(item: widget.items[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Alamat Pengiriman'),
            SoftPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PanelIcon(HugeIcons.strokeRoundedLocation01),
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
            const SectionLabel('Metode Pembayaran'),
            _PaymentMethodOption(
              icon: HugeIcons.strokeRoundedPayment01,
              title: 'Cash (COD)',
              subtitle: 'Bayar tunai ke driver saat pesanan tiba',
              selected: _paymentType == 'cash',
              onTap: () => setState(() => _paymentType = 'cash'),
            ),
            if (_loadingMethods)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              for (final method in _qrisMethods) ...[
                const SizedBox(height: 8),
                _PaymentMethodOption(
                  icon: HugeIcons.strokeRoundedQrCode01,
                  imageUrl: method['paymentImage'] as String?,
                  title: (method['paymentName'] as String?) ?? 'QRIS',
                  subtitle: _feeSubtitle(method),
                  selected: _paymentType == method['paymentMethod'],
                  onTap: () => setState(
                    () => _paymentType = method['paymentMethod'] as String,
                  ),
                ),
              ],
              if (_otherMethods.isNotEmpty) ...[
                const SizedBox(height: 8),
                _OtherMethodsDropdown(
                  expanded: _showOtherMethods,
                  onToggle: () =>
                      setState(() => _showOtherMethods = !_showOtherMethods),
                  methods: _otherMethods,
                  selectedMethod: _paymentType,
                  onSelect: (code) => setState(() => _paymentType = code),
                  feeSubtitle: _feeSubtitle,
                ),
              ],
            ],
            const SizedBox(height: 24),
            const SectionLabel('Kode Promo'),
            SoftPanel(
              child: _appliedPromoCode.isNotEmpty
                  ? Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedDiscountTag01,
                          size: 18,
                          color: KuwrirColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _appliedPromoCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _removePromo,
                          child: const Text('Hapus'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _promoCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: 'Masukkan kode promo',
                                ),
                                onSubmitted: (_) => _applyPromo(),
                              ),
                            ),
                            TextButton(
                              onPressed: _applyingPromo ? null : _applyPromo,
                              child: _applyingPromo
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Terapkan'),
                            ),
                          ],
                        ),
                        if (_promoError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _promoError!,
                            style: TextStyle(
                              color: KuwrirColors.error,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Rincian Biaya'),
            SoftPanel(
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
                        PriceRow(
                          label: 'Subtotal menu',
                          amount: _quote!.subtotal,
                        ),
                        if (_quote!.packagingFee > 0)
                          PriceRow(
                            label: 'Biaya kemasan',
                            amount: _quote!.packagingFee,
                          ),
                        PriceRow(label: 'Ongkir', amount: _quote!.deliveryFee),
                        if (_quote!.appServiceFee > 0)
                          PriceRow(
                            label: 'Biaya layanan',
                            amount: _quote!.appServiceFee,
                          ),
                        if (_quote!.taxAmount > 0)
                          PriceRow(
                            label: 'Pajak (PPN)',
                            amount: _quote!.taxAmount,
                          ),
                        if (_quote!.discountAmount > 0)
                          PriceRow(
                            label: 'Diskon ($_appliedPromoCode)',
                            amount: _quote!.discountAmount,
                            isDiscount: true,
                          ),
                        Divider(height: 20, color: KuwrirColors.divider),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: KuwrirColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: PriceRow(
                            label: 'Total',
                            amount: _quote!.total,
                            emphasis: true,
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
                      borderRadius: BorderRadius.circular(16),
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
                              ? 'Buat Pesanan · Rp ${formatRupiah(_quote!.total)}'
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

class _PanelIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
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
      child: HugeIcon(icon: icon, color: KuwrirColors.primary, size: 19),
    );
  }
}

class _OtherMethodsDropdown extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final List<Map<String, dynamic>> methods;
  final String selectedMethod;
  final ValueChanged<String> onSelect;
  final String Function(Map<String, dynamic>) feeSubtitle;

  const _OtherMethodsDropdown({
    required this.expanded,
    required this.onToggle,
    required this.methods,
    required this.selectedMethod,
    required this.onSelect,
    required this.feeSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Metode pembayaran lain',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: KuwrirColors.textSecondary,
                      ),
                    ),
                  ),
                  HugeIcon(
                    icon: expanded
                        ? HugeIcons.strokeRoundedArrowUp01
                        : HugeIcons.strokeRoundedArrowDown01,
                    color: KuwrirColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (var i = 0; i < methods.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _PaymentMethodOption(
                      icon: HugeIcons.strokeRoundedPayment01,
                      imageUrl: methods[i]['paymentImage'] as String?,
                      title:
                          (methods[i]['paymentName'] as String?) ??
                          'Pembayaran Online',
                      subtitle: feeSubtitle(methods[i]),
                      selected: selectedMethod == methods[i]['paymentMethod'],
                      onTap: () =>
                          onSelect(methods[i]['paymentMethod'] as String),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentMethodOption extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? imageUrl;

  const _PaymentMethodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KuwrirColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? KuwrirColors.primary : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: selected
                ? []
                : [
                    BoxShadow(
                      color: KuwrirColors.textPrimary.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              imageUrl != null
                  ? _MethodImageIcon(imageUrl: imageUrl!, fallback: icon)
                  : _PanelIcon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: KuwrirColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: selected
                    ? HugeIcons.strokeRoundedCheckmarkCircle02
                    : HugeIcons.strokeRoundedCircle,
                color: selected ? KuwrirColors.primary : KuwrirColors.textHint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodImageIcon extends StatelessWidget {
  final String imageUrl;
  final List<List<dynamic>> fallback;
  const _MethodImageIcon({required this.imageUrl, required this.fallback});

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
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        width: 26,
        height: 26,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : HugeIcon(icon: fallback, color: KuwrirColors.primary, size: 19),
        errorBuilder: (context, error, stackTrace) =>
            HugeIcon(icon: fallback, color: KuwrirColors.primary, size: 19),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final CartItem item;
  const _ItemRow({required this.item});

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
            'Rp ${formatRupiah(item.lineTotal)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
