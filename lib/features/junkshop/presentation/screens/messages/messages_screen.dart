import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../../core/utils/app_image_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/constants/firestore_fields/index.dart';
import '../../../../../core/utils/phone_launcher.dart';
import '../../../../../shared/widgets/common/stacked_avatars.dart';
import '../../../../messaging/data/repositories/chat_repository.dart';
import '../../../../messaging/data/models/conversation_model.dart';
import 'junkshop_chat_detail_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ChatRepository _chatRepository = ChatRepository();
  final String _currentUserId = currentUid ?? '';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Cached active-today status for other participants (userId → isActiveToday)
  final Map<String, bool> _participantActiveStatus = {};
  final Set<String> _fetchedParticipantIds = {};

  /// Fetch last_login_at for participants not yet checked. One read per unique
  /// user per session; results are cached to avoid repeated Firebase requests.
  void _loadParticipantStatuses(List<ConversationModel> conversations) {
    final toFetch = <String, String>{}; // userId → role
    for (final conv in conversations) {
      for (final participantId in conv.participants) {
        if (participantId != _currentUserId &&
            !_fetchedParticipantIds.contains(participantId)) {
          final details = conv.participantDetails[participantId];
          if (details != null) {
            toFetch[participantId] = details.role;
          }
        }
      }
    }
    if (toFetch.isEmpty) return;
    _fetchedParticipantIds.addAll(toFetch.keys);
    for (final entry in toFetch.entries) {
      _checkParticipantActiveToday(entry.key, entry.value);
    }
  }

  Future<void> _checkParticipantActiveToday(String userId, String role) async {
    try {
      final collectionName = role == 'household'
          ? 'households'
          : role == 'collector'
          ? 'collectors'
          : 'junkshops';
      final doc = await supabase
          .from(collectionName)
          .select('last_login_at')
          .eq('id', userId)
          .maybeSingle();
      if (doc == null) return;
      final lastLoginStr = doc['last_login_at'] as String?;
      bool isActive = false;
      if (lastLoginStr != null) {
        try {
          final lastLogin = DateTime.parse(lastLoginStr);
          final now = DateTime.now();
          isActive =
              lastLogin.year == now.year &&
              lastLogin.month == now.month &&
              lastLogin.day == now.day;
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _participantActiveStatus[userId] = isActive);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    // Wait for a brief moment to show the refresh animation
    await Future.delayed(const Duration(milliseconds: 500));
    // The StreamBuilder will automatically refresh with new data
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              _showNewChatDialog(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ConversationModel>>(
        stream: _chatRepository.getActiveConversationsStream(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var allConversations = snapshot.data!;

          // Fetch active status once per unique participant
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _loadParticipantStatuses(allConversations),
          );

          // Filter conversations based on search query
          if (_searchQuery.isNotEmpty) {
            allConversations = allConversations.where((conv) {
              // Search in participant names
              final participantNames = conv.participantDetails.values
                  .map((p) => p.name.toLowerCase())
                  .join(' ');
              // Search in last message
              final lastMessage = conv.lastMessage.toLowerCase();

              return participantNames.contains(_searchQuery) ||
                  lastMessage.contains(_searchQuery);
            }).toList();
          }

          return Column(
            children: [
              // Fixed search bar at the top
              Container(
                color: AppColors.backgroundDark,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Color(0xFF6B7280),
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              // Scrollable conversations list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppColors.primaryGreen,
                  backgroundColor: Colors.white,
                  child: _buildConversationsList(allConversations),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConversationsList(List<ConversationModel> conversations) {
    if (conversations.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
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
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to start a new chat',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        return _buildConversationRow(conversations[index]);
      },
    );
  }

  Widget _buildConversationRow(ConversationModel conversation) {
    final unreadCount = conversation.getUnreadCount(_currentUserId);
    final hasUnread = unreadCount > 0;

    // Handle group chats differently
    if (conversation.isGroupChat) {
      final nonJunkshopParticipants = conversation.participants
          .where((participantId) => participantId != _currentUserId)
          .map(
            (participantId) => conversation.participantDetails[participantId],
          )
          .where((details) => details != null)
          .cast<ParticipantDetails>()
          .toList();

      final avatarDataList = nonJunkshopParticipants.map((participant) {
        return AvatarData.fromParticipant(
          name: participant.name,
          profileImage: participant.profileImage,
          role: participant.role,
        );
      }).toList();

      return _buildGroupChatRow(
        conversation: conversation,
        displayName: conversation.groupName ?? 'Group Chat',
        avatarDataList: avatarDataList,
        hasUnread: hasUnread,
        unreadCount: unreadCount,
      );
    }

    // Handle regular 1-on-1 chats
    final otherParticipant = conversation.getOtherParticipant(_currentUserId);
    if (otherParticipant == null) return const SizedBox.shrink();

    // Get all non-junkshop participants for avatar display
    final nonJunkshopParticipants = conversation.participants
        .where((participantId) => participantId != _currentUserId)
        .map((participantId) => conversation.participantDetails[participantId])
        .where((details) => details != null)
        .cast<ParticipantDetails>()
        .toList();

    // Build avatar data list for stacked display
    final avatarDataList = nonJunkshopParticipants.map((participant) {
      return AvatarData.fromParticipant(
        name: participant.name,
        profileImage: participant.profileImage,
        role: participant.role,
      );
    }).toList();

    // Get display name - show both names if multiple participants
    String displayName;
    if (nonJunkshopParticipants.length > 1) {
      // Find household and collector
      final household = nonJunkshopParticipants.firstWhere(
        (p) => p.role == 'household',
        orElse: () => nonJunkshopParticipants.first,
      );
      final collector = nonJunkshopParticipants.firstWhere(
        (p) => p.role == 'collector',
        orElse: () => nonJunkshopParticipants.last,
      );
      displayName = '${household.name}, ${collector.name}';
    } else {
      displayName = otherParticipant.name;
    }

    return InkWell(
      onTap: () => _openConversation(conversation),
      onLongPress: () => _showConversationOptions(conversation),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar - use stacked avatars if multiple participants
            if (avatarDataList.length > 1)
              StackedAvatars(
                avatars: avatarDataList,
                size: 52,
                showOnlineStatus: false,
              )
            else
              // Single chat - show regular avatar with active indicator
              Builder(
                builder: (context) {
                  final otherParticipantId = conversation.participants
                      .firstWhere(
                        (id) => id != _currentUserId,
                        orElse: () => '',
                      );
                  return Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: _getRoleColor(otherParticipant.role),
                        backgroundImage:
                            otherParticipant.profileImage != null &&
                                otherParticipant.profileImage!.isNotEmpty &&
                                !otherParticipant.profileImage!.startsWith(
                                  'data:image',
                                )
                            ? AppImageProvider(
                                    otherParticipant.profileImage!,
                                  )
                                  as ImageProvider
                            : null,
                        child:
                            otherParticipant.profileImage == null ||
                                otherParticipant.profileImage!.isEmpty ||
                                otherParticipant.profileImage!.startsWith(
                                  'data:image',
                                )
                            ? Text(
                                otherParticipant.name.isNotEmpty
                                    ? otherParticipant.name
                                          .substring(0, 1)
                                          .toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (_participantActiveStatus[otherParticipantId] == true)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.successColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(
                          conversation.lastMessageTimestamp ?? DateTime.now(),
                        ),
                        style: TextStyle(
                          color: hasUnread
                              ? AppColors.successColor
                              : const Color(0xFF9CA3AF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: hasUnread
                                ? const Color(0xFF374151)
                                : const Color(0xFF9CA3AF),
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChatRow({
    required ConversationModel conversation,
    required String displayName,
    required List<AvatarData> avatarDataList,
    required bool hasUnread,
    required int unreadCount,
  }) {
    // Get junkshop profile image - use current user ID since junkshop is viewing
    final junkshopId = conversation.junkshopId ?? _currentUserId;
    final junkshopDetails = conversation.participantDetails[junkshopId];
    final junkshopProfileImage = junkshopDetails?.profileImage;
    final junkshopName = junkshopDetails?.name ?? displayName;

    return InkWell(
      onTap: () => _openConversation(conversation),
      onLongPress: () => _showGroupChatOptions(conversation),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group avatar - use junkshop profile image
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.junkshopPrimary,
              backgroundImage:
                  junkshopProfileImage != null &&
                      junkshopProfileImage.isNotEmpty
                  ? AppImageProvider(junkshopProfileImage)
                  : null,
              child:
                  junkshopProfileImage == null || junkshopProfileImage.isEmpty
                  ? Text(
                      junkshopName.isNotEmpty
                          ? junkshopName[0].toUpperCase()
                          : 'J',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.group,
                        size: 16,
                        color: AppColors.successColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(
                          conversation.lastMessageTimestamp ?? DateTime.now(),
                        ),
                        style: TextStyle(
                          color: hasUnread
                              ? AppColors.successColor
                              : const Color(0xFF9CA3AF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: hasUnread
                                ? const Color(0xFF374151)
                                : const Color(0xFF9CA3AF),
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'household':
        return const Color(0xFF3B82F6); // Blue for households
      case 'collector':
        return AppColors.successColor; // Green for collectors
      case 'junkshop':
        return const Color(0xFF8B5CF6); // Purple for junkshops
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }

  void _openConversation(ConversationModel conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            JunkshopChatDetailScreen(conversation: conversation),
      ),
    );
  }

  void _showConversationOptions(ConversationModel conversation) {
    final otherParticipant = conversation.getOtherParticipant(_currentUserId);
    if (otherParticipant == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              otherParticipant.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 20),

            ListTile(
              leading: const Icon(Icons.mark_chat_read),
              title: const Text('Mark as Read'),
              onTap: () {
                Navigator.pop(context);
                _markAsRead(conversation);
              },
            ),

            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Call'),
              onTap: () async {
                Navigator.pop(context);
                await _callParticipant(conversation);
              },
            ),

            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteConversation(conversation);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupChatOptions(ConversationModel conversation) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Icon(Icons.group, color: AppColors.successColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conversation.groupName ?? 'Group Chat',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              '${conversation.participants.length} members',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),

            const SizedBox(height: 20),

            ListTile(
              leading: const Icon(Icons.mark_chat_read),
              title: const Text('Mark as Read'),
              onTap: () {
                Navigator.pop(context);
                _markAsRead(conversation);
              },
            ),

            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteConversation(conversation);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Text(
                            'Start a Chat',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Select a household or collector to start chatting',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value.toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 15,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Color(0xFF6B7280),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // List of households and collectors
                    Flexible(child: _buildUsersList(searchQuery)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersList(String searchQuery) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getCombinedUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Error loading users: ${snapshot.error}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        var users = snapshot.data!;

        // Filter by search query
        if (searchQuery.isNotEmpty) {
          users = users.where((user) {
            final name = (user['name'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery);
          }).toList();
        }

        if (users.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.people_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'No users found'
                        : 'No users available',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final name = user['name'] ?? 'Unknown User';
            final role = user['role'] ?? 'user';
            var profileImage = user['profileImage'];

            // Skip base64 images
            if (profileImage != null &&
                profileImage.toString().startsWith('data:image')) {
              profileImage = null;
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: _getRoleColor(role),
                backgroundImage:
                    profileImage != null &&
                        profileImage.isNotEmpty &&
                        (profileImage.startsWith('http://') ||
                            profileImage.startsWith('https://'))
                    ? AppImageProvider(profileImage) as ImageProvider
                    : null,
                onBackgroundImageError: profileImage != null
                    ? (exception, stackTrace) {
                        if (kDebugMode) {
                          print(
                            '❌ Failed to load profile image for $name: $exception',
                          );
                        }
                      }
                    : null,
                child:
                    profileImage == null ||
                        profileImage.isEmpty ||
                        !(profileImage.startsWith('http://') ||
                            profileImage.startsWith('https://'))
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                role == 'household' ? 'Household' : 'Collector',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _startChatWithUser(user);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _startChatWithUser(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final userName = user['name'] ?? 'Unknown User';
    final userRole = user['role'] ?? 'user';
    final profileImage = user['profileImage'];

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting chat with $userName...'),
            duration: const Duration(seconds: 1),
            backgroundColor: AppColors.successColor,
          ),
        );
      }

      // Check if conversation already exists
      final existingConversations = await _chatRepository
          .getActiveConversationsStream(_currentUserId)
          .first;

      ConversationModel? existingConversation;
      for (var conv in existingConversations) {
        // Check if this is a 1-on-1 conversation with this user
        if (conv.participants.length == 2 &&
            conv.participants.contains(userId)) {
          existingConversation = conv;
          break;
        }
      }

      if (existingConversation != null) {
        // Navigate to existing conversation
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  JunkshopChatDetailScreen(conversation: existingConversation!),
            ),
          );
        }
      } else {
        // Create new conversation
        final conversationId = await _createNewConversation(
          userId: userId,
          userName: userName,
          userRole: userRole,
          profileImage: profileImage,
        );

        if (conversationId != null && mounted) {
          // Wait a moment for the conversation to be created
          await Future.delayed(const Duration(milliseconds: 500));

          // Fetch the created conversation
          final conversation = await _chatRepository
              .getConversationStream(conversationId)
              .first;

          if (conversation != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    JunkshopChatDetailScreen(conversation: conversation),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error starting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _createNewConversation({
    required String userId,
    required String userName,
    required String userRole,
    String? profileImage,
  }) async {
    try {
      // Get current junkshop user info
      final junkshopRow = await supabase
          .from('junkshops')
          .select()
          .eq('id', _currentUserId)
          .maybeSingle();

      if (junkshopRow == null) {
        throw Exception('Junkshop profile not found');
      }

      final junkshopData = rowToDoc('junkshops', junkshopRow);
      final junkshopProfile =
          junkshopData[UserFields.junkshopProfile] as Map<String, dynamic>?;
      final business = junkshopProfile?['business'] as Map<String, dynamic>?;

      final junkshopName =
          (business?['business_name'] ??
                  junkshopData[UserFields.businessName] ??
                  junkshopData[UserFields.name] ??
                  'Unknown Junkshop')
              .toString();

      final junkshopProfileImage =
          (junkshopData[UserFields.profileImageUrl] ??
                  junkshopData['profileImage'])
              ?.toString();

      // Direct conversation id (no posting involved)
      final directId = userRole == 'household'
          ? 'direct_${userId}_$_currentUserId'
          : 'direct_${_currentUserId}_$userId';

      return await _chatRepository.createConversation(
        postingId: directId,
        participants: [_currentUserId, userId],
        participantDetails: {
          _currentUserId: ParticipantDetails(
            name: junkshopName,
            role: 'junkshop',
            profileImage: junkshopProfileImage,
            joinedAt: DateTime.now(),
          ),
          userId: ParticipantDetails(
            name: userName,
            role: userRole,
            profileImage: profileImage,
            joinedAt: DateTime.now(),
          ),
        },
        initialMessage: 'Chat started between $junkshopName and $userName',
      );
    } catch (e) {
      if (kDebugMode) print('Error creating conversation: $e');
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> _getCombinedUsersStream() {
    // Re-evaluate whenever this junkshop's collectors change
    return supabase
        .from('collectors')
        .stream(primaryKey: ['id'])
        .eq('preferred_junkshop_id', _currentUserId)
        .asyncMap((_) async {
      List<Map<String, dynamic>> allUsers = [];

      // Get households
      try {
        final householdRows = await supabase.from('households').select();

        for (final data in rowsToDocs('households', householdRows)) {
          allUsers.add({
            'id': data['id'],
            'name':
                data[UserFields.fullName] ??
                data[UserFields.name] ??
                'Unknown Household',
            'profileImage':
                data[UserFields.profileImageUrl] ?? data['profileImage'],
            'role': 'household',
          });
        }
      } catch (e) {
        if (kDebugMode) print('Error loading households: $e');
      }

      // Get collectors assigned to this junkshop and approved only
      try {
        final collectorRows = await supabase
            .from('collectors')
            .select()
            .eq('preferred_junkshop_id', _currentUserId)
            .eq('application_status', 'approved');

        for (final data in rowsToDocs('collectors', collectorRows)) {
          // Extract name from nested collector_profile.personal structure
          final collectorProfile =
              data[UserFields.collectorProfile] as Map<String, dynamic>?;
          final personal =
              collectorProfile?['personal'] as Map<String, dynamic>?;
          final name =
              personal?[UserFields.fullName] ??
              personal?['fullName'] ??
              personal?[UserFields.name] ??
              data[UserFields.fullName] ??
              data['fullName'] ??
              data[UserFields.name] ??
              'Unknown Collector';

          allUsers.add({
            'id': data['id'],
            'name': name,
            'profileImage':
                data[UserFields.profileImageUrl] ?? data['profileImageUrl'],
            'role': 'collector',
          });
        }
      } catch (e) {
        if (kDebugMode) print('Error loading collectors: $e');
      }

      return allUsers;
    });
  }

  void _markAsRead(ConversationModel conversation) async {
    try {
      await _chatRepository.markConversationAsRead(
        conversationId: conversation.id,
        userId: _currentUserId,
      );
      final otherName =
          conversation.getOtherParticipant(_currentUserId)?.name ?? 'Unknown';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked conversation with $otherName as read'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking as read: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteConversation(ConversationModel conversation) {
    final otherName =
        conversation.getOtherParticipant(_currentUserId)?.name ?? 'Unknown';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text(
          'Are you sure you want to delete the conversation with $otherName? This will only remove it from your inbox.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatRepository.softDeleteConversation(
                  conversationId: conversation.id,
                  userId: _currentUserId,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conversation deleted'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Failed to delete conversation. Please try again.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _callParticipant(ConversationModel conversation) async {
    try {
      final otherParticipant = conversation.getOtherParticipant(_currentUserId);
      if (otherParticipant == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Participant not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Determine role and fetch phone from Firestore
      final role = otherParticipant.role;

      // Get the userId from the participants list
      final userId = conversation.participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );

      if (userId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User ID not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final userDoc = await supabase
          .from(role == 'collector' ? 'collectors' : 'households')
          .select('phone')
          .eq('id', userId)
          .maybeSingle();

      if (userDoc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final phoneNumber = userDoc['phone'] as String?;

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        await PhoneLauncher.makePhoneCall(phoneNumber);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone number not available'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to make phone call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
