import 'user.dart';

/// Auth response from login/register API
class AuthResponse {
  final String token;
  final String refreshToken;
  final User user;

  AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Login request payload
class LoginRequest {
  final String phone;
  final String password;

  LoginRequest({required this.phone, required this.password});

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'password': password,
      };
}

/// Register request payload
class RegisterRequest {
  final String name;
  final String email;
  final String phone;
  final String password;
  final String role;

  RegisterRequest({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
      };
}
