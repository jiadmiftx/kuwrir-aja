import 'api_client.dart';
import 'sse_stream.dart';

const _terminalOrderStatuses = {'delivered', 'cancelled', 'returned'};

/// Watches an order's status over SSE (`GET /orders/:id/stream`) instead of
/// polling for it — the same pattern [PaymentStatusWatcher] uses for
/// payment_status, but long-lived: an order can sit in flight for tens of
/// minutes, not the few seconds a payment confirmation takes, so the
/// underlying [SseStream] reconnects with backoff instead of giving up
/// after one short timeout. This wrapper's only job on top of [SseStream]
/// is stopping itself once a terminal status arrives.
class OrderStatusWatcher {
  final ApiClient _client;
  SseStream? _stream;

  OrderStatusWatcher(this._client);

  /// Calls [onStatus] for every status the stream reports, for as long as
  /// the watcher runs. Stops itself once a terminal status arrives; the
  /// caller is responsible for calling [stop] otherwise (e.g. on dispose).
  ///
  /// Stops any stream already running first — calling [start] again for a
  /// different order without an intervening [stop] used to leak the old
  /// connection forever instead of replacing it.
  void start(String orderId, {required void Function(String status) onStatus}) {
    stop();
    final stream = SseStream(
      _client,
      path: '/orders/$orderId/stream',
      eventName: 'order_status',
    );
    _stream = stream;
    stream.start(
      onEvent: (data) {
        final status = data['status'] as String?;
        if (status == null) return;
        onStatus(status);
        if (_terminalOrderStatuses.contains(status)) stop();
      },
    );
  }

  void stop() => _stream?.stop();
}
