import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Simple in-memory cart item
class CartItem {
  final String menuItemId;
  final String name;
  final double basePrice;
  final double displayPrice; // with markup
  int quantity;
  String? notes;

  CartItem({
    required this.menuItemId,
    required this.name,
    required this.basePrice,
    required this.displayPrice,
    this.quantity = 1,
    this.notes,
  });
}

class CartScreen extends StatefulWidget {
  final List<CartItem> items;
  final String merchantName;
  final double deliveryFee;

  const CartScreen({
    super.key,
    required this.items,
    required this.merchantName,
    required this.deliveryFee,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<CartItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + (item.displayPrice * item.quantity));
  double get _total => _subtotal + widget.deliveryFee;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
      ),
      body: _items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your cart is empty', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                // Merchant name
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: KuwrirColors.primary.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      const Icon(Icons.store, size: 18, color: KuwrirColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        widget.merchantName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Cart items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Item info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'IDR ${_formatPrice(item.displayPrice)}',
                                      style: const TextStyle(color: KuwrirColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              // Quantity controls
                              Row(
                                children: [
                                  _QuantityButton(
                                    icon: Icons.remove,
                                    onTap: () {
                                      setState(() {
                                        if (item.quantity > 1) {
                                          item.quantity--;
                                        } else {
                                          _items.removeAt(index);
                                        }
                                      });
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                  _QuantityButton(
                                    icon: Icons.add,
                                    onTap: () => setState(() => item.quantity++),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Price summary + Checkout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
                  ),
                  child: Column(
                    children: [
                      _PriceRow(label: 'Subtotal', amount: _subtotal),
                      const SizedBox(height: 4),
                      _PriceRow(label: 'Delivery Fee', amount: widget.deliveryFee),
                      const Divider(height: 16),
                      _PriceRow(label: 'Total (Cash)', amount: _total, isBold: true),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: KuwrirColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payments_outlined, size: 14, color: KuwrirColors.warning),
                            SizedBox(width: 4),
                            Text('Cash on Delivery (COD)', style: TextStyle(fontSize: 12, color: KuwrirColors.warning, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _items.isEmpty
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _CheckoutScreen(
                                        items: _items,
                                        merchantName: widget.merchantName,
                                        subtotal: _subtotal,
                                        deliveryFee: widget.deliveryFee,
                                        total: _total,
                                      ),
                                    ),
                                  ),
                          child: const Text('Proceed to Checkout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.onTap});

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

// --- Checkout Screen ---
class _CheckoutScreen extends StatelessWidget {
  final List<CartItem> items;
  final String merchantName;
  final double subtotal;
  final double deliveryFee;
  final double total;

  const _CheckoutScreen({
    required this.items,
    required this.merchantName,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery address
            const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on, color: KuwrirColors.primary),
                title: const Text('Kuta Beach Area'),
                subtitle: const Text('Jl. Pantai Kuta, Lombok Tengah, NTB'),
                trailing: TextButton(onPressed: () {}, child: const Text('Change')),
              ),
            ),
            const SizedBox(height: 24),

            // Payment method
            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments, color: KuwrirColors.warning),
                title: const Text('Cash on Delivery (COD)'),
                subtitle: const Text('Pay the driver in cash upon delivery'),
              ),
            ),
            const SizedBox(height: 24),

            // Order summary
            const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store, size: 16, color: KuwrirColors.primary),
                        const SizedBox(width: 8),
                        Text(merchantName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 16),
                    ...items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.quantity}x ${item.name}', style: const TextStyle(fontSize: 13)),
                              Text(
                                'IDR ${(item.displayPrice * item.quantity).toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        )),
                    const Divider(height: 16),
                    _PriceRow(label: 'Subtotal', amount: subtotal),
                    const SizedBox(height: 4),
                    _PriceRow(label: 'Delivery', amount: deliveryFee),
                    const Divider(height: 16),
                    _PriceRow(label: 'Total', amount: total, isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Notes
            TextField(
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Order Notes (optional)',
                hintText: 'e.g., Extra spicy, no MSG...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // TODO: Call API POST /orders
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  icon: const Icon(Icons.check_circle, color: KuwrirColors.success, size: 48),
                  title: const Text('Order Placed!'),
                  content: Text('Your order has been sent to $merchantName.\nPlease prepare IDR ${total.toStringAsFixed(0)} in cash.'),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Place Order · IDR ${total.toStringAsFixed(0)}'),
            ),
          ),
        ),
      ),
    );
  }
}
