import 'package:equatable/equatable.dart';

abstract class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

class SubmitRegister extends RegisterEvent {
  final String email;
  final String password;
  final String confirmPassword;
  final String? role;

  const SubmitRegister({
    required this.email,
    required this.password,
    required this.confirmPassword,
    this.role,
  });

  @override
  List<Object?> get props => [email, password, confirmPassword, role];
}

class SocialRegisterPressed extends RegisterEvent {
  final String provider; // 'google' | 'apple'
  final String? role;

  const SocialRegisterPressed({required this.provider, this.role});

  @override
  List<Object?> get props => [provider, role];
}
