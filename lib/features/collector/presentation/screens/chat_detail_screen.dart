import 'package:flutter/material.dart';
import '../../../../../core/utils/app_image_provider.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/common/stacked_avatars.dart';
import '../../../messaging/data/repositories/chat_repository.dart';
import '../../../messaging/data/models/conversation_model.dart';
import '../../../messaging/data/models/message_model.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? conversation;

  const ChatDetailScreen({super.key, this.conversation});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _chatRepository = ChatRepository();
  final String _currentUserId = currentUid ?? '';
  String _currentUserName = '';
  String _currentUserRole = 'collector';
  ConversationModel? _conversationModel;
  @override
  void initState() {
    super.initState();
    _initializeConversation();
  }

  void _initializeConversation() {
    // Extract ConversationModel from the passed argument
    if (widget.conversation != null &&
        widget.conversation!.containsKey('conversation')) {
      _conversationModel =
          widget.conversation!['conversation'] as ConversationModel;
      _loadCurrentUserInfo();
      _markAsRead();
    }
  }

  void _loadCurrentUserInfo() {
    if (_conversationModel == null) return;
    final participant = _conversationModel!.participantDetails[_currentUserId];
    if (participant != null) {
      _currentUserName = participant.name;
      _currentUserRole = participant.role;
    }
  }

  void _markAsRead() {
    if (_conversationModel == null) return;
    _chatRepository.markConversationAsRead(
      conversationId: _conversationModel!.id,
      userId: _currentUserId,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_conversationModel == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Chat'),
          backgroundColor: Colors.white,
        ),
        body: const Center(child: Text('Invalid conversation')),
      );
    }

    // Get all non-collector participants for display
    final nonCollectorParticipants = _conversationModel!.participants
        .where((participantId) => participantId != _currentUserId)
        .map(
          (participantId) =>
              _conversationModel!.participantDetails[participantId],
        )
        .where((details) => details != null)
        .cast<ParticipantDetails>()
        .toList();

    // Build avatar data list for header
    final avatarDataList = nonCollectorParticipants.map((participant) {
      return AvatarData.fromParticipant(
        name: participant.name,
        profileImage: participant.profileImage,
        role: participant.role,
      );
    }).toList();

    // Get display name - use group name for group chats
    String displayName;
    String subtitle;
    if (_conversationModel!.isGroupChat) {
      displayName = _conversationModel!.groupName ?? 'Group Chat';
      subtitle = 'Group Chat';
    } else if (nonCollectorParticipants.length > 1) {
      // Find household and junkshop
      final household = nonCollectorParticipants.firstWhere(
        (p) => p.role == 'household',
        orElse: () => nonCollectorParticipants.first,
      );
      final junkshop = nonCollectorParticipants.firstWhere(
        (p) => p.role == 'junkshop',
        orElse: () => nonCollectorParticipants.last,
      );
      displayName = household.name;
      subtitle = 'with ${junkshop.name} (Junkshop)';
    } else if (nonCollectorParticipants.isNotEmpty) {
      displayName = nonCollectorParticipants.first.name;
      subtitle = nonCollectorParticipants.first.role == 'household'
          ? 'Household'
          : nonCollectorParticipants.first.role == 'junkshop'
          ? 'Junkshop'
          : 'Chat';
    } else {
      displayName = 'Conversation';
      subtitle = 'Chat';
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Row(
          children: [
            if (avatarDataList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: StackedAvatars(
                  avatars: avatarDataList,
                  size: 40,
                  borderWidth: 1.5,
                  borderColor: Colors.white,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showConversationInfo(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatRepository.getMessagesStream(_conversationModel!.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say hi to start the conversation!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                // Show ALL messages including system messages
                final allMessages = messages;

                // Format creation date
                final createdAt =
                    _conversationModel!.createdAt ?? DateTime.now();
                final formattedDate =
                    '${createdAt.month}/${createdAt.day}/${createdAt.year} at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  reverse: true,
                  itemCount: allMessages.length + 1, // +1 for header
                  itemBuilder: (context, index) {
                    // Last item is the date header (renders at top with reverse:true)
                    if (index == allMessages.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Center(
                          child: Text(
                            formattedDate,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }

                    // index 0 = latest message (renders at bottom)
                    final messageIndex = allMessages.length - 1 - index;
                    final message = allMessages[messageIndex];
                    final previousMessage = messageIndex > 0
                        ? allMessages[messageIndex - 1]
                        : null;
                    final nextMessage = messageIndex < allMessages.length - 1
                        ? allMessages[messageIndex + 1]
                        : null;

                    // If it's a system message, show it as a left-aligned bubble
                    if (message.isSystemMessage) {
                      return _buildSystemMessageBubble(message);
                    }

                    final showAvatar =
                        nextMessage == null ||
                        nextMessage.senderId != message.senderId ||
                        nextMessage.isSystemMessage;
                    final showName =
                        (previousMessage == null ||
                            previousMessage.senderId != message.senderId ||
                            previousMessage.isSystemMessage) &&
                        !message.isFromUser(_currentUserId);

                    return _buildMessageBubble(message, showAvatar, showName);
                  },
                );
              },
            ),
          ),
          // Input bar
          _buildMessageInputBar(),
        ],
      ),
    );
  }

  Widget _buildSystemMessageBubble(MessageModel message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1, top: 2, left: 12, right: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System avatar
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey[400],
              child: const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // System name
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    'System',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                // Message bubble
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                    ),
                    child: Text(
                      message.text,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConversationInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conversation Members',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 20),
                ..._conversationModel!.participantDetails.entries.map((entry) {
                  final participant = entry.value;
                  final hasValidImage =
                      participant.profileImage != null &&
                      !participant.profileImage!.startsWith('data:image');

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: _getRoleColor(participant.role),
                      backgroundImage: hasValidImage
                          ? AppImageProvider(participant.profileImage!)
                                as ImageProvider
                          : null,
                      onBackgroundImageError: hasValidImage
                          ? (exception, stackTrace) {
                              if (kDebugMode) {
                                print(
                                  '❌ Failed to load profile image in info modal: $exception',
                                );
                              }
                            }
                          : null,
                      child: !hasValidImage
                          ? Text(
                              participant.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      participant.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      participant.getRoleDisplayName(),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'household':
        return const Color(0xFF3B82F6);
      case 'collector':
        return AppColors.successColor;
      case 'junkshop':
        return const Color(0xFF8B5CF6);
      default:
        return Colors.grey;
    }
  }

  Widget _buildMessageInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.add_circle,
                color: AppColors.successColor,
                size: 28,
              ),
              onPressed: () {
                // Show options (image, camera, etc.)
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Aa',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              decoration: BoxDecoration(
                color: AppColors.successColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    MessageModel message,
    bool showAvatar,
    bool showName,
  ) {
    // Treat system messages as normal conversation bubbles (left-aligned, no avatar)
    final isSystem =
        message.senderId == 'system' ||
        message.senderRole == 'system' ||
        message.isSystemMessage;
    final isFromMe = !isSystem && message.isFromUser(_currentUserId);

    // Get sender's profile image from conversation participants
    final senderParticipant =
        _conversationModel!.participantDetails[message.senderId];
    final senderProfileImage = senderParticipant?.profileImage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 1, top: 2, left: 12, right: 12),
      child: Row(
        mainAxisAlignment: isFromMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFromMe && showAvatar && !isSystem)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: _getRoleColor(message.senderRole),
                backgroundImage:
                    senderProfileImage != null &&
                        !senderProfileImage.startsWith('data:image')
                    ? AppImageProvider(senderProfileImage) as ImageProvider
                    : null,
                onBackgroundImageError: senderProfileImage != null
                    ? (exception, stackTrace) {
                        if (kDebugMode) {
                          print(
                            '❌ Failed to load sender profile image: $exception',
                          );
                        }
                      }
                    : null,
                child:
                    senderProfileImage == null ||
                        senderProfileImage.startsWith('data:image')
                    ? Text(
                        message.senderName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          if (!isFromMe && showAvatar && !isSystem) const SizedBox(width: 4),
          if (!isFromMe && (!showAvatar || isSystem)) const SizedBox(width: 28),
          Flexible(
            child: Column(
              crossAxisAlignment: isFromMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showName && !isFromMe && !isSystem)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isFromMe
                        ? AppColors.successColor
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(
                        isFromMe ? 18 : (showAvatar ? 18 : 4),
                      ),
                      bottomRight: Radius.circular(
                        isFromMe ? (showAvatar ? 18 : 4) : 18,
                      ),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: isFromMe ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (showAvatar && !isSystem) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      message.getTimeOnly(),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    try {
      await _chatRepository.sendTextMessage(
        conversationId: _conversationModel!.id,
        senderId: _currentUserId,
        senderName: _currentUserName,
        senderRole: _currentUserRole,
        text: text,
      );

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }
}
