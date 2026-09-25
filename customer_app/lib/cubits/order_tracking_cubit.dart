import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class OrderTrackingState {}

class OrderTrackingLoading extends OrderTrackingState {}

class OrderTracking extends OrderTrackingState {
  final Order order;

  /// Raw `{modification_request, removed_item}` response when the merchant
  /// has flagged an item unavailable and is waiting on the customer to pick
  /// a substitute or cancel — null the rest of the time. Polled alongside
  /// the order itself (same fallback-to-push pattern as everywhere else)
  /// rather than needing its own timer.
  final Map<String, dynamic>? modificationRequest;

  OrderTracking(this.order, {this.modificationRequest});
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
  final OrderStatusWatcher _watcher;
  Timer? _fallbackTimer;

  /// The order this cubit is currently supposed to be showing. This cubit
  /// is a single app-lifetime singleton (see main.dart's BlocProvider), not
  /// one instance per tracking screen — without this guard, a leaked
  /// watcher/timer from a *previously* viewed order (see startTracking)
  /// could resolve after the customer has navigated to a different order's
  /// tracking screen and clobber it with the wrong order's status.
  String? _activeOrderId;

  OrderTrackingCubit(this._api)
    : _watcher = OrderStatusWatcher(_api),
      super(OrderTrackingLoading());

  /// SSE (`GET /orders/:id/stream`, mirroring the payment-stream pattern
  /// from CLAUDE.md) is the primary refresh trigger now — the watcher only
  /// tells us *that* something changed, so every event still does a full
  /// [ApiClient.getOrder] to pick up the new fields (price, driver, etc).
  /// The periodic timer here is just a slow safety net for the rare case
  /// where the stream stalls without tripping its own reconnect (e.g. the
  /// OS suspends sockets but not timers while the app is backgrounded).
  ///
  /// Stopping the previous watcher/timer first matters because this cubit
  /// is shared across every order the customer opens in this session — the
  /// stream endpoint (`GET /orders/:id/stream`) leaked a request per
  /// second, for every order, forever, without this.
  void startTracking(String orderId) {
    _fallbackTimer?.cancel();
    _watcher.stop();
    _activeOrderId = orderId;
    _loadOrder(orderId);
    _watcher.start(orderId, onStatus: (_) => _loadOrder(orderId));
    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _loadOrder(orderId),
    );
  }

  /// Manual pull-to-refresh — reuses the same load path as the stream/timer,
  /// just triggered on demand instead of waiting for the next event.
  Future<void> refreshNow(String orderId) => _loadOrder(orderId);

  Future<void> _loadOrder(String orderId) async {
    try {
      final order = await _api.getOrder(orderId);
      // A request for a since-abandoned order that only just resolved —
      // discard it instead of overwriting whatever's now on screen.
      if (orderId != _activeOrderId) return;
      if (order.status == 'delivered' || order.status == 'returned') {
        _fallbackTimer?.cancel();
        _watcher.stop();
        emit(OrderTrackingDelivered(order));
        return;
      }
      Map<String, dynamic>? modReq;
      if (order.status == 'confirmed' || order.status == 'preparing') {
        try {
          modReq = await _api.getModificationRequest(orderId);
        } catch (_) {
          // 404 (no pending request) is the expected common case here.
        }
      }
      if (orderId != _activeOrderId) return;
      emit(OrderTracking(order, modificationRequest: modReq));
    } on ApiException catch (e) {
      if (orderId != _activeOrderId) return;
      emit(OrderTrackingError(e.message));
    } catch (_) {
      // Keep existing state on transient errors
    }
  }

  @override
  Future<void> close() {
    _fallbackTimer?.cancel();
    _watcher.stop();
    return super.close();
  }
}
