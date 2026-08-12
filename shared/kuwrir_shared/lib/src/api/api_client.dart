import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'api_logger.dart';
import '../models/merchant.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/product_search_result.dart';
import '../models/order.dart';
import '../models/order_quote.dart';
import '../models/support_message.dart';
import '../models/food_category.dart';
import '../models/promotion.dart';
import '../models/promo_banner.dart';
import '../models/wallet.dart';
import '../models/address.dart';

/// HTTP API client with JWT token management
class ApiClient {
  final String baseUrl;
  final http.Client _client;
  static const _secureStorage = FlutterSecureStorage();

  ApiClient({String? baseUrl})
    : baseUrl = baseUrl ?? ApiConfig.baseUrl,
      _client = http.Client();

  /// One-time move off SharedPreferences (plaintext) onto secure storage —
  /// safe to call repeatedly, it's a no-op once migrated.
  Future<void> _migrateLegacyTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString('auth_token');
    if (legacyToken == null) return;
    final legacyRefresh = prefs.getString('refresh_token') ?? '';
    await _secureStorage.write(key: 'auth_token', value: legacyToken);
    await _secureStorage.write(key: 'refresh_token', value: legacyRefresh);
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  /// Get stored JWT access token
  Future<String?> _getToken() async {
    await _migrateLegacyTokens();
    return _secureStorage.read(key: 'auth_token');
  }

  /// Get stored JWT token (public — used for building multipart requests)
  Future<String?> getToken() => _getToken();

  Future<String?> _getRefreshToken() async {
    await _migrateLegacyTokens();
    return _secureStorage.read(key: 'refresh_token');
  }

  /// Store JWT token
  Future<void> saveToken(String token, String refreshToken) async {
    await _secureStorage.write(key: 'auth_token', value: token);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
  }

