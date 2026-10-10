import 'package:equatable/equatable.dart';
import 'auth_user_model.dart';

class AuthResponse extends Equatable {
  final bool success;
  final String message;
  final AuthUserModel? user;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn; // Token expiry in seconds
  final Map<String, dynamic>? errors;

  const AuthResponse({
    required this.success,
    required this.message,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.errors,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      user: json['user'] != null ? AuthUserModel.fromJson(json['user']) : null,
      accessToken: json['access_token'] ?? json['accessToken'],
      refreshToken: json['refresh_token'] ?? json['refreshToken'],
      expiresIn: json['expires_in'] ?? json['expiresIn'],
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (user != null) 'user': user!.toJson(),
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (expiresIn != null) 'expires_in': expiresIn,
      if (errors != null) 'errors': errors,
    };
  }

  // Factory constructors for common scenarios
  factory AuthResponse.success({
    required String message,
    AuthUserModel? user, // Made optional
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
  }) {
    return AuthResponse(
      success: true,
      message: message,
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
    );
  }

  factory AuthResponse.failure({
    required String message,
    Map<String, dynamic>? errors,
  }) {
    return AuthResponse(success: false, message: message, errors: errors);
  }

  // Getters for common error scenarios
  bool get isUnauthorized =>
      message.toLowerCase().contains('unauthorized') ||
      message.toLowerCase().contains('invalid credentials');

  bool get isValidationError => errors != null && errors!.isNotEmpty;

  bool get isNetworkError =>
      message.toLowerCase().contains('network') ||
      message.toLowerCase().contains('connection');

  String get displayMessage {
    if (isValidationError) {
      // Return first validation error
      final firstError = errors!.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        return firstError.first.toString();
      }
      return firstError.toString();
    }
    return message;
  }

  @override
  List<Object?> get props => [
    success,
    message,
    user,
    accessToken,
    refreshToken,
    expiresIn,
    errors,
  ];

  AuthResponse copyWith({
    bool? success,
    String? message,
    AuthUserModel? user,
    String? accessToken,
    String? refreshToken,
    int? expiresIn,
    Map<String, dynamic>? errors,
  }) {
    return AuthResponse(
      success: success ?? this.success,
      message: message ?? this.message,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresIn: expiresIn ?? this.expiresIn,
      errors: errors ?? this.errors,
    );
  }
}
