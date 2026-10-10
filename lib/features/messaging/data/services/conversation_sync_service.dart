import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart' as helpers;
import 'package:flutter/foundation.dart' show kDebugMode;

/// Service to keep conversation posting status in sync with actual posting status
class ConversationSyncService {
  final SupabaseClient _db;
  final Map<String, StreamSubscription> _activeSubscriptions = {};

  ConversationSyncService({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;

  /// Start listening to posting status changes and sync with conversation
  /// Call this when a posting-related conversation is created or when app starts
  ///
  /// [userId] is kept for API compatibility (it is only part of the
  /// de-duplication key); postings are looked up by [postingId].
  void syncConversationWithPosting(
    String userId,
    String postingId,
    String conversationId,
  ) {
    // Use a composite key to prevent duplicate listeners for the same posting
    final syncKey = '$userId-$postingId-$conversationId';

    // If already syncing this exact posting, skip
    if (_activeSubscriptions.containsKey(syncKey)) {
      if (kDebugMode) print('⏭️  Already syncing posting $postingId, skipping duplicate');
      return;
    }

    // Cancel any old subscription for this conversation (different posting)
    cancelSync(conversationId);

    if (kDebugMode) print('🔄 Starting posting status sync: $postingId → $conversationId');

    final subscription = _db
        .from('postings')
        .stream(primaryKey: ['id'])
        .eq('id', postingId)
        .listen(
          (rows) async {
            if (rows.isEmpty) {
              if (kDebugMode) print('⚠️ Posting $postingId not found');
              return;
            }

            final postingData = helpers.rowToDoc('postings', rows.first);
            final postingStatus =
                postingData['status'] as String? ?? 'pending';

            try {
              final conversation = await _db
                  .from('conversations')
                  .select('posting_status')
                  .eq('id', conversationId)
                  .maybeSingle();

              if (conversation == null) {
                if (kDebugMode) {
                  print('❌ Conversation $conversationId not found! Cannot update status.');
                }
                return;
              }

              final oldStatus = conversation['posting_status'] as String?;
              if (oldStatus == postingStatus) return;

              // Conditional update: only one client wins the transition.
              final updated = await _db
                  .from('conversations')
                  .update({'posting_status': postingStatus})
                  .eq('id', conversationId)
                  .neq('posting_status', postingStatus)
                  .select('id');
              if (updated.isEmpty) return;

              final statusMessage = oldStatus != null
                  ? _getStatusChangeMessage(oldStatus, postingStatus, postingData)
                  : null;

              if (statusMessage != null) {
                await _db.from('messages').insert({
                  'conversation_id': conversationId,
                  'sender_id': 'ecokuha_assistant',
                  'sender_name': 'EcoKuha Assistant',
                  'sender_role': 'system',
                  'type': 'system',
                  'text': statusMessage,
                  'read_by': <String>[],
                  'metadata': {
                    'action': 'status_change',
                    'oldStatus': oldStatus,
                    'newStatus': postingStatus,
                  },
                });

                await _db
                    .from('conversations')
                    .update({
                      'last_message': statusMessage,
                      'last_message_sender_id': 'ecokuha_assistant',
                      'last_message_sender_name': 'EcoKuha Assistant',
                      'last_message_timestamp': DateTime.now()
                          .toUtc()
                          .toIso8601String(),
                    })
                    .eq('id', conversationId);
              }

              if (postingStatus == 'completed') {
                await _scheduleConversationDeletion(conversationId);
              }
            } catch (e) {
              if (kDebugMode) {
                print('❌ Failed to update conversation status: $e (posting $postingId, conversation $conversationId)');
              }
            }
          },
          onError: (error) {
            if (kDebugMode) print('❌ Error listening to posting status: $error');
          },
        );

    _activeSubscriptions[syncKey] = subscription;
  }

  /// Schedule conversation deletion 48 hours after completion
  Future<void> _scheduleConversationDeletion(String conversationId) async {
    try {
      final now = DateTime.now().toUtc();
      await _db
          .from('conversations')
          .update({
            'scheduled_for_deletion': true,
            'deletion_scheduled_at': now.toIso8601String(),
            'deletion_due_at': now
                .add(const Duration(hours: 48))
                .toIso8601String(),
          })
          .eq('id', conversationId);

      if (kDebugMode) {
        print('🗑️ Conversation $conversationId scheduled for deletion in 48 hours');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to schedule conversation deletion: $e');
    }
  }

  /// Cancel scheduled deletion (when conversation is reposted or rescheduled)
  Future<void> cancelScheduledDeletion(String conversationId) async {
    try {
      await _db
          .from('conversations')
          .update({
            'scheduled_for_deletion': false,
            'deletion_scheduled_at': null,
            'deletion_due_at': null,
            'deletion_reason': null,
          })
          .eq('id', conversationId);

      if (kDebugMode) print('✅ Cancelled scheduled deletion for conversation $conversationId');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to cancel scheduled deletion: $e');
    }
  }

  /// Cancel sync for a specific conversation
  void cancelSync(String conversationId) {
    final keysToRemove = <String>[];

    for (final key in _activeSubscriptions.keys) {
      if (key == conversationId || key.endsWith('-$conversationId')) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _activeSubscriptions[key]?.cancel();
      _activeSubscriptions.remove(key);
      if (kDebugMode) print('🛑 Stopped posting status sync: $key');
    }
  }

  /// Cancel all active syncs
  void cancelAllSyncs() {
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    if (kDebugMode) print('🛑 Stopped all posting status syncs');
  }

  /// Check and delete conversations that are past their deletion date
  Future<void> cleanupExpiredConversations() async {
    try {
      final expired = await _db
          .from('conversations')
          .select('id')
          .eq('scheduled_for_deletion', true)
          .lt('deletion_due_at', DateTime.now().toUtc().toIso8601String());

      if (kDebugMode) {
        print('🗑️ Found ${expired.length} expired conversations to delete');
      }

      for (final row in expired) {
        final conversationId = row['id'] as String;
        // Messages are removed by ON DELETE CASCADE
        await _db.from('conversations').delete().eq('id', conversationId);
        if (kDebugMode) print('✅ Deleted expired conversation: $conversationId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to cleanup expired conversations: $e');
    }
  }

  /// Sync all active posting-related conversations
  /// Call this on app startup to ensure all conversations are in sync
  Future<void> syncAllActiveConversations() async {
    try {
      final conversations = await _db
          .from('conversations')
          .select()
          .eq('is_active', true)
          .inFilter('posting_status', [
            'pending',
            'assigned',
            'in_transit',
            'arrived',
            'collecting',
          ]);

      if (kDebugMode) print('🔄 Syncing ${conversations.length} active conversations');

      for (final data in conversations) {
        final postingId = data['posting_id'] as String?;
        final conversationId = data['id'] as String;
        final participants = data['participants'] as List<dynamic>?;

        // Only sync posting-related conversations (not direct_ conversations)
        if (postingId != null &&
            postingId.isNotEmpty &&
            conversationId.startsWith('posting_') &&
            participants != null &&
            participants.isNotEmpty) {
          String? householdUserId;

          final participantDetails = data['participant_details'] as Map?;
          if (participantDetails != null) {
            for (final entry in participantDetails.entries) {
              final details = entry.value;
              if (details is Map && details['role'] == 'household') {
                householdUserId = entry.key.toString();
                break;
              }
            }
          }

          householdUserId ??= participants.first.toString();

          syncConversationWithPosting(
            householdUserId,
            postingId,
            conversationId,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to sync active conversations: $e');
    }
  }

  /// Get a stream of conversations that are scheduled for deletion
  /// This can be used to show warnings to users
  Stream<List<String>> getConversationsScheduledForDeletion(String userId) {
    return _db
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('scheduled_for_deletion', true)
        .map(
          (rows) => rows
              .where(
                (r) => (r['participants'] as List? ?? []).contains(userId),
              )
              .map((r) => r['id'] as String)
              .toList(),
        );
  }

  /// Get a human-readable status change message
  String? _getStatusChangeMessage(
    String oldStatus,
    String newStatus,
    Map<String, dynamic> postingData,
  ) {
    // Handle declined status with reason from nested structure
    if (newStatus == 'declined') {
      final postAttempt = ((postingData['postAttempt'] ?? postingData['post_attempt'] ?? 0) as num).toInt();
      String declineCount = '1st';
      String attemptSuffix = '';

      if (postAttempt == 1) {
        declineCount = '1st';
        attemptSuffix = '';
      } else if (postAttempt == 2) {
        declineCount = '2nd';
        attemptSuffix = ' (2nd attempt)';
      } else if (postAttempt == 3) {
        declineCount = '3rd';
        attemptSuffix = ' (3rd attempt)';
      } else if (postAttempt > 3) {
        declineCount = '${postAttempt}th';
        attemptSuffix = ' (${postAttempt}th attempt)';
      }

      final declines = (postingData['declines'] as Map?)
          ?.cast<String, dynamic>();
      final latestDecline = (declines?[declineCount] as Map?)
          ?.cast<String, dynamic>();
      final declineReason =
          latestDecline?['declineReason']?.toString() ??
          postingData['declineReason']?.toString() ??
          'No reason provided';

      return '❌ Collection request has been declined$attemptSuffix.\nReason: $declineReason\n\n⚠️ This conversation will be automatically deleted in 48 hours if no action is taken (repost or reschedule).';
    }

    // Handle cancelled status with reason(s)
    // Note: Collector cancellations already send their own message from task_details_screen
    // Only generate message for junkshop-initiated cancellations
    if (newStatus == 'cancelled') {
      // Check who cancelled - skip message if collector cancelled (they send their own)
      final cancellationData = postingData['cancellation'];
      if (cancellationData is Map) {
        final cancelledByRole = cancellationData['cancelledByRole'];
        if (cancelledByRole == 'collector') {
          return null; // Collector already sent their own cancellation message
        }
      }

      String reason = 'No reason provided';

      // Check for selectedReasons array first
      final selectedReasons = postingData['selectedReasons'];
      if (selectedReasons is List && selectedReasons.isNotEmpty) {
        reason = selectedReasons.join(', ');
      } else if (postingData['cancellationReason'] != null) {
        reason = postingData['cancellationReason'].toString();
      }

      return '❌ Collection has been cancelled by junkshop.\nReason: $reason';
    }

    // Skip message generation for collector cancellations - already handled
    if (newStatus == 'cancelled_by_collector') {
      return null;
    }

    // Map of status transitions to messages
    final Map<String, Map<String, String>> statusMessages = {
      'assigned': {'in_transit': '🚚 Collector is on the way'},
      'in_transit': {
        'arrived': '📍 Collector has arrived at your location',
        'assigned': '🔄 Collector is returning to base',
        'completed':
            '✅ Collection completed successfully. This conversation will remain open for 48 hours.',
      },
      'arrived': {
        'collecting': '📦 Collection in progress',
        'in_transit': '🚚 Collector is heading back',
      },
      'collecting': {
        'completed':
            '✅ Collection completed successfully. This conversation will remain open for 48 hours.',
        'in_transit': '🚚 Collector is heading back',
      },
    };

    return statusMessages[oldStatus]?[newStatus];
  }
}
