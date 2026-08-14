import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class StoreOrdersState {}

class StoreOrdersLoading extends StoreOrdersState {}

class StoreOrdersLoaded extends StoreOrdersState {
  final List<Map<String, dynamic>> orders;
  StoreOrdersLoaded(this.orders);
}

class StoreOrdersError extends StoreOrdersState {
  final String message;
  StoreOrdersError(this.message);
}

class StoreOrdersCubit extends Cubit<StoreOrdersState> {
  final ApiClient _api;
  Timer? _timer;

  StoreOrdersCubit(this._api) : super(StoreOrdersLoading());

  void startPolling() {
    load();
    // Push (see NotificationService.onPushData / main.dart) is the primary
    // refresh trigger now — this is just a fallback for missed/delayed pushes.
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => load());
  }

  Future<void> load() async {
    try {
      final orders = await _api.getMyStoreOrders();
      emit(StoreOrdersLoaded(orders));
    } on ApiException catch (e) {
      emit(StoreOrdersError(e.message));
    } catch (_) {
      emit(StoreOrdersError('Gagal memuat pesanan'));
    }
  }

  Future<void> accept(String orderId) async {
    await _api.acceptOrder(orderId);
    await load();
  }

  Future<void> markPreparing(String orderId) async {
    await _api.markPreparing(orderId);
    await load();
  }

  Future<void> markReady(String orderId) async {
    await _api.markReady(orderId);
    await load();
  }

  Future<void> cancelAccepted(String orderId, {String? reason}) async {
    await _api.cancelAcceptedOrder(orderId, reason: reason);
    await load();
  }

  Future<void> requestItemChange(
    String orderId, {
    required String itemId,
    required String reasonCategory,
    String? reason,
  }) async {
    await _api.requestItemChange(
      orderId,
      itemId: itemId,
      reasonCategory: reasonCategory,
      reason: reason,
    );
    await load();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
