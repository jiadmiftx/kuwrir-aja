import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  User? _user;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> checkAuthStatus() async {
    _isAuthenticated = await _apiClient.isAuthenticated();
    if (_isAuthenticated) {
      try {
        final res = await _apiClient.get('/auth/me'); // Just mock/placeholder logic if /auth/me exists
        _user = User.fromJson(res['user']);
      } catch (e) {
        // If fetch fails, maybe token is invalid
        _isAuthenticated = false;
        await _apiClient.clearTokens();
      }
    }
    notifyListeners();
  }

  Future<bool> login(String phone, String password) async {
    try {
      final res = await _apiClient.post('/auth/login', {
        'phone': phone,
        'password': password,
      });
      final authResponse = AuthResponse.fromJson(res);
      await _apiClient.saveToken(authResponse.token, authResponse.refreshToken);
      _user = authResponse.user;
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _apiClient.clearTokens();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
