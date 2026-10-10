import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';
import '../../data/models/login_request_model.dart';
import '../../data/models/auth_response_model.dart';

class LoginUseCase implements UseCase<AuthResponse, LoginParams> {
  final AuthRepository repository;

  LoginUseCase({required this.repository});

  @override
  Future<Either<Failure, AuthResponse>> call(LoginParams params) async {
    // Input validation
    if (params.email.isEmpty || params.password.isEmpty) {
      return Left(ValidationFailure('Email and password cannot be empty'));
    }

    if (!params.email.contains('@')) {
      return Left(ValidationFailure('Invalid email format'));
    }

    if (params.password.length < 6) {
      return Left(ValidationFailure('Password must be at least 6 characters'));
    }

    // Create login request
    final request = LoginRequest(
      email: params.email.trim().toLowerCase(),
      password: params.password,
      rememberMe: params.rememberMe,
    );

    // Call repository
    return await repository.login(request);
  }
}

class LoginParams extends Equatable {
  final String email;
  final String password;
  final bool rememberMe;

  const LoginParams({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });

  @override
  List<Object> get props => [email, password, rememberMe];
}
