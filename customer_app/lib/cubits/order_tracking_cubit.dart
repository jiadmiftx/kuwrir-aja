import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class OrderTrackingState {}

class OrderTrackingLoading extends OrderTrackingState {}

class OrderTracking extends OrderTrackingState {
  final Order order;
  OrderTracking(this.order);
}

class OrderTrackingDelivered extends OrderTrackingState {
  final Order order;
  OrderTrackingDelivered(this.order);
}

class OrderTrackingError extends OrderTrackingState {
  final String message;
  OrderTrackingError(this.message);
}

class OrderTrackingCubit extends Cubit<OrderTrackingState> {
  final ApiClient _api;
  Timer? _timer;

  OrderTrackingCubit(this._api) : super(OrderTrackingLoading());

  void startTracking(String orderId) {
    _loadOrder(orderId);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadOrder(orderId));
  }

  Future<void> _loadOrder(String orderId) async {
    try {
      final order = await _api.getOrder(orderId);
      if (order.status == 'delivered' || order.status == 'returned') {
        _timer?.cancel();
        emit(OrderTrackingDelivered(order));
      } else {
        emit(OrderTracking(order));
      }
    } on ApiException catch (e) {
      emit(OrderTrackingError(e.message));
    } catch (_) {
      // Keep existing state on transient errors
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
