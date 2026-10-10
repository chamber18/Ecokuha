import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';
import '../entities/auth_user_entity.dart';
import '../../data/models/register_request_model.dart';
import '../../data/models/auth_response_model.dart';

class RegisterUseCase implements UseCase<AuthResponse, RegisterParams> {
  final AuthRepository repository;

  RegisterUseCase({required this.repository});

  @override
  Future<Either<Failure, AuthResponse>> call(RegisterParams params) async {
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

    if (params.password != params.confirmPassword) {
      return Left(ValidationFailure('Passwords do not match'));
    }

    // Create register request
    final request = RegisterRequest(
      email: params.email.trim().toLowerCase(),
      password: params.password,
      confirmPassword: params.confirmPassword,
      role: params.role,
      fullName: params.fullName,
    );

    // Call repository
    return await repository.register(request);
  }
}

class RegisterParams extends Equatable {
  final String email;
  final String password;
  final String confirmPassword;
  final UserRole role;
  final String? fullName;

  const RegisterParams({
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.role,
    this.fullName,
  });

  @override
  List<Object?> get props => [email, password, confirmPassword, role, fullName];
}
