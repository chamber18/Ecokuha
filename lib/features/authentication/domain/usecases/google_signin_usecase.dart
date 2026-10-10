import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';
import '../../data/models/auth_response_model.dart';

class GoogleSignInUseCase implements UseCase<AuthResponse, GoogleSignInParams> {
  final AuthRepository repository;

  GoogleSignInUseCase({required this.repository});

  @override
  Future<Either<Failure, AuthResponse>> call(GoogleSignInParams params) async {
    return await repository.signInWithGoogle(role: params.role);
  }
}

class GoogleSignInParams extends Equatable {
  final String? role;

  const GoogleSignInParams({this.role});

  @override
  List<Object?> get props => [role];
}

class NoParams extends Equatable {
  @override
  List<Object> get props => [];
}
