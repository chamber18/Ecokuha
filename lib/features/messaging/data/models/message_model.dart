import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:equatable/equatable.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';

/// Message types
enum MessageType {
  text,
  image,
  system,
  statusUpdate;

  /// Convert to string
  String toValue() {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.system:
        return 'system';
      case MessageType.statusUpdate:
        return 'status_update';
    }
  }

  /// Parse from string
  static MessageType fromValue(String value) {
    switch (value) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'system':
        return MessageType.system;
      case 'status_update':
        return MessageType.statusUpdate;
      default:
        return MessageType.text;
    }
  }
}

/// Model representing a message in a conversation
class MessageModel extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole; // 'household', 'collector', 'junkshop', 'system'
  final String text;
  final MessageType type;
  final DateTime? timestamp;
  final List<String> readBy;
  final Map<String, dynamic>? metadata;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.type,
    this.timestamp,
    required this.readBy,
    this.metadata,
  });

  /// Create from a map (legacy-shaped doc map or raw snake_case row)
  factory MessageModel.fromMap(Map<String, dynamic> raw, {String? id}) {
    final data = raw.containsKey('sender_id') || raw.containsKey('read_by') || raw.containsKey('created_at')
        ? rowToDoc('messages', raw)
        : raw;

    return MessageModel(
      id: id ?? data['id']?.toString() ?? '',
      senderId: data[MessageFields.senderId]?.toString() ?? '',
      senderName: data[MessageFields.senderName] as String? ?? '',
      senderRole: data[MessageFields.senderRole] as String? ?? '',
      text: data[MessageFields.text] as String? ?? '',
      type: MessageType.fromValue(
        data[MessageFields.type] as String? ?? 'text',
      ),
      timestamp: toDateTime(data[MessageFields.timestamp]),
      readBy: List<String>.from((data[MessageFields.readBy] as List? ?? []).map((e) => e.toString())),
      metadata: data['metadata'] is Map ? Map<String, dynamic>.from(data['metadata'] as Map) : null,
    );
  }

  /// Convert to a legacy-shaped document map
  Map<String, dynamic> toMap() {
    return {
      MessageFields.senderId: senderId,
      MessageFields.senderName: senderName,
      MessageFields.senderRole: senderRole,
      MessageFields.text: text,
      MessageFields.type: type.toValue(),
      MessageFields.timestamp: Timestamp.fromDate(timestamp ?? DateTime.now()),
      MessageFields.readBy: readBy,
      'metadata': metadata,
    };
  }

  /// Check if message has been read by a user
  bool isReadBy(String userId) {
    return readBy.contains(userId);
  }

  /// Check if message is from current user
  bool isFromUser(String currentUserId) {
    return senderId == currentUserId;
  }

  /// Check if message is a system message
  bool get isSystemMessage => type == MessageType.system;

  /// Check if message is a status update
  bool get isStatusUpdate => type == MessageType.statusUpdate;

  /// Check if message has an image
  bool get hasImage => type == MessageType.image;

  /// Get image URL from metadata
  String? get imageUrl {
    return metadata?['imageUrl'] as String?;
  }

  /// Get thumbnail URL from metadata
  String? get thumbnailUrl {
    return metadata?['thumbnailUrl'] as String?;
  }

  /// Get old status from status update metadata
  String? get oldStatus {
    return metadata?['oldStatus'] as String?;
  }

  /// Get new status from status update metadata
  String? get newStatus {
    return metadata?['newStatus'] as String?;
  }

  /// Get action type for system messages
  String? get systemAction {
    return metadata?['action'] as String?;
  }

  /// Format timestamp for display
  String getFormattedTime() {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final difference = now.difference(timestamp!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Format as date
      return '${timestamp!.month}/${timestamp!.day}/${timestamp!.year}';
    }
  }

  /// Get time in HH:MM format
  String getTimeOnly() {
    if (timestamp == null) return '';

    final hour = timestamp!.hour.toString().padLeft(2, '0');
    final minute = timestamp!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Copy with updated fields
  MessageModel copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? text,
    MessageType? type,
    DateTime? timestamp,
    List<String>? readBy,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      text: text ?? this.text,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      readBy: readBy ?? this.readBy,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderName,
    senderRole,
    text,
    type,
    timestamp,
    readBy,
    metadata,
  ];
}

/// Helper class to create different types of messages
class MessageFactory {
  /// Create a text message
  static Map<String, dynamic> createTextMessage({
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
  }) {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': text,
      'type': 'text',
      'readBy': [senderId],
      'metadata': null,
    };
  }

  /// Create an image message
  static Map<String, dynamic> createImageMessage({
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
    required String imageUrl,
    String? thumbnailUrl,
  }) {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': text,
      'type': 'image',
      'readBy': [senderId],
      'metadata': {'imageUrl': imageUrl, 'thumbnailUrl': thumbnailUrl},
    };
  }

  /// Create a system message
  static Map<String, dynamic> createSystemMessage({
    required String text,
    required String action,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return {
      'senderId': 'ecokuha_assistant',
      'senderName': 'EcoKuha Assistant',
      'senderRole': 'system',
      'text': text,
      'type': 'system',
      'readBy': [],
      'metadata': {'action': action, ...?additionalMetadata},
    };
  }

  /// Create a status update message
  static Map<String, dynamic> createStatusUpdateMessage({
    required String senderId,
    required String senderName,
    required String senderRole,
    required String oldStatus,
    required String newStatus,
  }) {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': 'Status updated: ${_getStatusDisplayName(newStatus)}',
      'type': 'status_update',
      'readBy': [senderId],
      'metadata': {'oldStatus': oldStatus, 'newStatus': newStatus},
    };
  }

  /// Get display name for status
  static String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'queued':
        return 'Queued';
      case 'assigned':
        return 'Assigned';
      case 'in_transit':
        return 'On the way';
      case 'arrived':
        return 'Arrived';
      case 'collecting':
        return 'Collecting';
      case 'completed':
        return 'Completed';
      case 'declined':
        return 'Declined';
      default:
        return status;
    }
  }
}
