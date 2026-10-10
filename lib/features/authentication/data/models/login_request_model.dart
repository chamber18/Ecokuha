import 'package:equatable/equatable.dart';

class LoginRequest extends Equatable {
  final String email;
  final String password;
  final bool rememberMe;

  const LoginRequest({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim().toLowerCase(),
      'password': password,
      'remember_me': rememberMe,
    };
  }

  @override
  List<Object?> get props => [email, password, rememberMe];

  LoginRequest copyWith({String? email, String? password, bool? rememberMe}) {
    return LoginRequest(
      email: email ?? this.email,
      password: password ?? this.password,
      rememberMe: rememberMe ?? this.rememberMe,
    );
  }
}
