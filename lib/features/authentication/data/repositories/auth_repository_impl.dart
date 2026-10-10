import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../models/login_request_model.dart';
import '../models/register_request_model.dart';
import '../models/auth_response_model.dart';
import '../models/auth_user_model.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  final http.Client httpClient;
  final SharedPreferences sharedPreferences;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _isAuthenticatedKey = 'is_authenticated';

  AuthRepositoryImpl({
    required this.httpClient,
    required this.sharedPreferences,
  });

  @override
  Future<Either<Failure, AuthResponse>> login(LoginRequest request) async {
    try {
      final response = await httpClient.post(
        Uri.parse('${ApiClient.baseUrl}/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(json.decode(response.body));

        if (authResponse.success) {
          // Store tokens and user data
          await _storeAuthData(
            accessToken: authResponse.accessToken!,
            refreshToken: authResponse.refreshToken!,
            userData: authResponse.user!.toEntity(),
          );

          return Right(authResponse);
        } else {
          return Left(AuthFailure(authResponse.message));
        }
      } else if (response.statusCode == 401) {
        final errorData = json.decode(response.body);
        return Left(AuthFailure(errorData['message'] ?? 'Invalid credentials'));
      } else if (response.statusCode == 422) {
        final errorData = json.decode(response.body);
        return Left(
          ValidationFailure(errorData['message'] ?? 'Validation failed'),
        );
      } else {
        final errorData = json.decode(response.body);
        return Left(
          ServerFailure(
            'Server error: ${response.statusCode}',
            response.statusCode.toString(),
            errorData,
          ),
        );
      }
    } on SocketException {
      return Left(NetworkFailure('No internet connection'));
    } on FormatException {
      return Left(ServerFailure('Invalid response format'));
    } catch (e) {
      return Left(UnknownFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> register(
    RegisterRequest request,
  ) async {
    try {
      final response = await httpClient.post(
        Uri.parse('${ApiClient.baseUrl}/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(json.decode(response.body));

        if (authResponse.success) {
          // Store tokens and user data
          await _storeAuthData(
            accessToken: authResponse.accessToken!,
            refreshToken: authResponse.refreshToken!,
            userData: authResponse.user!.toEntity(),
          );

          return Right(authResponse);
        } else {
          return Left(AuthFailure(authResponse.message));
        }
      } else if (response.statusCode == 409) {
        final errorData = json.decode(response.body);
        return Left(AuthFailure(errorData['message'] ?? 'User already exists'));
      } else if (response.statusCode == 422) {
        final errorData = json.decode(response.body);
        return Left(
          ValidationFailure(errorData['message'] ?? 'Validation failed'),
        );
      } else {
        final errorData = json.decode(response.body);
        return Left(
          ServerFailure(
            'Server error: ${response.statusCode}',
            response.statusCode.toString(),
            errorData,
          ),
        );
      }
    } on SocketException {
      return Left(NetworkFailure('No internet connection'));
    } on FormatException {
      return Left(ServerFailure('Invalid response format'));
    } catch (e) {
      return Left(UnknownFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final accessToken = await getAccessToken();

      if (accessToken != null) {
        // Call logout endpoint
        final response = await httpClient.post(
          Uri.parse('${ApiClient.baseUrl}/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        );

        // Clear local data regardless of server response
        await clearAuthData();

        if (response.statusCode == 200 || response.statusCode == 204) {
          return const Right(null);
        } else {
          // Still return success since we cleared local data
          return const Right(null);
        }
      } else {
        // No token, just clear any remaining data
        await clearAuthData();
        return const Right(null);
      }
    } on SocketException {
      // Clear local data even if network fails
      await clearAuthData();
      return const Right(null);
    } catch (e) {
      // Clear local data even if logout call fails
      await clearAuthData();
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, AuthUserEntity>> getCurrentUser() async {
    try {
      final isAuth = await isAuthenticated();
      if (!isAuth) {
        return Left(AuthFailure('User not authenticated'));
      }

      final userDataString = sharedPreferences.getString(_userDataKey);
      if (userDataString != null) {
        final userData = json.decode(userDataString);
        final userModel = AuthUserModel.fromJson(userData);
        return Right(userModel.toEntity());
      }

      // If no cached user data, try to fetch from server
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        return Left(AuthFailure('No access token available'));
      }

      final response = await httpClient.get(
        Uri.parse('${ApiClient.baseUrl}/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        final userModel = AuthUserModel.fromJson(userData['user']);

        // Cache the user data
        await sharedPreferences.setString(
          _userDataKey,
          json.encode(userModel.toJson()),
        );

        return Right(userModel.toEntity());
      } else if (response.statusCode == 401) {
        // Token might be expired, clear auth data
        await clearAuthData();
        return Left(AuthFailure('Authentication expired'));
      } else {
        return Left(ServerFailure('Failed to fetch user data'));
      }
    } on SocketException {
      return Left(NetworkFailure('No internet connection'));
    } catch (e) {
      return Left(
        UnknownFailure('Error getting current user: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> refreshToken(
    String refreshToken,
  ) async {
    try {
      final response = await httpClient.post(
        Uri.parse('${ApiClient.baseUrl}/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(json.decode(response.body));

        if (authResponse.success && authResponse.accessToken != null) {
          // Update stored tokens
          await sharedPreferences.setString(
            _accessTokenKey,
            authResponse.accessToken!,
          );
          if (authResponse.refreshToken != null) {
            await sharedPreferences.setString(
              _refreshTokenKey,
              authResponse.refreshToken!,
            );
          }

          return Right(authResponse);
        } else {
          await clearAuthData();
          return Left(AuthFailure('Failed to refresh token'));
        }
      } else if (response.statusCode == 401) {
        // Refresh token is invalid, clear auth data
        await clearAuthData();
        return Left(AuthFailure('Refresh token expired'));
      } else {
        return Left(ServerFailure('Token refresh failed'));
      }
    } on SocketException {
      return Left(NetworkFailure('No internet connection'));
    } catch (e) {
      return Left(UnknownFailure('Token refresh error: ${e.toString()}'));
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final hasFlag = sharedPreferences.getBool(_isAuthenticatedKey) ?? false;
    final hasToken = sharedPreferences.getString(_accessTokenKey) != null;
    return hasFlag && hasToken;
  }

  @override
  Future<String?> getAccessToken() async {
    return sharedPreferences.getString(_accessTokenKey);
  }

  @override
  Future<void> clearAuthData() async {
    await Future.wait([
      sharedPreferences.remove(_accessTokenKey),
      sharedPreferences.remove(_refreshTokenKey),
      sharedPreferences.remove(_userDataKey),
      sharedPreferences.remove(_isAuthenticatedKey),
    ]);
  }

  /// Store authentication data after successful login/register
  Future<void> _storeAuthData({
    required String accessToken,
    required String refreshToken,
    required AuthUserEntity userData,
  }) async {
    final userModel = AuthUserModel.fromEntity(userData);

    await Future.wait([
      sharedPreferences.setString(_accessTokenKey, accessToken),
      sharedPreferences.setString(_refreshTokenKey, refreshToken),
      sharedPreferences.setString(
        _userDataKey,
        json.encode(userModel.toJson()),
      ),
      sharedPreferences.setBool(_isAuthenticatedKey, true),
    ]);
  }

  @override
  Future<Either<Failure, AuthResponse>> signInWithGoogle({String? role}) async {
    return Left(
      ServerFailure('Google Sign-In is not supported in this build.'),
    );
  }
}
