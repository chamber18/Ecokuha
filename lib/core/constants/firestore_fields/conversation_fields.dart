/// Firestore field names for conversation documents.
/// Collection path: conversations/{conversationId}
class ConversationFields {
  // ========== CORE METADATA ==========

  /// Conversation document ID (String)
  static const id = 'id';

  /// Creation timestamp (Timestamp)
  static const createdAt = 'createdAt';

  /// Last update timestamp (Timestamp)
  static const updatedAt = 'updatedAt';

  // ========== PARTICIPANTS ==========

  /// Typically: [householdId, junkshopId, ?collectorId]
  static const participants = 'participants';

  /// Structure: { userId: { name, role, profileImage, joinedAt } }
  static const participantDetails = 'participantDetails';

  /// Structure: { userId: 'household' | 'junkshop' | 'collector' }
  static const participantRoles = 'participantRoles';

  /// Household participant ID (String)
  static const householdId = 'householdId';

  /// Junkshop participant ID (String)
  static const junkshopId = 'junkshopId';

  /// Collector participant ID (String) - optional
  static const collectorId = 'collectorId';

  // ========== LAST MESSAGE TRACKING ==========

  /// Text of last message (String)
  static const lastMessage = 'lastMessage';

  /// Last message timestamp (Timestamp)
  static const lastMessageTime = 'lastMessageTime';

  /// Alternative: Last message timestamp (Timestamp)
  static const lastMessageTimestamp = 'lastMessageTimestamp';

  /// ID of user who sent last message (String)
  static const lastMessageSenderId = 'lastMessageSenderId';

  /// Name of user who sent last message (String)
  static const lastMessageSenderName = 'lastMessageSenderName';

  /// Type of last message: 'text' | 'image' | 'system' (String)
  static const lastMessageType = 'lastMessageType';

  // ========== POSTING RELATIONSHIP ==========

  /// ID of linked posting (String)
  static const postingId = 'postingId';

  /// Synced posting status (String)
  /// Mirrors the posting's status for quick access
  static const postingStatus = 'postingStatus';

  // ========== UNREAD TRACKING ==========

  /// Structure: { userId: unreadCount }
  static const unreadCounts = 'unreadCounts';

  /// Total messages in conversation (int)
  static const messageCount = 'messageCount';

  // ========== CONVERSATION STATE ==========

  /// Whether conversation is active (bool)
  static const isActive = 'isActive';

  /// Whether conversation is archived (bool)
  static const isArchived = 'isArchived';

  /// Structure: { userId: isMuted }
  static const mutedBy = 'mutedBy';

  // ========== PARTICIPANT DETAIL SUB-FIELDS ==========

  /// Participant name (String) - used in participantDetails map
  static const participantName = 'name';

  /// Participant role (String) - used in participantDetails map
  static const participantRole = 'role';

  /// Participant profile image URL (String) - used in participantDetails map
  static const participantProfileImage = 'profileImage';

  /// Participant joined timestamp (Timestamp) - used in participantDetails map
  static const participantJoinedAt = 'joinedAt';
}

/// Firestore field names for message sub-documents.
/// Collection path: conversations/{conversationId}/messages/{messageId}
class MessageFields {
  // ========== CORE METADATA ==========

  /// Message document ID (String)
  static const id = 'id';

  /// Message text content (String)
  static const text = 'text';

  /// Sender user ID (String)
  static const senderId = 'senderId';

  /// Sender display name (String)
  static const senderName = 'senderName';

  /// Sender role: 'household' | 'junkshop' | 'collector' (String)
  static const senderRole = 'senderRole';

  /// Message timestamp (Timestamp)
  static const timestamp = 'timestamp';

  /// Creation timestamp (Timestamp) - alternative
  static const createdAt = 'createdAt';

  // ========== MESSAGE TYPE & CONTENT ==========

  /// Message type: 'text' | 'image' | 'system' | 'status_update' (String)
  static const type = 'type';

  /// Image URL if type is 'image' (String)
  static const imageUrl = 'imageUrl';

  static const imageUrls = 'imageUrls';

  /// System message metadata (Map)
  static const systemData = 'systemData';

  // ========== READ TRACKING ==========

  static const readBy = 'readBy';

  static const readAt = 'readAt';

  /// Whether message has been delivered (bool)
  static const isDelivered = 'isDelivered';

  // ========== METADATA ==========

  /// Whether this is a system-generated message (bool)
  static const isSystemMessage = 'isSystemMessage';

  /// Related posting ID for status updates (String)
  static const postingId = 'postingId';

  /// Status update type: 'assigned' | 'in_transit' | 'completed' (String)
  static const statusUpdate = 'statusUpdate';
}
