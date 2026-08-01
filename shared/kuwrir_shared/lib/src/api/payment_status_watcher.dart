import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Watches an order's payment_status over SSE (`GET /payment/:orderId/stream`)
/// instead of polling for it. Meant for the short window right after a
/// payment WebView returns — closes the race between Duitku's async
/// server-to-server callback and the WebView's own return-URL navigation,
/// where a one-shot refresh could still show a stale "pending" status.
class PaymentStatusWatcher {
  final ApiClient _client;
  StreamSubscription<String>? _sub;
  http.Client? _http;
  Timer? _timeoutTimer;
  bool _finished = false;

  PaymentStatusWatcher(this._client);

  /// Calls [onStatus] for each payment_status the stream reports. Resolves
  /// on its own once a terminal status ("paid"/"failed"/"expired") arrives,
  /// or when [timeout] elapses — whichever comes first, so a caller never
  /// gets stuck waiting on a stream that failed to connect or stalled.
  Future<void> watch(
    String orderId, {
    required void Function(String status) onStatus,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final token = await _client.getToken();
    if (token == null) return;

    final completer = Completer<void>();
    void finish() {
      if (_finished) return;
      _finished = true;
      _timeoutTimer?.cancel();
      _sub?.cancel();
      _http?.close();
      if (!completer.isCompleted) completer.complete();
    }

    _timeoutTimer = Timer(timeout, finish);

    final httpClient = http.Client();
    _http = httpClient;
    final request = http.Request(
      'GET',
      Uri.parse('${_client.baseUrl}/payment/$orderId/stream'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'text/event-stream';

    try {
      final response = await httpClient.send(request);
      String? currentEvent;
      _sub = response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          if (line.startsWith('event:')) {
            currentEvent = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            if (currentEvent != 'payment_status') return;
            try {
              final data = jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
              final status = data['payment_status'] as String?;
              if (status == null) return;
              onStatus(status);
              if (status == 'paid' || status == 'failed' || status == 'expired') finish();
            } catch (_) {
              // ignore malformed event
            }
          } else if (line.isEmpty) {
            currentEvent = null;
          }
        },
        onError: (_) => finish(),
        onDone: finish,
      );
    } catch (_) {
      finish();
    }

    return completer.future;
  }

  void cancel() {
    _timeoutTimer?.cancel();
    _sub?.cancel();
    _http?.close();
  }
}
