import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_notification_service.dart';

/// Notification service.
///
/// Remote push is ON HOLD (no FCM). This class keeps its public API as
/// safe no-ops so callers keep working; local notifications are still shown
/// through [LocalNotificationService]. If a push token is ever provided it can
/// be persisted with [saveDeviceToken] (`device_tokens`, upsert on `token`).
class NotificationService {
  // ignore: unused_field
  final LocalNotificationService _localNotificationService;
  final SupabaseClient _supabase;

  NotificationService({
    SupabaseClient? supabase,
    required LocalNotificationService localNotificationService,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _localNotificationService = localNotificationService;

  /// Initialize notifications. Push is on hold: only local notifications are
  /// initialised and this never throws.
  Future<void> initialize() async {
    try {
      await _localNotificationService.initialize();
    } catch (e) {
      log('Error initializing notifications: $e');
    }
  }

  /// Persist a device push token for the signed-in user (upsert on `token`).
  Future<void> saveDeviceToken(String token, {String? platform}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      log('Cannot save token: no signed-in user');
      return;
    }
    try {
      await _supabase.from('device_tokens').upsert({
        'user_id': uid,
        'token': token,
        if (platform != null) 'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
    } catch (e) {
      log('Error saving device token: $e');
    }
  }

  /// Kept for API compatibility (formerly saved the FCM token).
  Future<void> saveTokenToFirestore(
    String token, {
    String? userId,
    String? role,
  }) => saveDeviceToken(token);

  /// Delete the signed-in user's device tokens (e.g., on logout).
  Future<void> deleteTokenFromFirestore(String userId, {String? role}) async {
    try {
      await _supabase.from('device_tokens').delete().eq('user_id', userId);
    } catch (e) {
      log('Error deleting device tokens: $e');
    }
  }

  /// Push is on hold: there is no token.
  Future<String?> getToken() async => null;
}
