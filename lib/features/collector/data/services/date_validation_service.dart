import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart' as helpers;
import 'package:flutter/foundation.dart' show kDebugMode;

/// Service to handle date validation and automatic status resets.
///
/// The nightly DB cron (`check_overdue_collections`) performs the same reset
/// server-side; this client service is kept for on-demand checks.
class DateValidationService {
  final SupabaseClient _db;

  DateValidationService({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;

  /// Check if a posting's collection date has passed and reset status if needed
  /// Returns true if the posting was reset, false otherwise
  Future<bool> checkAndResetIfDatePassed({
    required String householdId,
    required String postingId,
    required String collectorId,
    String? collectorName,
  }) async {
    try {
      final row = await _db
          .from('postings')
          .select()
          .eq('id', postingId)
          .maybeSingle();
      if (row == null) return false;

      final data = helpers.rowToDoc('postings', row);

      // Check status - only reset if still assigned
      final status = data['status'] as String?;
      if (status != 'assigned') return false;

      // Check if dateOfCollection exists and has passed
      final dateOfCollection = helpers.toDateTime(data['dateOfCollection']);
      if (dateOfCollection == null) return false;

      // Compare dates (ignore time)
      final now = DateTime.now();
      final local = dateOfCollection.toLocal();
      final collectionDate = DateTime(local.year, local.month, local.day);
      final today = DateTime(now.year, now.month, now.day);

      // If collection date has not passed yet, no action needed
      if (collectionDate.isAtSameMomentAs(today) ||
          collectionDate.isAfter(today)) {
        return false;
      }

      // Collection date has passed - mark for reassignment
      await _resetPostingToPending(
        postingId: postingId,
        postingData: data,
        collectorId: collectorId,
        collectorName: collectorName,
        dateOfCollection: local,
      );

      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error checking/resetting posting date: $e');
      return false;
    }
  }

  /// Reset posting to reschedule and add failure reason
  Future<void> _resetPostingToPending({
    required String postingId,
    required Map<String, dynamic> postingData,
    required String collectorId,
    String? collectorName,
    required DateTime dateOfCollection,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Format the date for the reason message
    final dateStr =
        '${dateOfCollection.month}/${dateOfCollection.day}/${dateOfCollection.year}';

    // Create failure reason
    final failureReason =
        'Collection date ($dateStr) has passed. Posting returned for reassignment.';

    // Store previous collector info before resetting
    final previousCollectorInfo = {
      'id': collectorId,
      'name': collectorName ?? 'Unknown',
      'failedDate': dateOfCollection.toUtc().toIso8601String(),
      'resetAt': nowIso,
      'reason': failureReason,
    };

    // Update posting status to reschedule for reassignment
    await _db
        .from('postings')
        .update({
          'status': 'reschedule',
          'previous_collector': previousCollectorInfo,
          'collector_failure_reason': failureReason,
          'collector_failed_at': nowIso,
        })
        .eq('id', postingId);

    // Send system message to conversation
    final conversationId = postingData['conversationId'] as String?;
    if (conversationId != null) {
      await _db.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': 'ecokuha_assistant',
        'sender_name': 'EcoKuha Assistant',
        'sender_role': 'system',
        'type': 'system',
        'text': failureReason,
        'read_by': <String>[],
        'metadata': {
          'action': 'collector_failed',
          'postingId': postingId,
          'statusUpdate': 'reassigned',
          'systemData': {
            'type': 'collector_failed',
            'previousCollectorId': collectorId,
            'previousCollectorName': collectorName,
            'scheduledDate': dateOfCollection.toUtc().toIso8601String(),
            'reason': failureReason,
          },
        },
      });

      // Update conversation's last message
      await _db
          .from('conversations')
          .update({
            'last_message': failureReason,
            'last_message_timestamp': nowIso,
            'last_message_type': 'system',
            'last_message_sender_id': 'ecokuha_assistant',
            'posting_status': 'reschedule',
          })
          .eq('id', conversationId);
    }
  }

  /// Remove previous collector info when new collector is assigned
  Future<void> removePreviousCollectorOnNewAssignment({
    required String householdId,
    required String postingId,
  }) async {
    try {
      await _db
          .from('postings')
          .update({
            'previous_collector': null,
            'collector_failure_reason': null,
            'collector_failed_at': null,
          })
          .eq('id', postingId);
      if (kDebugMode) {
        print('✅ Removed previous collector info after new assignment');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error removing previous collector info: $e');
    }
  }
}