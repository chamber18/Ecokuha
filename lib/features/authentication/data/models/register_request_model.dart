import 'package:equatable/equatable.dart';
import '../../domain/entities/auth_user_entity.dart';

class RegisterRequest extends Equatable {
  final String email;
  final String password;
  final String confirmPassword;
  final UserRole role;
  final String? fullName;

  const RegisterRequest({
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.role,
    this.fullName,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim().toLowerCase(),
      'password': password,
      'confirm_password': confirmPassword,
      'role': role.name,
      if (fullName != null) 'full_name': fullName!.trim(),
    };
  }

  // Validation methods
  bool get isValid {
    return email.isNotEmpty &&
        password.isNotEmpty &&
        password == confirmPassword &&
        password.length >= 6 &&
        _isValidEmail(email);
  }

  String? get validationError {
    if (email.isEmpty) return 'Email is required';
    if (!_isValidEmail(email)) return 'Please enter a valid email';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (password != confirmPassword) return 'Passwords do not match';
    return null;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  @override
  List<Object?> get props => [email, password, confirmPassword, role, fullName];

  RegisterRequest copyWith({
    String? email,
    String? password,
    String? confirmPassword,
    UserRole? role,
    String? fullName,
  }) {
    return RegisterRequest(
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
    );
  }
}
