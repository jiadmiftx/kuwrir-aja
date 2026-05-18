import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// HTTP API client with JWT token management
class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = http.Client();

  /// Get stored JWT token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Store JWT token
  Future<void> saveToken(String token, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('refresh_token', refreshToken);
  }

  /// Clear stored tokens (logout)
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  /// Build headers with optional auth token
  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// GET request
  Future<Map<String, dynamic>> get(String endpoint, {bool auth = true}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(auth: auth),
    );
    return _handleResponse(response);
  }

  /// POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  /// PUT request
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  /// PATCH request
  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: body['error']?.toString() ?? 'Unknown error occurred',
    );
  }
}

/// Custom API exception
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
