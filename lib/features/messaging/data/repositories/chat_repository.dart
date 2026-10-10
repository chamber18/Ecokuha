import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart' as helpers;
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// Repository for handling all messaging-related Supabase operations
class ChatRepository {
  final SupabaseClient _db;

  ChatRepository({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;

  static const _conversations = 'conversations';
  static const _messages = 'messages';

  // ========== INTERNAL HELPERS ==========

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  List<ConversationModel> _toConversations(
    List<Map<String, dynamic>> rows,
    String userId, {
    bool activeOnly = false,
  }) {
    final list = rows
        .map((r) => ConversationModel.fromMap(r))
        .where((c) => c.participants.contains(userId))
        .where((c) => !c.deletedBy.contains(userId))
        .where((c) => !activeOnly || c.isActive)
        .toList();
    list.sort((a, b) {
      final at = a.lastMessageTimestamp;
      final bt = b.lastMessageTimestamp;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return list;
  }

  Future<Map<String, dynamic>?> _getConversationRow(
    String conversationId,
  ) async {
    return await _db
        .from(_conversations)
        .select()
        .eq('id', conversationId)
        .maybeSingle();
  }

  /// Inserts a message built by [MessageFactory] and returns its id.
  Future<String> _insertMessage(
    String conversationId,
    Map<String, dynamic> messageData,
  ) async {
    final row = helpers.docToRow('messages', messageData, forUpdate: false);
    row['conversation_id'] = conversationId;
    final inserted = await _db.from(_messages).insert(row).select('id').single();
    return inserted['id'].toString();
  }

  // ========== CONVERSATION OPERATIONS ==========

  /// Get all conversations for a user (real-time stream)
  Stream<List<ConversationModel>> getConversationsStream(String userId) {
    return _db
        .from(_conversations)
        .stream(primaryKey: ['id'])
        .map((rows) => _toConversations(rows, userId));
  }

  /// Get active conversations only (real-time stream)
  Stream<List<ConversationModel>> getActiveConversationsStream(String userId) {
    return _db
        .from(_conversations)
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .map((rows) => _toConversations(rows, userId, activeOnly: true));
  }

  /// Get a single conversation by ID (real-time stream)
  Stream<ConversationModel?> getConversationStream(String conversationId) {
    return _db
        .from(_conversations)
        .stream(primaryKey: ['id'])
        .eq('id', conversationId)
        .map(
          (rows) => rows.isEmpty ? null : ConversationModel.fromMap(rows.first),
        );
  }

  /// Get conversation by posting ID
  Future<ConversationModel?> getConversationByPostingId(
    String postingId,
  ) async {
    final conversationId = 'posting_$postingId';
    final row = await _getConversationRow(conversationId);
    return row == null ? null : ConversationModel.fromMap(row);
  }

  /// Create a new conversation
  Future<String> createConversation({
    required String postingId,
    required List<String> participants,
    required Map<String, ParticipantDetails> participantDetails,
    String? initialMessage,
  }) async {
    // Use the postingId as-is (it's either 'posting_xxx' or 'direct_xxx')
    // Don't add 'posting_' prefix if it's already a direct conversation
    final conversationId = postingId.startsWith('direct_')
        ? postingId
        : 'posting_$postingId';

    final unreadCounts = <String, int>{
      for (final userId in participants) userId: 0,
    };

    await _db.from(_conversations).upsert({
      'id': conversationId,
      'posting_id': postingId,
      'participants': participants,
      'participant_details': participantDetails.map(
        (userId, details) => MapEntry(userId, details.toMap()),
      ),
      'last_message': initialMessage ?? 'Conversation started',
      'last_message_sender_id': 'ecokuha_assistant',
      'last_message_sender_name': 'EcoKuha Assistant',
      'last_message_timestamp': _nowIso(),
      'unread_counts': unreadCounts,
      'is_active': true,
      'posting_status': 'pending',
    });

    // Create initial system message if provided
    if (initialMessage != null) {
      await _insertMessage(
        conversationId,
        MessageFactory.createSystemMessage(
          text: initialMessage,
          action: 'conversation_created',
          additionalMetadata: {'postingId': postingId},
        ),
      );
    }

    return conversationId;
  }

  /// Add a participant to an existing conversation (e.g., when collector is assigned)
  Future<void> addParticipant({
    required String conversationId,
    required String userId,
    required ParticipantDetails participantDetails,
    String? systemMessage,
  }) async {
    final row = await _getConversationRow(conversationId);
    if (row == null) {
      throw Exception('Conversation not found');
    }

    final participants = List<String>.from(
      (row['participants'] as List? ?? []).map((e) => e.toString()),
    );
    if (!participants.contains(userId)) participants.add(userId);

    final details = Map<String, dynamic>.from(
      row['participant_details'] as Map? ?? {},
    );
    details[userId] = participantDetails.toMap();

    final unread = Map<String, dynamic>.from(row['unread_counts'] as Map? ?? {});
    unread[userId] = 1; // New participant has 1 unread (the system message)

    final updates = <String, dynamic>{
      'participants': participants,
      'participant_details': details,
      'unread_counts': unread,
    };

    if (systemMessage != null) {
      updates['last_message'] = systemMessage;
      updates['last_message_sender_id'] = 'ecokuha_assistant';
      updates['last_message_sender_name'] = 'EcoKuha Assistant';
      updates['last_message_timestamp'] = _nowIso();
    }

    await _db.from(_conversations).update(updates).eq('id', conversationId);

    if (systemMessage != null) {
      await _insertMessage(
        conversationId,
        MessageFactory.createSystemMessage(
          text: systemMessage,
          action: 'participant_added',
          additionalMetadata: {
            'userId': userId,
            'userName': participantDetails.name,
            'role': participantDetails.role,
          },
        ),
      );
    }
  }

  /// Remove a participant from an existing conversation (e.g., when collector is reassigned)
  Future<void> removeParticipant({
    required String conversationId,
    required String userId,
    String? systemMessage,
  }) async {
    final row = await _getConversationRow(conversationId);
    if (row == null) {
      throw Exception('Conversation not found');
    }

    final participants = List<String>.from(
      (row['participants'] as List? ?? []).map((e) => e.toString()),
    )..remove(userId);
    final details = Map<String, dynamic>.from(
      row['participant_details'] as Map? ?? {},
    )..remove(userId);
    final unread = Map<String, dynamic>.from(row['unread_counts'] as Map? ?? {})
      ..remove(userId);

    final updates = <String, dynamic>{
      'participants': participants,
      'participant_details': details,
      'unread_counts': unread,
    };

    if (systemMessage != null) {
      updates['last_message'] = systemMessage;
      updates['last_message_sender_id'] = 'ecokuha_assistant';
      updates['last_message_sender_name'] = 'EcoKuha Assistant';
      updates['last_message_timestamp'] = _nowIso();
    }

    await _db.from(_conversations).update(updates).eq('id', conversationId);

    if (systemMessage != null) {
      await _insertMessage(
        conversationId,
        MessageFactory.createSystemMessage(
          text: systemMessage,
          action: 'participant_removed',
          additionalMetadata: {'userId': userId},
        ),
      );
    }
  }

  /// Update conversation status (when posting status changes)
  Future<void> updateConversationStatus({
    required String conversationId,
    required String postingStatus,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{'posting_status': postingStatus};
    if (isActive != null) {
      updates['is_active'] = isActive;
    }
    await _db.from(_conversations).update(updates).eq('id', conversationId);
  }

  /// Updates the group name for a group conversation (junkshop only)
  Future<void> updateGroupName({
    required String conversationId,
    required String newName,
  }) async {
    await _db
        .from(_conversations)
        .update({'group_name': newName})
        .eq('id', conversationId);
  }

  // ========== MESSAGE OPERATIONS ==========

  /// Get messages in a conversation (real-time stream)
  Stream<List<MessageModel>> getMessagesStream(String conversationId) {
    return _db
        .from(_messages)
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((r) => MessageModel.fromMap(r)).toList());
  }

  /// Get paginated messages (for initial load). Pass [before] (the timestamp
  /// of the oldest loaded message) to fetch the previous page.
  Future<List<MessageModel>> getMessages({
    required String conversationId,
    int limit = 50,
    DateTime? before,
  }) async {
    var query = _db.from(_messages).select().eq('conversation_id', conversationId);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows
        .map((r) => MessageModel.fromMap(Map<String, dynamic>.from(r)))
        .toList()
        .reversed
        .toList(); // Reverse to show oldest first
  }

  /// Updates last-message fields and bumps unread counters for other participants.
  Future<void> _afterUserMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String lastMessage,
    String? postingStatus,
  }) async {
    await _db
        .from(_conversations)
        .update({
          'last_message': lastMessage,
          'last_message_sender_id': senderId,
          'last_message_sender_name': senderName,
          'last_message_timestamp': _nowIso(),
          if (postingStatus != null) 'posting_status': postingStatus,
        })
        .eq('id', conversationId);

    await _db.rpc(
      'increment_unread_counts',
      params: {'p_conversation_id': conversationId, 'p_sender_id': senderId},
    );
  }

  /// Send a text message
  Future<String> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
  }) async {
    final id = await _insertMessage(
      conversationId,
      MessageFactory.createTextMessage(
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        text: text,
      ),
    );

    await _afterUserMessage(
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      lastMessage: text,
    );
    return id;
  }

