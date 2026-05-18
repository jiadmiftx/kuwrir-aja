/// User model matching the backend User struct
class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? avatarUrl;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatar_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'avatar_url': avatarUrl,
      'is_active': isActive,
    };
  }
}
