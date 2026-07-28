import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/cart_cubit.dart';
import '../cubits/order_cubit.dart';
import 'payment_webview_screen.dart';

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
  String _paymentType = 'cash';
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _loadingMethods = false;
  final Set<String> _expandedGroups = {};

  static const _groupOrder = [
    'E-Wallet',
    'QRIS',
    'Virtual Account',
    'Kartu Kredit',
    'Gerai Retail',
    'PayLater',
  ];

  static const _groupIcons = {
    'E-Wallet': Icons.account_balance_wallet_outlined,
    'QRIS': Icons.qr_code_rounded,
    'Virtual Account': Icons.account_balance_outlined,
    'Kartu Kredit': Icons.credit_card_outlined,
    'Gerai Retail': Icons.storefront_outlined,
    'PayLater': Icons.schedule_outlined,
  };

  String _categoryFor(String paymentName) {
    final upper = paymentName.toUpperCase();
    if (upper.contains('QRIS')) return 'QRIS';
    if (upper.contains('CREDIT CARD')) return 'Kartu Kredit';
    if (upper.contains('PAYLATER')) return 'PayLater';
    if (upper.contains('RETAIL') ||
        upper.contains('INDOMARET') ||
        upper.contains('ALFAMART')) {
      return 'Gerai Retail';
    }
    if (upper.contains('VA')) return 'Virtual Account';
    return 'E-Wallet';
  }

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  /// Live channel list from Duitku, re-fetched once the real total is
  /// known (fees can vary per amount tier). Best-effort: if the gateway
  /// isn't configured or the call fails, checkout just falls back to
  /// Cash (COD) only rather than blocking the whole screen.
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
          navigator.pushNamed(
            '/tracking',
            arguments: {'order_id': order.id},
          );
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
            _PaymentMethodOption(
              icon: Icons.payments_outlined,
              title: 'Cash (COD)',
              subtitle: 'Bayar tunai ke driver saat pesanan tiba',
              selected: _paymentType == 'cash',
              onTap: () => setState(() => _paymentType = 'cash'),
            ),
            if (_loadingMethods) ...[
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ] else
              for (final entry in () {
                final grouped = <String, List<Map<String, dynamic>>>{};
                for (final method in _paymentMethods) {
                  final cat = _categoryFor(
                    (method['paymentName'] as String?) ?? '',
                  );
                  grouped.putIfAbsent(cat, () => []).add(method);
                }
                return _groupOrder.where(
                  (cat) => grouped[cat]?.isNotEmpty ?? false,
                ).map((cat) => MapEntry(cat, grouped[cat]!));
              }()) ...[
                const SizedBox(height: 10),
                _PaymentMethodGroup(
                  category: entry.key,
                  icon: _groupIcons[entry.key] ?? Icons.payments_outlined,
                  methods: entry.value,
                  expanded:
                      _expandedGroups.contains(entry.key) ||
                      entry.value.any((m) => m['paymentMethod'] == _paymentType),
                  onToggle: () => setState(() {
                    if (_expandedGroups.contains(entry.key)) {
                      _expandedGroups.remove(entry.key);
                    } else {
                      _expandedGroups.add(entry.key);
                    }
                  }),
                  selectedMethod: _paymentType,
                  onSelect: (code) => setState(() => _paymentType = code),
                  fmt: _fmt,
                ),
              ],
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

class _PaymentMethodOption extends StatelessWidget {
  final IconData icon;
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KuwrirColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? KuwrirColors.primary : KuwrirColors.border,
            width: selected ? 1.5 : 1,
          ),
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
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? KuwrirColors.primary : KuwrirColors.textHint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodImageIcon extends StatelessWidget {
  final String imageUrl;
  final IconData fallback;
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
        loadingBuilder: (context, child, progress) =>
            progress == null
                ? child
                : Icon(fallback, color: KuwrirColors.primary, size: 19),
        errorBuilder: (context, error, stackTrace) =>
            Icon(fallback, color: KuwrirColors.primary, size: 19),
      ),
    );
  }
}

/// One payment-method category (e.g. "E-Wallet", "Virtual Account") as a
/// collapsible section — Duitku returns 20+ channels flat, which is too
/// long to scan as one list, so channels are grouped by category and only
/// expanded on demand (or automatically if it already holds the selected
/// method).
class _PaymentMethodGroup extends StatelessWidget {
  final String category;
  final IconData icon;
  final List<Map<String, dynamic>> methods;
  final bool expanded;
  final VoidCallback onToggle;
  final String selectedMethod;
  final ValueChanged<String> onSelect;
  final String Function(double) fmt;

  const _PaymentMethodGroup({
    required this.category,
    required this.icon,
    required this.methods,
    required this.expanded,
    required this.onToggle,
    required this.selectedMethod,
    required this.onSelect,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KuwrirColors.border),
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
                  _PanelIcon(icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: KuwrirColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${methods.length}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: KuwrirColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: KuwrirColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  for (var i = 0; i < methods.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _PaymentMethodOption(
                      icon: icon,
                      imageUrl: methods[i]['paymentImage'] as String?,
                      title:
                          (methods[i]['paymentName'] as String?) ??
                          'Pembayaran Online',
                      subtitle: () {
                        final fee = double.tryParse(
                          (methods[i]['totalFee'] as String?) ?? '0',
                        );
                        return fee != null && fee > 0
                            ? 'Biaya admin Rp ${fmt(fee)}'
                            : 'Tanpa biaya admin';
                      }(),
                      selected:
                          selectedMethod == methods[i]['paymentMethod'],
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
