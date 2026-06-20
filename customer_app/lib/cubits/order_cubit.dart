import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class OrderState {}

class OrderIdle extends OrderState {}

class OrderPlacing extends OrderState {}

class OrderPlaced extends OrderState {
  final Order order;
  OrderPlaced(this.order);
}

class OrderError extends OrderState {
  final String message;
  OrderError(this.message);
}

class OrderCubit extends Cubit<OrderState> {
  final ApiClient _api;

  OrderCubit(this._api) : super(OrderIdle());

  Future<void> placeOrder({
    required String merchantId,
    required List<CartItem> items,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    String receiverName = '',
    String receiverPhone = '',
    String paymentType = 'cash',
    String notes = '',
  }) async {
    emit(OrderPlacing());
    try {
      final body = {
        'merchant_id': merchantId,
        'items': items
            .map((i) => {
                  'product_id': i.product.id,
                  'quantity': i.quantity,
                  'notes': i.notes ?? '',
                })
            .toList(),
        'dropoff_address': dropoffAddress,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'receiver_name': receiverName,
        'receiver_phone': receiverPhone,
        'payment_type': paymentType,
        'notes': notes,
      };
      final order = await _api.placeOrder(body);
      emit(OrderPlaced(order));
    } on ApiException catch (e) {
      emit(OrderError(e.message));
    } catch (e) {
      emit(OrderError('Gagal membuat pesanan'));
    }
  }

  void reset() => emit(OrderIdle());
}
