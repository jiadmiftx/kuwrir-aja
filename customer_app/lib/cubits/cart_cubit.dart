import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class CartState {
  final List<CartItem> items;
  final String? merchantId;
  final String? merchantName;

  const CartState({this.items = const [], this.merchantId, this.merchantName});

  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);
  double get packagingFeeTotal =>
      items.fold(0, (sum, i) => sum + i.packagingFeeTotal);
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    String? merchantId,
    String? merchantName,
  }) => CartState(
    items: items ?? this.items,
    merchantId: merchantId ?? this.merchantId,
    merchantName: merchantName ?? this.merchantName,
  );
}

String _variantKey(List<ProductVariant> variants) {
  final ids = variants.map((v) => v.id).toList()..sort();
  return ids.join(',');
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  /// Adds a product to the cart. Products with different [selectedVariants]
  /// combinations become separate cart lines even when they're the same
  /// product (e.g. "Nasi Goreng - Pedas" vs "- Tidak Pedas").
  void addItem(
    Product product, {
    String? merchantId,
    String? merchantName,
    List<ProductVariant> selectedVariants = const [],
    int quantity = 1,
  }) {
    final key = _variantKey(selectedVariants);

    // Reset cart if switching merchants
    if (state.merchantId != null && state.merchantId != merchantId) {
      emit(
        CartState(
          items: [
            CartItem(
              product: product,
              quantity: quantity,
              selectedVariants: selectedVariants,
            ),
          ],
          merchantId: merchantId,
          merchantName: merchantName,
        ),
      );
      return;
    }

    final existing = state.items.indexWhere(
      (i) => i.product.id == product.id && i.variantKey == key,
    );
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + quantity,
      );
      emit(state.copyWith(items: updated));
    } else {
      emit(
        state.copyWith(
          items: [
            ...state.items,
            CartItem(
              product: product,
              quantity: quantity,
              selectedVariants: selectedVariants,
            ),
          ],
          merchantId: merchantId,
          merchantName: merchantName,
        ),
      );
    }
  }

  void removeItem(String productId, {String variantKey = ''}) {
    final updated = state.items
        .where(
          (i) => !(i.product.id == productId && i.variantKey == variantKey),
        )
        .toList();
    emit(state.copyWith(items: updated));
  }

  void decrementItem(String productId, {String variantKey = ''}) {
    final idx = state.items.indexWhere(
      (i) => i.product.id == productId && i.variantKey == variantKey,
    );
    if (idx < 0) return;
    final item = state.items[idx];
    if (item.quantity <= 1) {
      removeItem(productId, variantKey: variantKey);
    } else {
      final updated = List<CartItem>.from(state.items);
      updated[idx] = item.copyWith(quantity: item.quantity - 1);
      emit(state.copyWith(items: updated));
    }
  }

  /// Edits the note on an existing cart line (e.g. "pedas sedikit, tanpa
  /// bawang") without touching quantity or variant selection.
  void updateNotes(String productId, String notes, {String variantKey = ''}) {
    final idx = state.items.indexWhere(
      (i) => i.product.id == productId && i.variantKey == variantKey,
    );
    if (idx < 0) return;
    final updated = List<CartItem>.from(state.items);
    updated[idx] = updated[idx].copyWith(notes: notes);
    emit(state.copyWith(items: updated));
  }

  void clear() => emit(const CartState());
}