  /// Clear stored tokens (logout)
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'refresh_token');
  }

  /// Opt-in flag for the biometric/device-lock quick re-auth gate. Declining
  /// just leaves this unset — re-prompted on the next fresh login.
  Future<bool> isBiometricLockEnabled() async {
    return (await _secureStorage.read(key: 'biometric_lock_enabled')) == 'true';
  }

  Future<void> setBiometricLockEnabled(bool enabled) async {
    await _secureStorage.write(
      key: 'biometric_lock_enabled',
      value: enabled.toString(),
    );
  }

  /// Exchanges the stored refresh token for a new access+refresh pair.
  /// Returns false (without throwing) on any failure, so callers can fall
  /// back to a normal "session expired" flow.
  Future<bool> _tryRefresh() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await _logged(
        'POST',
        '/auth/refresh',
        body: {'refresh_token': '(redacted)'},
        send:
            () => _client
                .post(
                  Uri.parse('$baseUrl/auth/refresh'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                  body: jsonEncode({'refresh_token': refreshToken}),
                )
                .timeout(_kTimeout),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['token'] == null) return false;
      await saveToken(
        body['token'] as String,
        body['refresh_token'] as String? ?? '',
      );
      return true;
    } catch (_) {
      return false;
    }
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

  /// Runs [send] once; on a 401 (and only when [auth] is set, so public
  /// endpoints never trigger this) attempts exactly one silent token
  /// refresh and retries [send] once with the refreshed headers. Every
  /// existing caller's "catch failure -> clear tokens -> go to /login" flow
  /// keeps working unchanged — it just fires less often now.
  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function(Map<String, String> headers) send, {
    required bool auth,
  }) async {
    var response = await send(await _headers(auth: auth)).timeout(_kTimeout);
    if (auth && response.statusCode == 401 && await _tryRefresh()) {
      response = await send(await _headers(auth: auth)).timeout(_kTimeout);
    }
    return response;
  }

  /// Runs [send], logging the request/response pair (method, URL, body,
  /// status, elapsed time) to the debug console — every JSON call funnels
  /// through here so nothing needs its own logging.
  Future<http.Response> _logged(
    String method,
    String endpoint, {
    Object? body,
    required Future<http.Response> Function() send,
  }) async {
    final url = '$baseUrl$endpoint';
    ApiLogger.request(method: method, url: url, body: body);
    final sw = Stopwatch()..start();
    final response = await send();
    sw.stop();
    ApiLogger.response(
      method: method,
      url: url,
      statusCode: response.statusCode,
      rawBody: response.body,
      elapsed: sw.elapsed,
    );
    return response;
  }

  /// GET request
  Future<Map<String, dynamic>> get(String endpoint, {bool auth = true}) async {
    final response = await _logged(
      'GET',
      endpoint,
      send:
          () => _sendWithRetry(
            (headers) =>
                _client.get(Uri.parse('$baseUrl$endpoint'), headers: headers),
            auth: auth,
          ),
    );
    return _handleResponse(response);
  }

  /// POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await _logged(
      'POST',
      endpoint,
      body: body,
      send:
          () => _sendWithRetry(
            (headers) => _client.post(
              Uri.parse('$baseUrl$endpoint'),
              headers: headers,
              body: jsonEncode(body),
            ),
            auth: auth,
          ),
    );
    return _handleResponse(response);
  }

  /// PUT request
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await _logged(
      'PUT',
      endpoint,
      body: body,
      send:
          () => _sendWithRetry(
            (headers) => _client.put(
              Uri.parse('$baseUrl$endpoint'),
              headers: headers,
              body: jsonEncode(body),
            ),
            auth: auth,
          ),
    );
    return _handleResponse(response);
  }

  /// PATCH request
  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await _logged(
      'PATCH',
      endpoint,
      body: body,
      send:
          () => _sendWithRetry(
            (headers) => _client.patch(
              Uri.parse('$baseUrl$endpoint'),
              headers: headers,
              body: jsonEncode(body),
            ),
            auth: auth,
          ),
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

  // ── Customer: Merchant Browsing ──────────────────────────────────────────

  Future<List<Merchant>> getMerchants({String? category}) async {
    final query = category != null ? '?category=$category' : '';
    final data = await get('/merchants$query');
    final list = data['merchants'] as List<dynamic>? ?? [];
    return list
        .map((m) => Merchant.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<Merchant>> getPopularMerchants({String? foodCategoryId}) async {
    final query =
        foodCategoryId != null ? '?food_category_id=$foodCategoryId' : '';
    final data = await get('/merchants/popular$query', auth: false);
    final list = data['merchants'] as List<dynamic>? ?? [];
    return list
        .map((m) => Merchant.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<Merchant>> getNearbyMerchants({
    required double lat,
    required double lng,
    double radiusKm = 5,
    String? foodCategoryId,
  }) async {
    final params = <String>[
      'lat=$lat',
      'lng=$lng',
      'radius=$radiusKm',
      if (foodCategoryId != null) 'food_category_id=$foodCategoryId',
    ];
    final data = await get(
      '/merchants/nearby?${params.join('&')}',
      auth: false,
    );
    final list = data['merchants'] as List<dynamic>? ?? [];
    return list
        .map((m) => Merchant.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<FoodCategory>> getFoodCategories() async {
    final data = await get('/food-categories', auth: false);
    final list = data['food_categories'] as List<dynamic>? ?? [];
    return list
        .map((c) => FoodCategory.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<List<Promotion>> getActivePromotions() async {
    final data = await get('/promotions/active', auth: false);
    final list = data['promotions'] as List<dynamic>? ?? [];
    return list
        .map((p) => Promotion.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<List<PromoBanner>> getActiveBanners() async {
    final data = await get('/banners/active', auth: false);
    final list = data['banners'] as List<dynamic>? ?? [];
    return list
        .map((b) => PromoBanner.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<List<Merchant>> searchMerchants(String q) async {
    if (q.isEmpty) return [];
    final data = await get(
      '/merchants/search?q=${Uri.encodeQueryComponent(q)}',
      auth: false,
    );
    final list = data['merchants'] as List<dynamic>? ?? [];
    return list
        .map((m) => Merchant.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductSearchResult>> searchProducts({
    String? q,
    String? foodCategoryId,
    bool discount = false,
    bool freeDelivery = false,
  }) async {
    final params = <String>[
      if (q != null && q.isNotEmpty) 'q=${Uri.encodeQueryComponent(q)}',
      if (foodCategoryId != null) 'food_category_id=$foodCategoryId',
      if (discount) 'discount=true',
      if (freeDelivery) 'free_delivery=true',
    ];
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final data = await get('/products/search$query', auth: false);
    final list = data['products'] as List<dynamic>? ?? [];
    return list
        .map((p) => ProductSearchResult.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductSearchResult>> getPopularProducts() async {
    final data = await get('/products/popular', auth: false);
    final list = data['products'] as List<dynamic>? ?? [];
    return list
        .map((p) => ProductSearchResult.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<Merchant> getMerchant(String id) async {
    final data = await get('/merchants/$id');
    return Merchant.fromJson(data['merchant'] as Map<String, dynamic>);
  }

  Future<List<ProductCategory>> getMerchantMenu(String merchantId) async {
    final data = await get('/merchants/$merchantId/products');
    final list = data['categories'] as List<dynamic>?;
    if (list != null) {
      return list
          .map((c) => ProductCategory.fromJson(c as Map<String, dynamic>))
          .toList();
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

  /// Real delivery fee/tax/total for a cart, without creating an order —
  /// backs the checkout confirmation screen shown after Cart, since Cart
  /// itself only ever shows a flat delivery-fee estimate.
  Future<OrderQuote> quoteOrder(Map<String, dynamic> body) async {
    final data = await post('/orders/quote', body);
    return OrderQuote.fromJson(data);
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
    return list
        .map((c) => ProductCategory.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<void> createCategory(String name) async {
    await post('/my-store/categories', {'name': name});
  }

  /// Throws [ApiException] (400) with a clear message when the category
  /// still has products — unlike deleteProduct/deleteVariant, this one
  /// surfaces backend errors instead of firing-and-forgetting, since "why
  /// didn't it delete" is exactly what the merchant needs to see here.
  Future<void> deleteCategory(String catId) async {
    final response = await _logged(
      'DELETE',
      '/my-store/categories/$catId',
      send:
          () => _sendWithRetry(
            (headers) => _client.delete(
              Uri.parse('$baseUrl/my-store/categories/$catId'),
              headers: headers,
            ),
            auth: true,
          ),
    );
    _handleResponse(response);
  }

  Future<Product> createProduct(String catId, Map<String, dynamic> body) async {
    final data = await post('/my-store/categories/$catId/products', body);
    return Product.fromJson(data['product'] as Map<String, dynamic>);
  }

  /// Sends a single-file multipart POST, logging it like every other
  /// request. Used by the three image/logo/banner upload endpoints.
  Future<http.Response> _loggedMultipart(
    String endpoint,
    File imageFile,
  ) async {
    final url = '$baseUrl$endpoint';
    ApiLogger.request(method: 'POST', url: url, body: {'file': imageFile.path});
    final token = await _getToken();
    final uri = Uri.parse(url);
    final req =
        http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            await http.MultipartFile.fromPath('image', imageFile.path),
          );
    final sw = Stopwatch()..start();
    final streamed = await req.send().timeout(_kTimeout);
    final response = await http.Response.fromStream(streamed);
    sw.stop();
    ApiLogger.response(
      method: 'POST',
      url: url,
      statusCode: response.statusCode,
      rawBody: response.body,
      elapsed: sw.elapsed,
    );
    return response;
  }

  /// Uploads a photo for a product owned by the calling merchant.
  /// Returns the new image URL.
  Future<String> uploadProductImage(String productId, File imageFile) async {
    final body = await _loggedMultipart(
      '/my-store/products/$productId/image',
      imageFile,
    );
    final data = _handleResponse(body);
    return data['image_url'] as String;
  }

  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> body,
  ) async {
    await put('/my-store/products/$productId', body);
  }

  Future<String> uploadStoreLogo(File imageFile) async {
    final body = await _loggedMultipart('/my-store/logo', imageFile);
    final data = _handleResponse(body);
    return data['logo_url'] as String;
  }

  Future<String> uploadStoreBanner(File imageFile) async {
    final body = await _loggedMultipart('/my-store/banner', imageFile);
    final data = _handleResponse(body);
    return data['banner_url'] as String;
  }

  // ── Merchant: Promo Codes ──────────────────────────────────────────────
  // Raw maps (not a shared model) since this view needs every field the
  // backend stores (usage_limit, used_count, is_active, dates), unlike the
  // trimmed customer-facing Promotion model above.

  Future<List<Map<String, dynamic>>> getMyPromotions() async {
    final data = await get('/my-store/promotions');
    final list = data['promotions'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> createMyPromotion(Map<String, dynamic> body) async {
    await post('/my-store/promotions', body);
  }

  Future<void> updateMyPromotion(String id, Map<String, dynamic> body) async {
    await put('/my-store/promotions/$id', body);
  }

  Future<void> deleteMyPromotion(String id) async {
    await _logged(
      'DELETE',
      '/my-store/promotions/$id',
      send:
          () async => _client.delete(
            Uri.parse('$baseUrl/my-store/promotions/$id'),
            headers: await _headers(),
          ),
    );
  }

  Future<void> toggleMyPromotion(String id) async {
    await put('/my-store/promotions/$id/toggle', {});
  }

  // ── Merchant: Homepage Banner Slots ────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMyBanners() async {
    final data = await get('/my-store/banners');
    final list = data['banners'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createMyBanner(Map<String, dynamic> body) async {
    final data = await post('/my-store/banners', body);
    return data['banner'] as Map<String, dynamic>;
  }

  Future<String> uploadMyBannerImage(String bannerId, File imageFile) async {
    final body = await _loggedMultipart(
      '/my-store/banners/$bannerId/image',
      imageFile,
    );
    final data = _handleResponse(body);
    return data['image_url'] as String;
  }

  Future<void> deleteProduct(String productId) async {
    await _logged(
      'DELETE',
      '/my-store/products/$productId',
      send:
          () async => _client.delete(
            Uri.parse('$baseUrl/my-store/products/$productId'),
            headers: await _headers(),
          ),
    );
  }

  Future<void> toggleProductAvailability(
    String productId,
    bool available,
  ) async {
    await put('/my-store/products/$productId/toggle', {
      'is_available': available,
    });
  }

  Future<ProductVariant> createVariant(
    String productId,
    Map<String, dynamic> body,
  ) async {
    final data = await post('/my-store/products/$productId/variants', body);
    return ProductVariant.fromJson(data['variant'] as Map<String, dynamic>);
  }

  Future<void> deleteVariant(String variantId) async {
    await _logged(
      'DELETE',
      '/my-store/variants/$variantId',
      send:
          () async => _client.delete(
            Uri.parse('$baseUrl/my-store/variants/$variantId'),
            headers: await _headers(),
          ),
    );
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

  Future<void> updateTaxSettings({
    required bool taxEnabled,
    double? taxRate,
  }) async {
    await put('/my-store', {'tax_enabled': taxEnabled, 'tax_rate': taxRate});
  }

  Future<void> toggleFreeDelivery(bool enabled) async {
    await put('/my-store', {'is_free_delivery': enabled});
  }

  Future<void> updateMerchantDetails({
    String? name,
    String? phone,
    String? address,
  }) async {
    await put('/my-store', {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
    });
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

  /// The order the driver already accepted and hasn't finished delivering
  /// yet, if any — null otherwise. Lets the app resume the active-delivery
  /// screen after a restart instead of losing track of an in-progress order
  /// (it's deliberately excluded from getAvailableJobs once accepted).
  Future<Map<String, dynamic>?> getCurrentDelivery() async {
    final data = await get('/driver-orders/current');
    return data['order'] as Map<String, dynamic>?;
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

  /// Road-following distance/duration (merchant -> dropoff) for the active-delivery map,
  /// via OpenRouteService server-side. Response always has `distance_km`; `duration_min` and
  /// `source` ("road" vs "straight_line") let the caller show an honest label if ORS wasn't
  /// reachable and the backend fell back to the straight-line haversine distance.
  Future<Map<String, dynamic>> getDriverRoadRoute(String orderId) async {
    return await get('/driver-orders/$orderId/road-route');
  }

  // --- Merchant wallet ---

  Future<Wallet> getMerchantWallet() async {
    final data = await get('/my-store/wallet');
    return Wallet.fromJson(data['wallet'] as Map<String, dynamic>);
  }

  Future<List<WalletTransaction>> getMerchantWalletTransactions() async {
    final data = await get('/my-store/wallet/transactions');
    final list = data['transactions'] as List<dynamic>? ?? [];
    return list
        .map((t) => WalletTransaction.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> withdrawMerchant({
    required double amount,
    required String bankCode,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    return await post('/my-store/wallet/withdraw', {
      'amount': amount,
      'bank_code': bankCode,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
    });
  }

  Future<Map<String, dynamic>> getMerchantDashboardSummary() async {
    return await get('/my-store/dashboard-summary');
  }

  // --- Driver wallet ---

  Future<List<WalletTransaction>> getDriverWalletTransactions() async {
    final data = await get('/driver/wallet/transactions');
    final list = data['transactions'] as List<dynamic>? ?? [];
    return list
        .map((t) => WalletTransaction.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> withdrawDriver({
    required double amount,
    String bankCode = '',
    String bankAccountNumber = '',
    String bankAccountName = '',
  }) async {
    return await post('/driver/wallet/withdraw', {
      'amount': amount,
      'bank_code': bankCode,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
    });
  }

  Future<Map<String, dynamic>> depositDriverCOD({
    required double amount,
    String method = 'cash',
    String reference = '',
  }) async {
    return await post('/driver/cod/deposit', {
      'amount': amount,
      'method': method,
      'reference': reference,
    });
  }

  // --- Customer wallet ---

  Future<Wallet> getCustomerWallet() async {
    final data = await get('/customer/wallet');
    return Wallet.fromJson(data['wallet'] as Map<String, dynamic>);
  }

  Future<List<WalletTransaction>> getCustomerWalletTransactions() async {
    final data = await get('/customer/wallet/transactions');
    final list = data['transactions'] as List<dynamic>? ?? [];
    return list
        .map((t) => WalletTransaction.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> withdrawCustomer({
    required double amount,
    String bankCode = '',
    String bankAccountNumber = '',
    String bankAccountName = '',
  }) async {
    return await post('/customer/wallet/withdraw', {
      'amount': amount,
      'bank_code': bankCode,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
    });
  }

  Future<Map<String, dynamic>> topupCustomerWallet({
    required double amount,
    required String paymentMethod,
  }) async {
    return await post('/customer/wallet/topup', {
      'amount': amount,
      'payment_method': paymentMethod,
    });
  }

  // --- Order payment (Duitku) ---

  /// Live payment channels enabled for the merchant account at [amount] —
  /// fees can vary per amount tier, so this is re-fetched once the real
  /// order total is known rather than cached.
  Future<List<Map<String, dynamic>>> getPaymentMethods(double amount) async {
    final data = await get('/payment/methods?amount=${amount.round()}');
    final list = data['payment_methods'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Creates a Duitku payment link for an already-placed non-cash order.
  /// Returns the raw response (`payment_url`, `payment_ref`, `expires_at`).
  Future<Map<String, dynamic>> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    String email = '',
  }) async {
    return await post('/payment/$orderId/create', {
      'payment_method': paymentMethod,
      if (email.isNotEmpty) 'email': email,
    });
  }

  // --- Saved bank account (customer/driver/merchant, role-agnostic) ---

  Future<Map<String, dynamic>?> getBankAccount() async {
    try {
      return await get('/me/bank-account');
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> saveBankAccount({
    required String bankCode,
    required String accountNumber,
    required String accountName,
  }) async {
    return await put('/me/bank-account', {
      'bank_code': bankCode,
      'account_number': accountNumber,
      'account_name': accountName,
    });
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
    return list
        .map((m) => SupportMessage.fromJson(m as Map<String, dynamic>))
        .toList();
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
    return list
        .map((m) => SupportMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendAdminReply(String userId, String text) async {
    await post('/admin/support/users/$userId/messages', {'text': text});
  }

  // --- Phone + OTP Auth ---

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    return await post('/auth/otp/request', {'phone': phone});
  }

  /// [role] only matters for auto-registering a brand-new phone number
  /// (merchant_app/driver_app pass their own role; customer_app leaves it
  /// null and defaults to customer). [agreeTerms] is required when this call
  /// ends up auto-registering a brand-new customer account — the backend
  /// rejects with `requires_terms: true` otherwise.
  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code, {
    String? role,
    bool agreeTerms = false,
  }) async {
    return await post('/auth/otp/verify', {
      'phone': phone,
      'code': code,
      if (role != null) 'role': role,
      'agree_terms': agreeTerms,
    });
  }

  Future<User> getMe() async {
    final data = await get('/auth/me');
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Attaches and verifies a real phone number on the currently
  /// authenticated account. Throws [ApiException] on invalid/expired code
  /// or if the phone is already used on a different account.
  Future<User> verifyMyPhone(String phone, String code) async {
    final data = await post('/auth/verify-phone', {
      'phone': phone,
      'code': code,
    });
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Fills in profile fields OTP login never asks for (name/email) — phone
  /// is the only required identity. Throws [ApiException] (409) if the
  /// email is already used on a different account.
  Future<User> updateProfile({String? name, String? email}) async {
    final data = await put('/auth/me', {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Permanently deactivates and soft-deletes the current account. Throws
  /// [ApiException] (409) if the account still holds COD cash or wallet
  /// balance that must be settled first. Callers must clear local tokens
  /// and navigate to the login screen themselves after this succeeds.
  Future<void> deleteAccount() async {
    final response = await _logged(
      'DELETE',
      '/auth/me',
      send:
          () => _sendWithRetry(
            (headers) =>
                _client.delete(Uri.parse('$baseUrl/auth/me'), headers: headers),
            auth: true,
          ),
    );
    _handleResponse(response);
  }

  // --- Saved Addresses ---

  Future<List<SavedAddress>> getAddresses() async {
    final data = await get('/addresses');
    final list = data['addresses'] as List<dynamic>? ?? [];
    return list
        .map((a) => SavedAddress.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<SavedAddress> createAddress({
    required String label,
    required String address,
    String detail = '',
    required double lat,
    required double lng,
    bool isDefault = false,
  }) async {
    final data = await post('/addresses', {
      'label': label,
      'address': address,
      'detail': detail,
      'latitude': lat,
      'longitude': lng,
      'is_default': isDefault,
    });
    return SavedAddress.fromJson(data['address'] as Map<String, dynamic>);
  }

  Future<SavedAddress> updateAddress(
    String id, {
    required String label,
    required String address,
    String detail = '',
    required double lat,
    required double lng,
    bool isDefault = false,
  }) async {
    final data = await put('/addresses/$id', {
      'label': label,
      'address': address,
      'detail': detail,
      'latitude': lat,
      'longitude': lng,
      'is_default': isDefault,
    });
    return SavedAddress.fromJson(data['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String id) async {
    await _logged(
      'DELETE',
      '/addresses/$id',
      send:
          () async => _sendWithRetry(
            (headers) => _client.delete(
              Uri.parse('$baseUrl/addresses/$id'),
              headers: headers,
            ),
            auth: true,
          ),
    );
  }

  Future<void> setDefaultAddress(String id) async {
    await put('/addresses/$id/default', {});
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
