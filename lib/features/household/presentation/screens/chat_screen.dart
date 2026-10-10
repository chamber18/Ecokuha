import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../core/utils/app_image_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/constants/firestore_fields/index.dart';
import '../../../../../shared/widgets/common/stacked_avatars.dart';
import '../../../messaging/data/repositories/chat_repository.dart';
import '../../../messaging/data/models/conversation_model.dart';
import '../../../messaging/data/models/message_model.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatRepository _chatRepository = ChatRepository();
  final String _currentUserId = currentUid ?? '';
  final Set<String> _updatingConversations =
      {}; // Track conversations being updated
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Cached active-today status for other participants (userId → isActiveToday)
  final Map<String, bool> _participantActiveStatus = {};
  final Set<String> _fetchedParticipantIds = {};

  /// Fetch last_login_at for participants not yet checked. Results cached so
  /// only one Firestore read per unique user is made per screen session.
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
        backgroundColor: AppColors.backgroundDark,
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
                      color: AppColors.textLight,
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
                  child: CustomScrollView(
                    slivers: [
                      // Conversations list
                      _buildConversationsSliverList(allConversations),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
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
                  'Select a junkshop to start chatting',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(height: 16),
              // List of junkshops
              Flexible(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: supabase
                      .from('junkshops')
                      .stream(primaryKey: ['id'])
                      .map((rows) => rowsToDocs('junkshops', rows)),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Error loading junkshops: ${snapshot.error}',
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

                    final junkshops = snapshot.data!;

                    if (junkshops.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.store_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No junkshops available',
                                style: TextStyle(
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
                      itemCount: junkshops.length,
                      itemBuilder: (context, index) {
                        final junkshop = junkshops[index];
                        final junkshopId = junkshop['id'].toString();

                        // Try to get name from nested structure
                        final junkshopProfile =
                            junkshop['junkshop_profile']
                                as Map<String, dynamic>?;
                        final business =
                            junkshopProfile?['business']
                                as Map<String, dynamic>?;
                        final contact =
                            junkshopProfile?['contact']
                                as Map<String, dynamic>?;

                        final name =
                            business?['business_name'] ??
                            junkshop['business_name'] ??
                            junkshop['businessName'] ??
                            junkshop['full_name'] ??
                            junkshop['name'] ??
                            'Unknown Junkshop';

                        // Try multiple possible locations for profile image
                        var profileImage =
                            junkshop['profile_image_url'] ??
                            junkshop['profileImage'] ??
                            junkshop['profile_image'] ??
                            junkshop['photoURL'] ??
                            business?['profile_image'] ??
                            contact?['profile_image'];

                        // Check if it's a base64 image (starts with "data:image")
                        // If so, we can't use NetworkImage, skip it
                        if (profileImage != null &&
                            profileImage.toString().startsWith('data:image')) {
                          if (kDebugMode) {
                            print(
                              '⚠️ Base64 image detected for $name - skipping (re-upload needed)',
                            );
                          }
                          profileImage =
                              null; // NetworkImage can't handle base64
                        } else if (profileImage != null) {
                          if (kDebugMode) {
                            print(
                              '✅ Valid profile image URL found: ${profileImage.toString().substring(0, profileImage.toString().length > 50 ? 50 : profileImage.toString().length)}...',
                            );
                          }
                        } else {
                          if (kDebugMode) {
                            print(
                              'ℹ️ No profile image for $name - will show initials',
                            );
                          }
                        }

                        if (kDebugMode) print('Extracted name: $name');
                        if (kDebugMode) print('===================');

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primaryBlue,
                            backgroundImage: profileImage != null
                                ? AppImageProvider(profileImage)
                                      as ImageProvider
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
                            child: profileImage == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name.substring(0, 1).toUpperCase()
                                        : 'J',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
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
                          subtitle: const Text(
                            'Junkshop',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          trailing: Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.successColor,
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            await _createOrOpenChat(
                              junkshopId,
                              name,
                              profileImage,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createOrOpenChat(
    String junkshopId,
    String junkshopName,
    String? junkshopProfileImage,
  ) async {
    try {
      // Define the direct conversation ID
      final directConversationId = 'direct_${_currentUserId}_$junkshopId';

      // Check if this specific direct conversation already exists
      final existingConversationDoc = await supabase
          .from('conversations')
          .select()
          .eq('id', directConversationId)
          .maybeSingle();

      if (existingConversationDoc != null) {
        // Open existing direct conversation
        final conversation = ConversationModel.fromMap(
          existingConversationDoc,
        );

        if (kDebugMode) print('📝 Opening existing conversation:');
        if (kDebugMode) {
          print(
            '   Junkshop profile image in conversation: ${conversation.participantDetails[junkshopId]?.profileImage}',
          );
        }

        // Fetch latest junkshop profile image from Firestore
        final junkshopRow = await supabase
            .from('junkshops')
            .select()
            .eq('id', junkshopId)
            .maybeSingle();

        if (junkshopRow != null) {
          final junkshopData = rowToDoc('junkshops', junkshopRow);
          final latestProfileImage =
              junkshopData[UserFields.profileImageUrl] ??
              junkshopData['profileImage'] ??
              junkshopData['profile_image'];

          if (kDebugMode) {
            print(
              '   Latest profile image from Firestore: $latestProfileImage',
            );
          }

          // Update conversation if profile image has changed
          if (latestProfileImage != null &&
              latestProfileImage !=
                  conversation.participantDetails[junkshopId]?.profileImage &&
              !latestProfileImage.toString().startsWith('data:image')) {
            if (kDebugMode) {
              print('   ✅ Updating conversation with new profile image');
            }

            final details = Map<String, dynamic>.from(
              existingConversationDoc['participant_details'] as Map? ?? {},
            );
            final junkshopDetails = Map<String, dynamic>.from(
              details[junkshopId] as Map? ?? {},
            );
            junkshopDetails['profileImage'] = latestProfileImage;
            details[junkshopId] = junkshopDetails;

            await supabase
                .from('conversations')
                .update({'participant_details': details})
                .eq('id', directConversationId);

            // Refresh conversation data
            final updatedConversationDoc = await supabase
                .from('conversations')
                .select()
                .eq('id', directConversationId)
                .single();

            final updatedConversation = ConversationModel.fromMap(
              updatedConversationDoc,
            );

            if (mounted) {
              Navigator.pushNamed(
                context,
                '/household/conversation',
                arguments: {'conversation': updatedConversation},
              );
            }
            return;
          }
        }

        if (mounted) {
          Navigator.pushNamed(
            context,
            '/household/conversation',
            arguments: {'conversation': conversation},
          );
        }
      } else {
        if (kDebugMode) print('📝 Creating new conversation with:');
        if (kDebugMode) print('   Junkshop ID: $junkshopId');
        if (kDebugMode) print('   Junkshop name: $junkshopName');
        if (kDebugMode) {
          print('   Junkshop profile image: $junkshopProfileImage');
        }

        // Create new direct conversation
        final currentUserRow = await supabase
            .from('households')
            .select()
            .eq('id', _currentUserId)
            .maybeSingle();

        final currentUserData = currentUserRow == null
            ? null
            : rowToDoc('households', currentUserRow);
        final householdName =
            currentUserData?['name'] ??
            currentUserData?['full_name'] ??
            currentUserData?['fullName'] ??
            'Household';
        final householdProfileImage =
            currentUserData?['profileImage'] ??
            currentUserData?['profile_image'];

        // Create conversation with junkshop (no posting involved)
        final conversationId = await _chatRepository.createConversation(
          postingId:
              directConversationId, // This is now just the conversation ID
          participants: [_currentUserId, junkshopId],
          participantDetails: {
            _currentUserId: ParticipantDetails(
              name: householdName,
              role: 'household',
              profileImage: householdProfileImage,
              joinedAt: DateTime.now(),
            ),
            junkshopId: ParticipantDetails(
              name: junkshopName,
              role: 'junkshop',
              profileImage: junkshopProfileImage,
              joinedAt: DateTime.now(),
            ),
          },
          initialMessage: 'Chat started with $junkshopName',
        );

        // Fetch the created conversation
        final conversationDoc = await supabase
            .from('conversations')
            .select()
            .eq('id', conversationId)
            .maybeSingle();

        if (conversationDoc != null && mounted) {
          final conversation = ConversationModel.fromMap(conversationDoc);
          Navigator.pushNamed(
            context,
            '/household/conversation',
            arguments: {'conversation': conversation},
          );
        }
      }
    } catch (e) {
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

  Widget _buildConversationsSliverList(List<ConversationModel> conversations) {
    if (conversations.isEmpty) {
      return SliverFillRemaining(
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
                'Start a pickup request to begin chatting',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final actualIndex = index ~/ 2; // Account for separators

          if (index.isOdd) {
            // Separator
            return const Divider(
              height: 1,
              thickness: 0.6,
              indent: 64,
              color: AppColors.borderLight,
            );
          }

          // Conversation tile
          final conversation = conversations[actualIndex];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _buildConversationTile(conversation),
          );
        },
        childCount: conversations.length * 2 - 1, // Items + separators
      ),
    );
  }

  Widget _buildConversationTile(ConversationModel conversation) {
    final unreadCount = conversation.getUnreadCount(_currentUserId);
    final hasUnread = unreadCount > 0;

    final otherParticipant = conversation.getOtherParticipant(_currentUserId);
    if (otherParticipant == null) return const SizedBox.shrink();

    // Get all non-household participants for avatar display
    final nonHouseholdParticipants = conversation.participants
        .where((participantId) => participantId != _currentUserId)
        .map((participantId) => conversation.participantDetails[participantId])
        .where((details) => details != null)
        .cast<ParticipantDetails>()
        .toList();

    // Build avatar data list for stacked display
    final avatarDataList = nonHouseholdParticipants.map((participant) {
      return AvatarData.fromParticipant(
        name: participant.name,
        profileImage: participant.profileImage,
        role: participant.role,
      );
    }).toList();

    // Get display name - show both names if multiple participants
    String displayName;
    if (nonHouseholdParticipants.length > 1) {
      // Find junkshop and collector
      final junkshop = nonHouseholdParticipants.firstWhere(
        (p) => p.role == 'junkshop',
        orElse: () => nonHouseholdParticipants.first,
      );
      final collector = nonHouseholdParticipants.firstWhere(
        (p) => p.role == 'collector',
        orElse: () => nonHouseholdParticipants.last,
      );
      displayName = '${junkshop.name}, ${collector.name}';
    } else {
      displayName = otherParticipant.name;
    }

    final isCollector = otherParticipant.role == 'collector';

    // Debug: Check what profile image data we have
    if (kDebugMode) {
      print(
        '🔍 [${DateTime.now().millisecondsSinceEpoch}] Conversation tile building:',
      );
    }
    if (kDebugMode) print('   Conversation ID: ${conversation.id}');
    if (kDebugMode) {
      print('   Total participants: ${conversation.participants.length}');
    }
    if (kDebugMode) {
      print(
        '   Non-household participants: ${nonHouseholdParticipants.length}',
      );
    }
    for (var participant in nonHouseholdParticipants) {
      if (kDebugMode) {
        print(
          '   - ${participant.name} (${participant.role}): ${participant.profileImage != null ? "has image" : "no image"}',
        );
      }
    }

    // Check if we need to update junkshop profile image
    for (var participant in nonHouseholdParticipants) {
      if (participant.role == 'junkshop' &&
          participant.profileImage == null &&
          !_updatingConversations.contains(conversation.id)) {
        if (kDebugMode) {
          print('   ℹ️ Triggering junkshop profile update');
        }
        _updateJunkshopProfileImageInBackground(conversation);
        break;
      }
    }

    return InkWell(
      onTap: () => _openConversation(conversation),
      onLongPress: () => _showConversationOptions(conversation),
      child: Container(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            // Use stacked avatars if multiple participants, single avatar otherwise
            Stack(
              children: [
                avatarDataList.isNotEmpty
                    ? StackedAvatars(
                        avatars: avatarDataList,
                        size: 56,
                        borderWidth: 2,
                        borderColor: Colors.white,
                        showOnlineStatus: false,
                      )
                    : CircleAvatar(
                        radius: 28,
                        backgroundColor: isCollector
                            ? AppColors.successColor
                            : AppColors.primaryBlue,
                        child: Text(
                          otherParticipant.name.isNotEmpty
                              ? otherParticipant.name
                                    .substring(0, 2)
                                    .toUpperCase()
                              : '??',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                // Active indicator — shown only if the other participant
                // logged in today (checked once per session, no repeated reads)
                if (avatarDataList.length <= 1)
                  Builder(
                    builder: (context) {
                      final otherParticipantId = conversation.participants
                          .firstWhere(
                            (id) => id != _currentUserId,
                            orElse: () => '',
                          );
                      final isActive =
                          _participantActiveStatus[otherParticipantId] ?? false;
                      if (!isActive) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.successColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      );
                    },
                  ),
              ],
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
                        _formatTimestamp(conversation.lastMessageTimestamp),
                        style: TextStyle(
                          color: hasUnread
                              ? AppColors.successColor
                              : AppColors.textLight,
                          fontSize: 12,
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
                            fontSize: 14,
                            color: hasUnread
                                ? AppColors.textSecondary
                                : AppColors.textSecondary,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
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

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';

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

  Future<void> _updateJunkshopProfileImageInBackground(
    ConversationModel conversation,
  ) async {
    // Prevent duplicate updates for the same conversation
    if (_updatingConversations.contains(conversation.id)) {
      if (kDebugMode) {
        print('   ⏭️ Already updating this conversation, skipping...');
      }
      return;
    }

    _updatingConversations.add(conversation.id);

    // Get the junkshop participant
    final junkshopParticipant = conversation.participantDetails.values
        .firstWhere((p) => p.role == 'junkshop');

    // Find the junkshop ID from participants
    final junkshopId = conversation.participantDetails.entries
        .firstWhere((entry) => entry.value.role == 'junkshop')
        .key;

    try {
      if (kDebugMode) {
        print(
          '🔄 Fetching latest junkshop profile image for: ${junkshopParticipant.name}',
        );
      }

      // Fetch latest junkshop data from Firestore
      final junkshopRow = await supabase
          .from('junkshops')
          .select()
          .eq('id', junkshopId)
          .maybeSingle();

      if (junkshopRow != null) {
        final junkshopData = rowToDoc('junkshops', junkshopRow);
        final latestProfileImage =
            junkshopData[UserFields.profileImageUrl] ??
            junkshopData['profileImage'] ??
            junkshopData['profile_image'];

        if (kDebugMode) {
          print('   Latest profile image from Firestore: $latestProfileImage');
        }

        // Update if we found a valid image URL
        if (latestProfileImage != null &&
            !latestProfileImage.toString().startsWith('data:image') &&
            latestProfileImage.toString().startsWith('http')) {
          if (kDebugMode) {
            print('   ✅ Updating conversation with profile image');
          }
          if (kDebugMode) {
            print(
              '   Update path: participant_details.$junkshopId.profileImage',
            );
          }

          final convRow = await supabase
              .from('conversations')
              .select('participant_details')
              .eq('id', conversation.id)
              .maybeSingle();
          if (convRow != null) {
            final details = Map<String, dynamic>.from(
              convRow['participant_details'] as Map? ?? {},
            );
            final junkshopDetails = Map<String, dynamic>.from(
              details[junkshopId] as Map? ?? {},
            );
            junkshopDetails[ConversationFields.participantProfileImage] =
                latestProfileImage;
            details[junkshopId] = junkshopDetails;

            await supabase
                .from('conversations')
                .update({'participant_details': details})
                .eq('id', conversation.id);

            if (kDebugMode) {
              print('   🎉 Profile image updated successfully!');
            }
          }
        } else {
          if (kDebugMode) {
            print('   ⚠️ No valid profile image found in Firestore');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('   ❌ Error updating junkshop profile image: $e');
    } finally {
      // Keep in set for a moment to prevent StreamBuilder rebuild spam
      // Then remove to allow future updates if needed
      await Future.delayed(const Duration(milliseconds: 500));
      _updatingConversations.remove(conversation.id);
    }
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
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _chatRepository.softDeleteConversation(
                  conversationId: conversation.id,
                  userId: _currentUserId,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Conversation deleted'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting conversation: $e'),
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

  void _openConversation(ConversationModel conversation) async {
    await _chatRepository.markConversationAsRead(
      conversationId: conversation.id,
      userId: _currentUserId,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(conversation: conversation),
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ConversationScreen({super.key, required this.conversation});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _chatRepository = ChatRepository();
  final String _currentUserId = currentUid ?? '';
  String _currentUserName = '';
  String _currentUserRole = 'household';
  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
    _markAsRead();
  }

  void _loadCurrentUserInfo() {
    final participant = widget.conversation.participantDetails[_currentUserId];
    if (participant != null) {
      _currentUserName = participant.name;
      _currentUserRole = participant.role;
    }
  }

  void _markAsRead() {
    _chatRepository.markConversationAsRead(
      conversationId: widget.conversation.id,
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
    // Get posting ID for display
    final postingId = widget.conversation.postingId.replaceAll('posting_', '');

    // Get all non-household participants for display
    final nonHouseholdParticipants = widget.conversation.participants
        .where((participantId) => participantId != _currentUserId)
        .map(
          (participantId) =>
              widget.conversation.participantDetails[participantId],
        )
        .where((details) => details != null)
        .cast<ParticipantDetails>()
        .toList();

    // Build avatar data list for header
    final avatarDataList = nonHouseholdParticipants.map((participant) {
      return AvatarData.fromParticipant(
        name: participant.name,
        profileImage: participant.profileImage,
        role: participant.role,
      );
    }).toList();

    // Get display name - show both names if multiple participants
    String displayName;
    String subtitle;
    if (nonHouseholdParticipants.length > 1) {
      // Find junkshop and collector
      final junkshop = nonHouseholdParticipants.firstWhere(
        (p) => p.role == 'junkshop',
        orElse: () => nonHouseholdParticipants.first,
      );
      final collector = nonHouseholdParticipants.firstWhere(
        (p) => p.role == 'collector',
        orElse: () => nonHouseholdParticipants.last,
      );
      displayName = junkshop.name;
      subtitle = 'with ${collector.name} (Collector)';
    } else if (nonHouseholdParticipants.isNotEmpty) {
      displayName = nonHouseholdParticipants.first.name;
      subtitle = nonHouseholdParticipants.first.role == 'junkshop'
          ? 'Junkshop'
          : nonHouseholdParticipants.first.role == 'collector'
          ? 'Collector'
          : 'Posting #$postingId';
    } else {
      displayName = 'Conversation';
      subtitle = 'Posting #$postingId';
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
              stream: _chatRepository.getMessagesStream(widget.conversation.id),
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
                    widget.conversation.createdAt ?? DateTime.now();
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
          // Changed back to Flexible like regular messages
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
                // Message bubble - EXACT same structure as regular messages
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
                        color: AppColors.textPrimary,
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
                ...widget.conversation.participantDetails.entries.map((entry) {
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
        return AppColors.primaryBlue;
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
        widget.conversation.participantDetails[message.senderId];
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
        conversationId: widget.conversation.id,
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
