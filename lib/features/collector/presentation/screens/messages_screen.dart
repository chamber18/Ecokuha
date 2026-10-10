import 'package:flutter/material.dart';
import '../../../../../core/utils/app_image_provider.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../messaging/data/repositories/chat_repository.dart';
import '../../../messaging/data/models/conversation_model.dart';
import '../../../../shared/widgets/common/stacked_avatars.dart';

class CollectorMessagesScreen extends StatefulWidget {
  const CollectorMessagesScreen({super.key});

  @override
  State<CollectorMessagesScreen> createState() =>
      _CollectorMessagesScreenState();
}

class _CollectorMessagesScreenState extends State<CollectorMessagesScreen> {
  final ChatRepository _chatRepository = ChatRepository();
  final String _currentUserId = currentUid ?? '';
  final Set<String> _updatingConversations =
      {}; // Track conversations being updated
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
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _currentUserId.isEmpty
            ? null
            : supabase
                  .from('collectors')
                  .stream(primaryKey: ['id'])
                  .eq('id', _currentUserId)
                  .map(
                    (rows) =>
                        rows.isEmpty ? null : rowToDoc('collectors', rows.first),
                  ),
        builder: (context, statusSnap) {
          final collectorData = statusSnap.data;
          final status =
              collectorData?['application_status'] as String? ?? 'approved';

          // Resolve junkshop ID from collector doc
          final cp =
              collectorData?['collector_profile'] as Map<String, dynamic>?;
          final personal = cp?['personal'] as Map<String, dynamic>?;
          final junkshopId =
              (personal?['preferred_junkshop_id'] ??
                      cp?['preferred_junkshop_id'] ??
                      collectorData?['preferred_junkshop_id'] ??
                      '')
                  .toString()
                  .trim();

          if (status == 'reapplying' ||
              status == 'rejected' ||
              status == 'fired') {
            final isRejected = status == 'rejected';
            final isFired = status == 'fired';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFired
                          ? Icons.person_remove_rounded
                          : isRejected
                          ? Icons.cancel_rounded
                          : Icons.chat_bubble_outline,
                      size: 64,
                      color: isFired
                          ? Colors.red.shade400
                          : isRejected
                          ? Colors.red.shade400
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Messaging Unavailable',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isFired
                            ? Colors.red.shade700
                            : isRejected
                            ? Colors.red.shade700
                            : Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFired
                          ? 'You\'ve been dismissed by your junkshop. Messaging is unavailable until you reapply and get approved by a new junkshop.'
                          : isRejected
                          ? 'Your reapplication was rejected. Messaging is paused until you reapply and get approved by a junkshop.'
                          : 'Your reapplication is pending review. Messaging will be available again once your junkshop approves your request.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isFired
                            ? Colors.red.shade600
                            : isRejected
                            ? Colors.red.shade600
                            : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Block messaging when the partner junkshop is disabled by admin
          if (junkshopId.isNotEmpty) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: supabase
                  .from('junkshops')
                  .select()
                  .eq('id', junkshopId)
                  .maybeSingle()
                  .then(
                    (row) => row == null ? null : rowToDoc('junkshops', row),
                  ),
              builder: (context, jsSnap) {
                if (jsSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final jsData = jsSnap.data;
                final junkshopDisabled = jsData?['isActive'] == false;
                if (junkshopDisabled) {
                  final shopName =
                      ((jsData?['junkshop_profile']
                                  as Map<String, dynamic>?)?['business_name'] ??
                              jsData?['full_name'] ??
                              'Your junkshop')
                          .toString()
                          .trim();
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.domain_disabled_rounded,
                            size: 64,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Messaging Unavailable',
                            style: AppTextStyles.h5.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$shopName has been disabled by the administrator. Messaging is unavailable until you reapply to an active junkshop and get approved.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.red.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return _buildConversationList();
              },
            );
          }
          return _buildConversationList();
        },
      ),
    );
  }

  Widget _buildConversationList() {
    return StreamBuilder<List<ConversationModel>>(
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

        if (_searchQuery.isNotEmpty) {
          allConversations = allConversations.where((conv) {
            final participantNames = conv.participantDetails.values
                .map((p) => p.name.toLowerCase())
                .join(' ');
            final lastMessage = conv.lastMessage.toLowerCase();
            return participantNames.contains(_searchQuery) ||
                lastMessage.contains(_searchQuery);
          }).toList();
        }

        return Column(
          children: [
            Container(
              color: Colors.white,
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
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start chatting with households or junkshops',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
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
        final actualIndex = index ~/ 2;

        if (index.isOdd) {
          return const Divider(
            height: 1,
            thickness: 0.6,
            indent: 64,
            color: Color(0xFFE2E8F0),
          );
        }

        if (actualIndex >= conversations.length) return null;

        final conversation = conversations[actualIndex];

        // Get other participants (excluding current user)
        final otherParticipantIds = conversation.participants
            .where((id) => id != _currentUserId)
            .toList();

        // For 3+ person chats (posting conversations), prioritize household
        // For 2-person chats, get the only other participant
        String otherParticipantId = '';
        if (otherParticipantIds.length > 1) {
          // Multi-person chat - find household first
          final householdId = otherParticipantIds.firstWhere(
            (id) => conversation.participantDetails[id]?.role == 'household',
            orElse: () => otherParticipantIds.first,
          );
          otherParticipantId = householdId;
        } else if (otherParticipantIds.isNotEmpty) {
          otherParticipantId = otherParticipantIds.first;
        }

        // For group chats, always anchor to the junkshop participant for display
        if (conversation.isGroupChat) {
          final junkshopEntry = conversation.participantDetails.entries
              .where((e) => e.value.role == 'junkshop')
              .toList();
          if (junkshopEntry.isNotEmpty) {
            otherParticipantId = junkshopEntry.first.key;
          }
        }

        if (otherParticipantId.isEmpty) return const SizedBox.shrink();

        final otherParticipant =
            conversation.participantDetails[otherParticipantId];
        if (otherParticipant == null) return const SizedBox.shrink();

        // Build display name for group chats
        String displayName;
        if (conversation.isGroupChat) {
          displayName = conversation.groupName ?? 'Group Chat';
        } else if (otherParticipantIds.length > 1) {
          // Multiple participants - show both household and junkshop names
          final household = conversation.participantDetails.values.firstWhere(
            (p) => p.role == 'household',
            orElse: () => otherParticipant,
          );
          final junkshop = conversation.participantDetails.values.firstWhere(
            (p) => p.role == 'junkshop',
            orElse: () => otherParticipant,
          );
          displayName = '${household.name} + ${junkshop.name}';
        } else {
          displayName = otherParticipant.name;
        }

        // Role colors
        final Color roleColor = otherParticipant.role == 'household'
            ? const Color(0xFF3B82F6)
            : const Color(0xFF8B5CF6);

        final unreadCount = conversation.unreadCounts[_currentUserId] ?? 0;
        final isUpdating = _updatingConversations.contains(conversation.id);

        return InkWell(
          onTap: isUpdating
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  // Mark as read
                  if (unreadCount > 0) {
                    setState(() {
                      _updatingConversations.add(conversation.id);
                    });

                    try {
                      await _chatRepository.markConversationAsRead(
                        conversationId: conversation.id,
                        userId: _currentUserId,
                      );
                    } catch (_) {
                    } finally {
                      if (mounted) {
                        setState(() {
                          _updatingConversations.remove(conversation.id);
                        });
                      }
                    }
                  }

                  // Navigate to conversation
                  navigator.pushNamed(
                    '/collector/chat-detail',
                    arguments: {'conversation': conversation},
                  );
                },
          onLongPress: () => _showConversationOptions(conversation),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar - use junkshop avatar for group chats, stacked for multi-participant, single otherwise
                if (conversation.isGroupChat)
                  // Group chat - show junkshop profile image
                  Builder(
                    builder: (context) {
                      final junkshopParticipant = conversation
                          .participantDetails
                          .values
                          .firstWhere(
                            (p) => p.role == 'junkshop',
                            orElse: () => otherParticipant,
                          );
                      final hasImage =
                          junkshopParticipant.profileImage != null &&
                          !junkshopParticipant.profileImage!.startsWith(
                            'data:image',
                          );
                      return CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF8B5CF6),
                        backgroundImage: hasImage
                            ? AppImageProvider(
                                    junkshopParticipant.profileImage!,
                                  )
                                  as ImageProvider
                            : null,
                        child: !hasImage
                            ? Text(
                                junkshopParticipant.name
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      );
                    },
                  )
                else if (otherParticipantIds.length > 1)
                  // Non-group multi-participant - show stacked avatars
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: StackedAvatars(
                      avatars: otherParticipantIds.map((participantId) {
                        final participant =
                            conversation.participantDetails[participantId];
                        if (participant == null) {
                          return const AvatarData(
                            initials: '?',
                            backgroundColor: Colors.grey,
                          );
                        }
                        return AvatarData.fromParticipant(
                          name: participant.name,
                          profileImage: participant.profileImage,
                          role: participant.role,
                        );
                      }).toList(),
                      size: 52,
                      borderWidth: 2,
                      borderColor: Colors.white,
                      showOnlineStatus: false,
                    ),
                  )
                else
                  // Single chat - show regular avatar with active indicator
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: roleColor,
                        backgroundImage:
                            otherParticipant.profileImage != null &&
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
                                otherParticipant.profileImage!.startsWith(
                                  'data:image',
                                )
                            ? Text(
                                otherParticipant.name
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
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
                  ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(
                              conversation.lastMessageTimestamp ??
                                  DateTime.now(),
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: unreadCount > 0
                                  ? AppColors.successColor
                                  : const Color(0xFF9CA3AF),
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
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
                              style: TextStyle(
                                fontSize: 15,
                                color: unreadCount > 0
                                    ? const Color(0xFF374151)
                                    : const Color(0xFF9CA3AF),
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.successColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
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
      },
    );
  }

  void _showConversationOptions(ConversationModel conversation) {
    final String displayName;
    if (conversation.isGroupChat) {
      displayName = conversation.groupName ?? 'Group Chat';
    } else {
      final otherParticipant = conversation.getOtherParticipant(_currentUserId);
      if (otherParticipant == null) return;
      displayName = otherParticipant.name;
    }

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
              displayName,
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

            if (!conversation.isGroupChat)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
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
            backgroundColor: const Color(0xFF10B981),
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

  Future<void> _callParticipant(ConversationModel conversation) async {
    final otherParticipant = conversation.getOtherParticipant(_currentUserId);
    if (otherParticipant == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${otherParticipant.name}...'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _deleteConversation(ConversationModel conversation) {
    if (conversation.isGroupChat) return;
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
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await _chatRepository.softDeleteConversation(
                  conversationId: conversation.id,
                  userId: _currentUserId,
                );
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Conversation deleted'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error deleting conversation: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }
}
