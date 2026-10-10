import 'package:equatable/equatable.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';

/// Model representing a conversation between household, junkshop, and collector
class ConversationModel extends Equatable {
  final String id;
  final String postingId;
  final List<String> participants;
  final Map<String, ParticipantDetails> participantDetails;
  final String lastMessage;
  final String lastMessageSenderId;
  final String lastMessageSenderName;
  final DateTime? lastMessageTimestamp;
  final Map<String, int> unreadCounts;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final String postingStatus;
  final List<String> deletedBy;
  final bool isGroupChat;
  final String? groupName;
  final String? junkshopId;

  const ConversationModel({
    required this.id,
    required this.postingId,
    required this.participants,
    required this.participantDetails,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageSenderName,
    this.lastMessageTimestamp,
    required this.unreadCounts,
    this.createdAt,
    this.updatedAt,
    required this.isActive,
    required this.postingStatus,
    this.deletedBy = const [],
    this.isGroupChat = false,
    this.groupName,
    this.junkshopId,
  });

  /// Create from a map. Accepts either a legacy-shaped document map
  /// (see rowToDoc('conversations', row)) or a raw snake_case row.
  factory ConversationModel.fromMap(Map<String, dynamic> raw, {String? id}) {
    final data = raw.containsKey('participant_details') ||
            raw.containsKey('unread_counts') ||
            raw.containsKey('last_message_timestamp') ||
            raw.containsKey('is_active')
        ? rowToDoc('conversations', raw)
        : raw;

    Map<String, dynamic> asMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    return ConversationModel(
      id: id ?? data['id'] as String? ?? '',
      postingId: data[ConversationFields.postingId] as String? ?? '',
      participants: List<String>.from(
        (data[ConversationFields.participants] as List? ?? []).map(
          (e) => e.toString(),
        ),
      ),
      participantDetails: _parseParticipantDetails(
        asMap(data[ConversationFields.participantDetails]),
      ),
      lastMessage: data[ConversationFields.lastMessage] as String? ?? '',
      lastMessageSenderId:
          data[ConversationFields.lastMessageSenderId] as String? ?? '',
      lastMessageSenderName:
          data[ConversationFields.lastMessageSenderName] as String? ?? '',
      lastMessageTimestamp: toDateTime(
        data[ConversationFields.lastMessageTimestamp],
      ),
      unreadCounts: asMap(data[ConversationFields.unreadCounts]).map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      createdAt: toDateTime(data[ConversationFields.createdAt]),
      updatedAt: toDateTime(data[ConversationFields.updatedAt]),
      isActive: data[ConversationFields.isActive] as bool? ?? true,
      postingStatus:
          data[ConversationFields.postingStatus] as String? ?? 'pending',
      deletedBy: List<String>.from(
        (data['deletedBy'] as List? ?? []).map((e) => e.toString()),
      ),
      isGroupChat: data['isGroupChat'] as bool? ?? false,
      groupName: data['groupName'] as String?,
      junkshopId: data['junkshopId'] as String?,
    );
  }
  /// Parse participant details from map
  static Map<String, ParticipantDetails> _parseParticipantDetails(
    Map<String, dynamic> data,
  ) {
    final Map<String, ParticipantDetails> result = {};

    data.forEach((userId, details) {
      if (details is Map<String, dynamic>) {
        result[userId] = ParticipantDetails.fromMap(details);
      }
    });

    return result;
  }

  /// Convert to a legacy-shaped document map (use docToRow('conversations', ...) for DB writes)
  Map<String, dynamic> toMap() {
    return {
      ConversationFields.postingId: postingId,
      ConversationFields.participants: participants,
      ConversationFields.participantDetails: participantDetails.map(
        (userId, details) => MapEntry(userId, details.toMap()),
      ),
      ConversationFields.lastMessage: lastMessage,
      ConversationFields.lastMessageSenderId: lastMessageSenderId,
      ConversationFields.lastMessageSenderName: lastMessageSenderName,
      ConversationFields.lastMessageTimestamp: lastMessageTimestamp != null
          ? Timestamp.fromDate(lastMessageTimestamp!)
          : Timestamp.now(),
      ConversationFields.unreadCounts: unreadCounts,
      ConversationFields.createdAt: createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : Timestamp.now(),
      ConversationFields.updatedAt: Timestamp.now(),
      ConversationFields.isActive: isActive,
      ConversationFields.postingStatus: postingStatus,
      'deletedBy': deletedBy,
      'isGroupChat': isGroupChat,
      if (groupName != null) 'groupName': groupName,
      if (junkshopId != null) 'junkshopId': junkshopId,
    };
  }

