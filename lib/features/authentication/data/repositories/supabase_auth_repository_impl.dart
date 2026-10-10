import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthResponse;

import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../models/login_request_model.dart';
import '../models/register_request_model.dart';
import '../models/auth_response_model.dart';
import '../models/auth_user_model.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/user_collection_helper.dart';
import '../../../../core/supabase/supabase_helpers.dart' as sb;
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class SupabaseAuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;
  final SharedPreferences sharedPreferences;

  static const String _userDataKey = 'user_data';
  static const String _isAuthenticatedKey = 'is_authenticated';

  SupabaseAuthRepositoryImpl({
    SupabaseClient? supabase,
    required this.sharedPreferences,
  }) : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<Either<Failure, AuthResponse>> login(LoginRequest request) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: request.email,
        password: request.password,
      );

      final User? user = response.user;
      if (user == null) {
        return const Left(AuthFailure('Login failed: No user returned'));
      }

      // Get user profile data from the role tables
      final userProfile = await _getUserProfile(user.id);
      if (userProfile == null) {
        return const Left(AuthFailure('User profile not found'));
      }

      // Check if account is active
      final userData = await UserCollectionHelper.findUserDoc(user.id);
      if (userData != null) {
        final isActive = userData['isActive'] as bool? ?? true;

        if (!isActive) {
          await _supabase.auth.signOut();

          final role = userProfile.role.toString().split('.').last;
          String message;
          if (role == 'household') {
            message =
                'Your account has been temporarily disabled. Please contact support for assistance.';
          } else if (role == 'junkshop') {
            message =
                'Your junkshop account is currently inactive. Please contact the administrator to reactivate your account.';
          } else {
            message =
                'Your account has been disabled. Please contact support for more information.';
          }

          return Left(AuthFailure(message));
        }
      }

      // Update last login timestamp
      try {
        final docRef = await UserCollectionHelper.findUserDocument(user.id);
        if (docRef != null) {
          await docRef.update({
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
            'sign_in_provider': 'password',
          });
          if (kDebugMode) print('✅ Updated last_login_at for user: ${user.id}');
        } else {
          if (kDebugMode) print('⚠️ User document not found for: ${user.id}');
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to update lastLoginAt: $e');
        // Don't fail login if timestamp update fails
      }

      // Store user data locally
      await _storeUserData(userProfile);

      final authResponse = AuthResponse(
        success: true,
        message: 'Login successful',
        user: userProfile,
        accessToken: response.session?.accessToken ?? 'temp_token',
        refreshToken: response.session?.refreshToken,
      );

      await _saveDeviceToken();

      return Right(authResponse);
    } on AuthException catch (e) {
      return Left(AuthFailure(_getAuthErrorMessage(e)));
    } on TypeError catch (_) {
      return Left(const AuthFailure('Something went wrong. Please try again.'));
    } catch (e, stackTrace) {
      if (kDebugMode) print('Login error: $e');
      if (kDebugMode) print('Stack trace: $stackTrace');
      return Left(
        AuthFailure(
          _getFriendlyErrorMessage(e, 'Login failed. Please try again.'),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> register(
    RegisterRequest request,
  ) async {
    try {
      final role = request.role.toString().split('.').last;

      // Create the auth user (email confirmation is OFF: a session exists)
      final response = await _supabase.auth.signUp(
        email: request.email,
        password: request.password,
        data: {
          'full_name': request.fullName ?? '',
          'role': role,
        },
      );

      final User? user = response.user;
      if (user == null) {
        return const Left(AuthFailure('Registration failed: No user created'));
      }

      final AuthUserModel userProfile = AuthUserModel(
        id: user.id,
        email: request.email,
        fullName: request.fullName ?? '',
        role: request.role,
        profileImageUrl: null,
        isEmailVerified: user.emailConfirmedAt != null,
        isProfileComplete:
            false, // Will be updated based on role-specific completion
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        signInProvider: 'password',
      );

      // Save user profile row
      try {
        final userData = userProfile.toJson();
        userData['isActive'] = true;
        await _insertUserRow(user.id, role, userData);
      } on PostgrestException catch (pe) {
        if (pe.code == '42501') {
          return const Left(
            AuthFailure(
              'Registration failed due to a permissions error. Please try again or contact support.',
            ),
          );
        }
        return const Left(
          AuthFailure('Unable to create your profile. Please try again.'),
        );
      }

      await _storeUserData(userProfile);

      final authResponse = AuthResponse(
        success: true,
        message: 'Registration successful',
        user: userProfile,
        accessToken: response.session?.accessToken,
        refreshToken: response.session?.refreshToken,
      );

      return Right(authResponse);
    } on AuthException catch (e) {
      return Left(AuthFailure(_getAuthErrorMessage(e)));
    } on TypeError catch (_) {
      return Left(const AuthFailure('Something went wrong. Please try again.'));
    } catch (e, stackTrace) {
      if (kDebugMode) print('Registration error: $e');
      if (kDebugMode) print('Stack trace: $stackTrace');
      return Left(
        AuthFailure(
          _getFriendlyErrorMessage(e, 'Registration failed. Please try again.'),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> signInWithGoogle({String? role}) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // If role is provided (registration), sign out first to force account picker
      if (role != null) {
        await googleSignIn.signOut();
      }

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return const Left(AuthFailure('Google sign-in cancelled by user'));
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final idToken = googleAuth.idToken;
      if (idToken == null) {
        return const Left(
          AuthFailure('Google sign-in failed: No ID token returned'),
        );
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      final User? user = response.user;

      if (user == null) {
        return const Left(
          AuthFailure('Google sign-in failed: No user returned'),
        );
      }

      AuthUserModel userProfile;
      bool isNewUser = false;

      final existingProfile = await _getUserProfile(user.id);

      if (existingProfile == null) {
        isNewUser = true;

        // Use provided role or default to household
        UserRole userRole = UserRole.household;
        if (role == 'collector') {
          userRole = UserRole.collector;
        } else if (role == 'junkshop') {
          userRole = UserRole.junkshop;
        }

        final meta = user.userMetadata ?? const <String, dynamic>{};
        userProfile = AuthUserModel(
          id: user.id,
          email: user.email ?? '',
          fullName:
              (meta['full_name'] ?? meta['name'] ?? googleUser.displayName ?? '')
                  .toString(),
          role: userRole,
          profileImageUrl:
              (meta['avatar_url'] ?? meta['picture'] ?? googleUser.photoUrl)
                  as String?,
          isEmailVerified: user.emailConfirmedAt != null,
          isProfileComplete: false,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          signInProvider: 'google.com',
        );

        final userData = userProfile.toJson();
        userData['isActive'] = true;

        await _insertUserRow(
          user.id,
          userProfile.role.toString().split('.').last,
          userData,
        );
      } else {
        // Account already exists
        if (role != null) {
          // Registration attempt with an existing account
          await googleSignIn.signOut();
          await _supabase.auth.signOut();

          return const Left(
            AuthFailure(
              'This Google account is already registered. Please sign in instead or use a different Google account.',
            ),
          );
        }

        userProfile = existingProfile;

        try {
          final docRef = await UserCollectionHelper.findUserDocument(user.id);
          if (docRef != null) {
            await docRef.update({
              'last_login_at': DateTime.now().toUtc().toIso8601String(),
              'sign_in_provider': 'google.com',
            });
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Failed to update lastLoginAt: $e');
        }
      }

      await _storeUserData(userProfile);

      final authResponse = AuthResponse(
        success: true,
        message: isNewUser
            ? 'Account created successfully'
            : 'Login successful',
        user: userProfile,
        accessToken: response.session?.accessToken ?? 'temp_token',
        refreshToken: response.session?.refreshToken,
      );

      await _saveDeviceToken();

      return Right(authResponse);
    } on AuthException catch (e) {
      return Left(AuthFailure(_getAuthErrorMessage(e)));
    } catch (e, stackTrace) {
      if (kDebugMode) print('Google sign-in error: $e');
      if (kDebugMode) print('Stack trace: $stackTrace');
      return Left(
        AuthFailure(
          _getFriendlyErrorMessage(
            e,
            'Google sign-in failed. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final user = _supabase.auth.currentUser;

      // Push is on hold; this is a safe no-op unless tokens exist.
      if (user != null) {
        try {
          await getIt<NotificationService>().deleteTokenFromFirestore(user.id);
        } catch (e) {
          if (kDebugMode) print('⚠️ Failed to delete device token: $e');
        }
      }

      await _supabase.auth.signOut();
      await _clearUserData();
      return const Right(null);
    } catch (e) {
      return const Left(AuthFailure('Failed to sign out. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, AuthUserEntity>> getCurrentUser() async {
    try {
      final User? user = _supabase.auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure('No user is currently signed in'));
      }

      try {
        final userProfile = await _getUserProfile(user.id);
        if (userProfile == null) {
          return const Left(AuthFailure('User profile not found'));
        }
        return Right(userProfile.toEntity());
      } on PostgrestException catch (pe) {
        if (pe.code == '42501') {
          return const Left(
            AuthFailure('Unable to load your profile. Please sign in again.'),
          );
        }
        return const Left(
          AuthFailure('Unable to load your profile. Please try again.'),
        );
      }
    } catch (e) {
      return const Left(
        AuthFailure('Unable to load your account. Please try again.'),
      );
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> refreshToken(
    String refreshToken,
  ) async {
    try {
      final User? user = _supabase.auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure('No user is currently signed in'));
      }

      // Force session refresh
      final refreshed = await _supabase.auth.refreshSession();

      final userProfile = await _getUserProfile(user.id);
      if (userProfile == null) {
        return const Left(AuthFailure('User profile not found'));
      }

      final authResponse = AuthResponse(
        success: true,
        message: 'Token refreshed successfully',
        user: userProfile,
        accessToken: refreshed.session?.accessToken,
        refreshToken: refreshed.session?.refreshToken,
      );

      return Right(authResponse);
    } catch (e) {
      return const Left(AuthFailure('Session expired. Please sign in again.'));
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    return _supabase.auth.currentUser != null;
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return _supabase.auth.currentSession?.accessToken;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearAuthData() async {
    await _clearUserData();
  }

  // Private helper methods

  Future<void> _insertUserRow(
    String uid,
    String role,
    Map<String, dynamic> userData,
  ) async {
    final table = UserCollectionHelper.tableForRole(role);
    final row = sb.docToRow(table, userData, forUpdate: false);
    row['id'] = uid;
    await _supabase.from(table).upsert(row);
  }

  Future<void> _saveDeviceToken() async {
    // Push is on hold: getToken() returns null so this is a no-op.
    try {
      final notificationService = getIt<NotificationService>();
      final token = await notificationService.getToken();
      if (token != null) {
        await notificationService.saveDeviceToken(token);
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save device token: $e');
    }
  }

  Future<AuthUserModel?> _getUserProfile(String uid) async {
    try {
      final userData = await UserCollectionHelper.getUserData(uid);
      if (userData == null) return null;

      return AuthUserModel.fromJson(userData);
    } catch (e) {
      return null;
    }
  }

  // Public helper to update user profile fields
  Future<Either<Failure, void>> updateUserProfile(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      final docRef = await UserCollectionHelper.findUserDocument(uid);
      if (docRef == null) {
        return const Left(AuthFailure('User document not found'));
      }
      await docRef.set(updates, merge: true);
      return const Right(null);
    } on PostgrestException catch (pe) {
      if (pe.code == '42501') {
        return const Left(
          AuthFailure('Unable to update profile. Please try again.'),
        );
      }
      return const Left(
        AuthFailure('Unable to update profile. Please check your connection.'),
      );
    } catch (e) {
      return const Left(
        AuthFailure('Unable to update profile. Please try again.'),
      );
    }
  }

  Future<void> _storeUserData(AuthUserModel userData) async {
    await Future.wait([
      sharedPreferences.setString(_userDataKey, json.encode(userData.toJson())),
      sharedPreferences.setBool(_isAuthenticatedKey, true),
    ]);
  }

  Future<void> _clearUserData() async {
    await Future.wait([
      sharedPreferences.remove(_userDataKey),
      sharedPreferences.setBool(_isAuthenticatedKey, false),
    ]);
  }

  String _getAuthErrorMessage(AuthException e) {
    final code = (e is AuthApiException ? e.code : null) ?? '';
    final msg = e.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Email or password is incorrect. Please try again.';
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('already registered') ||
        msg.contains('already been registered') ||
        msg.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (code == 'weak_password' || msg.contains('password should be at least')) {
      return 'Your password is too weak. Please use at least 6 characters.';
    }
    if (code == 'validation_failed' ||
        code == 'email_address_invalid' ||
        msg.contains('invalid email') ||
        msg.contains('unable to validate email')) {
      return 'Please enter a valid email address.';
    }
    if (code == 'user_banned' || msg.contains('banned')) {
      return 'This account has been disabled. Please contact support.';
    }
    if (code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        msg.contains('rate limit') ||
        msg.contains('too many')) {
      return 'Too many failed attempts. Please wait a moment and try again.';
    }
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (code == 'provider_disabled' || code == 'signup_disabled') {
      return 'This sign-in method is not enabled. Please contact support.';
    }
    if (code == 'reauthentication_needed' || msg.contains('reauthentication')) {
      return 'For security, please sign out and sign in again before making this change.';
    }
    if (code == 'identity_already_exists') {
      return 'An account already exists with the same email using a different sign-in method.';
    }
    return 'Authentication failed. Please try again.';
  }

  String _getFriendlyErrorMessage(dynamic e, String fallback) {
    final str = e.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('network is unreachable') ||
        str.contains('host lookup') ||
        str.contains('no internet') ||
        str.contains('connection refused') ||
        str.contains('failed host lookup')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (str.contains('timeout') || str.contains('timed out')) {
      return 'Connection timed out. Please try again.';
    }
    return fallback;
  }
}