  /// Send an image message
  Future<String> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
    required String imageUrl,
    String? thumbnailUrl,
  }) async {
    final id = await _insertMessage(
      conversationId,
      MessageFactory.createImageMessage(
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        text: text,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
      ),
    );

    await _afterUserMessage(
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      lastMessage: '📷 Photo',
    );
    return id;
  }

  /// Send a status update message
  Future<String> sendStatusUpdateMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String oldStatus,
    required String newStatus,
  }) async {
    final messageData = MessageFactory.createStatusUpdateMessage(
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      oldStatus: oldStatus,
      newStatus: newStatus,
    );
    final id = await _insertMessage(conversationId, messageData);

    await _afterUserMessage(
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      lastMessage: messageData['text'] as String,
      postingStatus: newStatus,
    );
    return id;
  }

  /// Send a system message
  Future<String> sendSystemMessage({
    required String conversationId,
    required String text,
    required String action,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final id = await _insertMessage(
      conversationId,
      MessageFactory.createSystemMessage(
        text: text,
        action: action,
        additionalMetadata: additionalMetadata,
      ),
    );

    await _db
        .from(_conversations)
        .update({
          'last_message': text,
          'last_message_sender_id': 'ecokuha_assistant',
          'last_message_sender_name': 'EcoKuha Assistant',
          'last_message_timestamp': _nowIso(),
        })
        .eq('id', conversationId);

    return id;
  }

  // ========== READ RECEIPT OPERATIONS ==========

  /// Mark all messages in a conversation as read by the current user
  /// (the RPC uses `auth.uid()`; [userId] is kept for API compatibility).
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    await _db.rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
  }

  /// Mark a specific message as read
  Future<void> markMessageAsRead({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    final row = await _db
        .from(_messages)
        .select('read_by')
        .eq('id', messageId)
        .maybeSingle();
    if (row == null) return;
    final readBy = List<String>.from(
      (row['read_by'] as List? ?? []).map((e) => e.toString()),
    );
    if (readBy.contains(userId)) return;
    readBy.add(userId);
    await _db.from(_messages).update({'read_by': readBy}).eq('id', messageId);
  }

  // ========== UTILITY OPERATIONS ==========

  int _sumUnread(List<ConversationModel> conversations, String userId) {
    var total = 0;
    for (final c in conversations) {
      total += c.unreadCounts[userId] ?? 0;
    }
    return total;
  }

  /// Get total unread count for a user across all conversations
  Future<int> getTotalUnreadCount(String userId) async {
    final rows = await _db
        .from(_conversations)
        .select()
        .contains('participants', [userId]);
    return _sumUnread(
      _toConversations(
        rows.map((r) => Map<String, dynamic>.from(r)).toList(),
        userId,
      ),
      userId,
    );
  }

  /// Get total unread count stream
  Stream<int> getTotalUnreadCountStream(String userId) {
    return _db
        .from(_conversations)
        .stream(primaryKey: ['id'])
        .map((rows) => _sumUnread(_toConversations(rows, userId), userId));
  }

  /// Delete a message
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _db.from(_messages).delete().eq('id', messageId);
  }

  /// Archive/deactivate a conversation
  Future<void> archiveConversation(String conversationId) async {
    await _db
        .from(_conversations)
        .update({'is_active': false})
        .eq('id', conversationId);
  }

  /// Delete a conversation and all its messages (messages cascade)
  Future<void> deleteConversation(String conversationId) async {
    await _db.from(_conversations).delete().eq('id', conversationId);
  }

  /// Soft delete a conversation for a specific user (they can't see it but others can)
  Future<void> softDeleteConversation({
    required String conversationId,
    required String userId,
  }) async {
    final row = await _getConversationRow(conversationId);
    if (row == null) return;
    final deletedBy = List<String>.from(
      (row['deleted_by'] as List? ?? []).map((e) => e.toString()),
    );
    if (!deletedBy.contains(userId)) deletedBy.add(userId);
    await _db
        .from(_conversations)
        .update({'deleted_by': deletedBy})
        .eq('id', conversationId);
  }

  /// Restore a previously deleted conversation for a user (remove from deletedBy)
  Future<void> restoreConversationForUser({
    required String conversationId,
    required String userId,
  }) async {
    final row = await _getConversationRow(conversationId);
    if (row == null) return;
    final deletedBy = List<String>.from(
      (row['deleted_by'] as List? ?? []).map((e) => e.toString()),
    )..remove(userId);
    await _db
        .from(_conversations)
        .update({'deleted_by': deletedBy})
        .eq('id', conversationId);
  }
}
