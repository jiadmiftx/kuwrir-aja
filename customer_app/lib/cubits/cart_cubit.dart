import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class CartState {
  final List<CartItem> items;
  final String? merchantId;
  final String? merchantName;

  const CartState({
    this.items = const [],
    this.merchantId,
    this.merchantName,
  });

  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    String? merchantId,
    String? merchantName,
  }) =>
      CartState(
        items: items ?? this.items,
        merchantId: merchantId ?? this.merchantId,
        merchantName: merchantName ?? this.merchantName,
      );
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  void addItem(Product product, {String? merchantId, String? merchantName}) {
    // Reset cart if switching merchants
    if (state.merchantId != null && state.merchantId != merchantId) {
      emit(CartState(
        items: [CartItem(product: product)],
        merchantId: merchantId,
        merchantName: merchantName,
      ));
      return;
    }

    final existing = state.items.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + 1,
      );
      emit(state.copyWith(items: updated));
    } else {
      emit(state.copyWith(
        items: [...state.items, CartItem(product: product)],
        merchantId: merchantId,
        merchantName: merchantName,
      ));
    }
  }

  void removeItem(String productId) {
    final updated = state.items.where((i) => i.product.id != productId).toList();
    emit(state.copyWith(items: updated));
  }

  void decrementItem(String productId) {
    final idx = state.items.indexWhere((i) => i.product.id == productId);
    if (idx < 0) return;
    final item = state.items[idx];
    if (item.quantity <= 1) {
      removeItem(productId);
    } else {
      final updated = List<CartItem>.from(state.items);
      updated[idx] = item.copyWith(quantity: item.quantity - 1);
      emit(state.copyWith(items: updated));
    }
  }

  void clear() => emit(const CartState());
}
