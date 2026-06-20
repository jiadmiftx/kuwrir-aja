import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class ActiveDeliveryState {}

class ActiveDeliveryIdle extends ActiveDeliveryState {}

class ActiveDeliveryActive extends ActiveDeliveryState {
  final Map<String, dynamic> order;
  ActiveDeliveryActive(this.order);
}

class ActiveDeliveryMarkingPickup extends ActiveDeliveryState {
  final Map<String, dynamic> order;
  ActiveDeliveryMarkingPickup(this.order);
}

class ActiveDeliveryMarkingDelivered extends ActiveDeliveryState {
  final Map<String, dynamic> order;
  ActiveDeliveryMarkingDelivered(this.order);
}

class ActiveDeliveryDone extends ActiveDeliveryState {
  final Map<String, dynamic> result;
  ActiveDeliveryDone(this.result);
}

class ActiveDeliveryError extends ActiveDeliveryState {
  final String message;
  ActiveDeliveryError(this.message);
}

class ActiveDeliveryCubit extends Cubit<ActiveDeliveryState> {
  final ApiClient _api;

  ActiveDeliveryCubit(this._api) : super(ActiveDeliveryIdle());

  void setOrder(Map<String, dynamic> order) {
    emit(ActiveDeliveryActive(order));
  }

  Future<void> markPickedUp(String orderId) async {
    final current = state;
    if (current is ActiveDeliveryActive) {
      emit(ActiveDeliveryMarkingPickup(current.order));
      try {
        final result = await _api.markPickedUp(orderId);
        final updated = Map<String, dynamic>.from(current.order)
          ..addAll(result['order'] as Map<String, dynamic>? ?? {});
        emit(ActiveDeliveryActive(updated));
      } on ApiException catch (e) {
        emit(ActiveDeliveryError(e.message));
      } catch (_) {
        emit(ActiveDeliveryError('Gagal konfirmasi pickup'));
      }
    }
  }

  Future<void> markDelivered(String orderId) async {
    final current = state;
    if (current is ActiveDeliveryActive) {
      emit(ActiveDeliveryMarkingDelivered(current.order));
      try {
        final result = await _api.markDelivered(orderId);
        emit(ActiveDeliveryDone(result));
      } on ApiException catch (e) {
        emit(ActiveDeliveryError(e.message));
      } catch (_) {
        emit(ActiveDeliveryError('Gagal konfirmasi pengiriman'));
      }
    }
  }

  void reset() => emit(ActiveDeliveryIdle());
}
