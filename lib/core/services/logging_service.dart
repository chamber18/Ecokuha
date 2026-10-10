import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  Future<void> logActivity({
    required String type,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    try {
      final uid = currentUid;
      if (uid == null) return;

      await supabase.from('junkshop_logs').insert({
        'junkshop_id': uid,
        'type': type.toLowerCase(),
        'message': message,
        'user_id': uid,
        if (details != null) 'details': details,
      });
    } catch (e) {
      if (kDebugMode) print('Error logging activity: $e');
    }
  }

  // Convenience methods for common log types
  Future<void> logPurchase({
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await logActivity(type: 'purchase', message: message, details: details);
  }

  Future<void> logSale({
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await logActivity(type: 'sale', message: message, details: details);
  }

  Future<void> logPosting({
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await logActivity(type: 'posting', message: message, details: details);
  }

  Future<void> logCollector({
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await logActivity(type: 'collector', message: message, details: details);
  }

  Future<void> logSystem({
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await logActivity(type: 'system', message: message, details: details);
  }

  Future<void> logError({
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await logActivity(type: 'error', message: message, details: details);
  }
}
