import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import '../models/merchant.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/support_message.dart';

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

  /// Get stored JWT token (public — used for building multipart requests)
  Future<String?> getToken() => _getToken();

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

  static const _kTimeout = Duration(seconds: 15);

  /// GET request
  Future<Map<String, dynamic>> get(String endpoint, {bool auth = true}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(auth: auth),
    ).timeout(_kTimeout);
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
    ).timeout(_kTimeout);
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
    ).timeout(_kTimeout);
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
    ).timeout(_kTimeout);
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

  // ── Customer: Merchant Browsing ──────────────────────────────────────────

  Future<List<Merchant>> getMerchants({String? category}) async {
    final query = category != null ? '?category=$category' : '';
    final data = await get('/merchants$query');
    final list = data['merchants'] as List<dynamic>? ?? [];
    return list.map((m) => Merchant.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<List<Merchant>> getPopularMerchants() async {
    final data = await get('/merchants/popular', auth: false);
    final list = data['merchants'] as List<dynamic>? ?? [];
    return list.map((m) => Merchant.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<Merchant> getMerchant(String id) async {
    final data = await get('/merchants/$id');
    return Merchant.fromJson(data['merchant'] as Map<String, dynamic>);
  }

  Future<List<ProductCategory>> getMerchantMenu(String merchantId) async {
    final data = await get('/merchants/$merchantId/products');
    final list = data['categories'] as List<dynamic>?;
    if (list != null) {
      return list.map((c) => ProductCategory.fromJson(c as Map<String, dynamic>)).toList();
    }
    // Fallback: flat products list grouped by category
    final products = data['products'] as List<dynamic>? ?? [];
    final Map<String, ProductCategory> catMap = {};
    for (final p in products) {
      final product = Product.fromJson(p as Map<String, dynamic>);
      if (!catMap.containsKey(product.categoryId)) {
        catMap[product.categoryId] = ProductCategory(
          id: product.categoryId,
          merchantId: merchantId,
          name: 'Menu',
          products: [],
        );
      }
      catMap[product.categoryId] = ProductCategory(
        id: catMap[product.categoryId]!.id,
        merchantId: merchantId,
        name: catMap[product.categoryId]!.name,
        products: [...catMap[product.categoryId]!.products, product],
      );
    }
    return catMap.values.toList();
  }

  // ── Customer: Orders ──────────────────────────────────────────────────────

  Future<Order> placeOrder(Map<String, dynamic> body) async {
    final data = await post('/orders', body);
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<List<Order>> getMyOrders({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final data = await get('/orders$query');
    final list = data['orders'] as List<dynamic>? ?? [];
    return list.map((o) => Order.fromJson(o as Map<String, dynamic>)).toList();
  }

  Future<Order> getOrder(String id) async {
    final data = await get('/orders/$id');
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<void> cancelOrder(String id) async {
    await post('/orders/$id/cancel', {});
  }

  // ── Merchant: Store Management ────────────────────────────────────────────

  Future<Map<String, dynamic>> getTodaySummary() async {
    return await get('/my-store/today-summary');
  }

  Future<List<Map<String, dynamic>>> getMyStoreOrders() async {
    final data = await get('/merchant-orders');
    final list = data['orders'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> acceptOrder(String id) async {
    await post('/merchant-orders/$id/accept', {});
  }

  Future<void> markPreparing(String id) async {
    await post('/merchant-orders/$id/preparing', {});
  }

  Future<void> markReady(String id) async {
    await post('/merchant-orders/$id/ready', {});
  }

  Future<List<ProductCategory>> getMyStoreMenu() async {
    final data = await get('/my-store/categories');
    final list = data['categories'] as List<dynamic>? ?? [];
    return list.map((c) => ProductCategory.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<void> createCategory(String name) async {
    await post('/my-store/categories', {'name': name});
  }

  Future<Product> createProduct(String catId, Map<String, dynamic> body) async {
    final data = await post('/my-store/categories/$catId/products', body);
    return Product.fromJson(data['product'] as Map<String, dynamic>);
  }

  /// Uploads a photo for a product owned by the calling merchant.
  /// Returns the new image URL.
  Future<String> uploadProductImage(String productId, File imageFile) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl/my-store/products/$productId/image');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    final streamed = await req.send().timeout(_kTimeout);
    final body = await http.Response.fromStream(streamed);
    final data = _handleResponse(body);
    return data['image_url'] as String;
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> body) async {
    await put('/my-store/products/$productId', body);
  }

  Future<void> deleteProduct(String productId) async {
    final headers = await _headers();
    await _client.delete(
      Uri.parse('$baseUrl/my-store/products/$productId'),
      headers: headers,
    );
  }

  Future<void> toggleProductAvailability(String productId, bool available) async {
    await put('/my-store/products/$productId/toggle', {'is_available': available});
  }

  Future<void> toggleStoreOpen(bool open) async {
    await put('/my-store/toggle-open', {'is_open': open});
  }

  Future<void> toggleSelfDeliver(bool enabled) async {
    await put('/my-store/toggle-self-deliver', {'can_self_deliver': enabled});
  }

  Future<void> setSelfDeliveryFee(double fee) async {
    await put('/my-store/self-delivery-fee', {'self_delivery_fee': fee});
  }

  Future<Merchant> getMyMerchant() async {
    final data = await get('/my-store');
    return Merchant.fromJson(data['merchant'] as Map<String, dynamic>);
  }

  // ── Driver ────────────────────────────────────────────────────────────────

  Future<void> setDriverStatus(bool online) async {
    await patch('/driver/status', {'online': online});
  }

  Future<List<Map<String, dynamic>>> getAvailableJobs() async {
    final data = await get('/driver-orders/available');
    final list = data['orders'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> acceptDelivery(String orderId) async {
    return await post('/driver-orders/$orderId/accept', {});
  }

  Future<Map<String, dynamic>> markPickedUp(String orderId) async {
    return await post('/driver-orders/$orderId/pickup', {});
  }

  Future<Map<String, dynamic>> markDelivered(String orderId) async {
    return await post('/driver-orders/$orderId/deliver', {});
  }

  Future<Map<String, dynamic>> getDriverWallet() async {
    return await get('/driver/wallet');
  }

  // --- Chat ---

  Future<List<Map<String, dynamic>>> getOrderChat(String orderId) async {
    final data = await get('/orders/$orderId/chat');
    final list = data['messages'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> sendChatMessage(String orderId, String text) async {
    await post('/orders/$orderId/chat', {'text': text});
  }

  Future<List<Map<String, dynamic>>> getDriverOrderChat(String orderId) async {
    final data = await get('/driver-orders/$orderId/chat');
    final list = data['messages'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> sendDriverChatMessage(String orderId, String text) async {
    await post('/driver-orders/$orderId/chat', {'text': text});
  }

  // --- Notifications ---

  Future<void> saveDeviceToken(String token) async {
    await put('/auth/device-token', {'token': token});
  }

  // --- Support Chat ---

  Future<List<SupportMessage>> getSupportMessages() async {
    final data = await get('/support/messages');
    final list = data['messages'] as List? ?? [];
    return list.map((m) => SupportMessage.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<void> sendSupportMessage(String text) async {
    await post('/support/messages', {'text': text});
  }

  // Admin support
  Future<List<Map<String, dynamic>>> getAdminSupportUsers() async {
    final data = await get('/admin/support/users');
    final list = data['users'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<SupportMessage>> getAdminUserMessages(String userId) async {
    final data = await get('/admin/support/users/$userId/messages');
    final list = data['messages'] as List? ?? [];
    return list.map((m) => SupportMessage.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<void> sendAdminReply(String userId, String text) async {
    await post('/admin/support/users/$userId/messages', {'text': text});
  }

  // --- Google Auth ---

  Future<Map<String, dynamic>> googleLogin(String idToken, String role) async {
    return await post('/auth/google', {'id_token': idToken, 'role': role});
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
