import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Generic long-lived SSE subscription with backoff-capped auto-reconnect —
/// the mechanics [OrderStatusWatcher] first implemented for order status,
/// factored out so chat/support streams don't each copy the same ~60 lines.
/// Only handles connection/parsing/reconnect; callers own any
/// domain-specific logic (e.g. stopping on a terminal value).
class SseStream {
  final ApiClient _client;

  /// Path relative to [ApiClient.baseUrl], e.g. `/orders/$id/stream`.
  final String path;

  /// Only `data:` lines under this SSE `event:` name are decoded and
  /// handed to the caller — matches the second argument to the backend's
  /// `c.SSEvent(eventName, ...)` call.
  final String eventName;

  StreamSubscription<String>? _sub;
  http.Client? _http;
  Timer? _reconnectTimer;
  bool _stopped = true;
  int _retryCount = 0;

  SseStream(this._client, {required this.path, required this.eventName});

  /// Calls [onEvent] with the decoded JSON payload of every matching event,
  /// for as long as the stream runs. The caller is responsible for calling
  /// [stop] (e.g. on dispose, or from within [onEvent] for a terminal value).
  void start({required void Function(Map<String, dynamic> data) onEvent}) {
    _stopped = false;
    _retryCount = 0;
    _connect(onEvent);
  }

  Future<void> _connect(void Function(Map<String, dynamic>) onEvent) async {
    if (_stopped) return;
    final token = await _client.getToken();
    if (token == null) return;

    final httpClient = http.Client();
    _http = httpClient;
    final request =
        http.Request('GET', Uri.parse('${_client.baseUrl}$path'))
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'text/event-stream';

    try {
      final response = await httpClient.send(request);
      String? currentEvent;
      _sub = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.startsWith('event:')) {
                currentEvent = line.substring(6).trim();
              } else if (line.startsWith('data:')) {
                if (currentEvent != eventName) return;
                try {
                  final data =
                      jsonDecode(line.substring(5).trim())
                          as Map<String, dynamic>;
                  onEvent(data);
                } catch (_) {
                  // ignore malformed event
                }
              } else if (line.isEmpty) {
                currentEvent = null;
              }
            },
            onError: (_) => _scheduleReconnect(onEvent),
            onDone: () => _scheduleReconnect(onEvent),
          );
    } catch (_) {
      _scheduleReconnect(onEvent);
    }
  }

  /// Exponential-ish backoff capped at 15s — covers a dropped connection
  /// (network blip, backgrounded app, nginx idle timeout) without hammering
  /// the server on a sustained outage.
  void _scheduleReconnect(void Function(Map<String, dynamic>) onEvent) {
    if (_stopped) return;
    _http?.close();
    _retryCount++;
    final delaySeconds = math.min(2 * _retryCount, 15);
    _reconnectTimer = Timer(
      Duration(seconds: delaySeconds),
      () => _connect(onEvent),
    );
  }

  void stop() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _http?.close();
  }
}