  /// Get unread count for a specific user
  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  /// Get participant details for a specific user
  ParticipantDetails? getParticipant(String userId) {
    return participantDetails[userId];
  }

  /// Get the other participant (for 1-on-1 chats before collector assigned)
  ParticipantDetails? getOtherParticipant(String currentUserId) {
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    return otherUserId.isNotEmpty ? participantDetails[otherUserId] : null;
  }

  /// Check if a user is a participant
  bool isParticipant(String userId) {
    return participants.contains(userId);
  }

  /// Copy with updated fields
  ConversationModel copyWith({
    String? id,
    String? postingId,
    List<String>? participants,
    Map<String, ParticipantDetails>? participantDetails,
    String? lastMessage,
    String? lastMessageSenderId,
    String? lastMessageSenderName,
    DateTime? lastMessageTimestamp,
    Map<String, int>? unreadCounts,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? postingStatus,
    List<String>? deletedBy,
    bool? isGroupChat,
    String? groupName,
    String? junkshopId,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      postingId: postingId ?? this.postingId,
      participants: participants ?? this.participants,
      participantDetails: participantDetails ?? this.participantDetails,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderName:
          lastMessageSenderName ?? this.lastMessageSenderName,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      postingStatus: postingStatus ?? this.postingStatus,
      deletedBy: deletedBy ?? this.deletedBy,
      isGroupChat: isGroupChat ?? this.isGroupChat,
      groupName: groupName ?? this.groupName,
      junkshopId: junkshopId ?? this.junkshopId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    postingId,
    participants,
    participantDetails,
    lastMessage,
    lastMessageSenderId,
    lastMessageSenderName,
    lastMessageTimestamp,
    unreadCounts,
    createdAt,
    updatedAt,
    isActive,
    postingStatus,
    deletedBy,
    isGroupChat,
    groupName,
    junkshopId,
  ];
}

/// Details about a conversation participant
class ParticipantDetails extends Equatable {
  final String name;
  final String role; // 'household', 'junkshop', 'collector'
  final String? profileImage;
  final DateTime? joinedAt;

  const ParticipantDetails({
    required this.name,
    required this.role,
    this.profileImage,
    this.joinedAt,
  });

  /// Create from map
  factory ParticipantDetails.fromMap(Map<String, dynamic> map) {
    return ParticipantDetails(
      name: map[ConversationFields.participantName] as String? ?? '',
      role: map[ConversationFields.participantRole] as String? ?? '',
      profileImage: map[ConversationFields.participantProfileImage] as String?,
      joinedAt: toDateTime(map[ConversationFields.participantJoinedAt]),
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      ConversationFields.participantName: name,
      ConversationFields.participantRole: role,
      ConversationFields.participantProfileImage: profileImage,
      ConversationFields.participantJoinedAt: joinedAt != null
          ? joinedAt!.toUtc().toIso8601String()
          : DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Get role-specific color
  String getRoleColor() {
    switch (role) {
      case 'household':
        return '#3B82F6'; // Blue
      case 'collector':
        return '#10B981'; // Green
      case 'junkshop':
        return '#8B5CF6'; // Purple
      default:
        return '#6B7280'; // Gray
    }
  }

  /// Get role display name
  String getRoleDisplayName() {
    switch (role) {
      case 'household':
        return 'Household';
      case 'collector':
        return 'Collector';
      case 'junkshop':
        return 'Junkshop';
      default:
        return 'User';
    }
  }

  @override
  List<Object?> get props => [name, role, profileImage, joinedAt];
}
