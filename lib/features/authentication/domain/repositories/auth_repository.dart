import 'package:dartz/dartz.dart';
import '../entities/auth_user_entity.dart';
import '../../data/models/login_request_model.dart';
import '../../data/models/register_request_model.dart';
import '../../data/models/auth_response_model.dart';
import '../../../../core/error/failures.dart';

abstract class AuthRepository {
  /// Login user with email and password
  Future<Either<Failure, AuthResponse>> login(LoginRequest request);

  /// Register new user
  Future<Either<Failure, AuthResponse>> register(RegisterRequest request);

  /// Sign in with Google
  Future<Either<Failure, AuthResponse>> signInWithGoogle({String? role});

  /// Logout current user
  Future<Either<Failure, void>> logout();

  /// Get current authenticated user
  Future<Either<Failure, AuthUserEntity>> getCurrentUser();

  /// Refresh authentication token
  Future<Either<Failure, AuthResponse>> refreshToken(String refreshToken);

  /// Check if user is authenticated
  Future<bool> isAuthenticated();

  /// Get stored access token
  Future<String?> getAccessToken();

  /// Clear all auth data
  Future<void> clearAuthData();
}
