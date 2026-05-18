/// API configuration constants
class ApiConfig {
  /// Base URL of the KUWRIR backend API
  /// Use machine IP instead of localhost so simulators/emulators can connect
  static const String baseUrl = 'http://192.168.1.12:8080/api/v1';

  /// Request timeout in seconds
  static const int timeoutSeconds = 30;

  /// API endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String settings = '/admin/settings';
  static const String health = '/health';
}
