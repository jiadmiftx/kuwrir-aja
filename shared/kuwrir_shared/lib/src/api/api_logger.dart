import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Pretty-prints every API request/response to the debug console (no-op in
/// release builds). Shared by every app since they all go through the same
/// [ApiClient] — one logger, consistent format everywhere.
class ApiLogger {
  static const _divider = '─────────────────────────────────────────────────';

  static void request({
    required String method,
    required String url,
    Map<String, String>? headers,
    Object? body,
  }) {
    if (!kDebugMode) return;
    final b = StringBuffer()
      ..writeln('┌$_divider')
      ..writeln('│ ➜ $method $url');
    final safeHeaders = _redactAuth(headers);
    if (safeHeaders != null && safeHeaders.isNotEmpty) {
      b.writeln('│ headers: $safeHeaders');
    }
    if (body != null) {
      for (final line in _pretty(body).split('\n')) {
        b.writeln('│ $line');
      }
    }
    b.write('└$_divider');
    debugPrint(b.toString());
  }

  static void response({
    required String method,
    required String url,
    required int statusCode,
    required String rawBody,
    required Duration elapsed,
  }) {
    if (!kDebugMode) return;
    final ok = statusCode >= 200 && statusCode < 300;
    final icon = ok ? '✓' : '✗';
    final b = StringBuffer()
      ..writeln('┌$_divider')
      ..writeln('│ $icon $method $url  [$statusCode]  ${elapsed.inMilliseconds}ms');
    for (final line in _pretty(_tryDecode(rawBody)).split('\n')) {
      b.writeln('│ $line');
    }
    b.write('└$_divider');
    debugPrint(b.toString());
  }

  static Map<String, String>? _redactAuth(Map<String, String>? headers) {
    if (headers == null) return null;
    final copy = Map<String, String>.from(headers);
    final auth = copy['Authorization'];
    if (auth != null && auth.length > 24) {
      copy['Authorization'] = '${auth.substring(0, 24)}…';
    }
    return copy;
  }

  static Object? _tryDecode(String body) {
    if (body.isEmpty) return body;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _pretty(Object? data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}
