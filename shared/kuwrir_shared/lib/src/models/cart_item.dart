import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  final String? notes;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.notes,
  });

  double get lineTotal => product.price * quantity;

  CartItem copyWith({int? quantity, String? notes}) => CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        notes: notes ?? this.notes,
      );
}
