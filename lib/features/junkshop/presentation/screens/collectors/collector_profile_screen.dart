import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/utils/phone_launcher.dart';
import '../../../../../../features/messaging/data/models/conversation_model.dart';
import '../../../../../../features/messaging/data/repositories/chat_repository.dart';
import '../messages/junkshop_chat_detail_screen.dart';
import 'collector_reviews_screen.dart';
import 'collector_collections_screen.dart';

class CollectorProfileScreen extends StatefulWidget {
  const CollectorProfileScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.status,
    this.avatarUrl,
    required this.rating,
    required this.totalCollections,
    required this.totalSold,
    required this.assignedTasks,
    this.todayCollections,
    this.totalItems,
    this.approvedAt,
    this.recentCollections,
    this.collectorId = '',
    this.vehicle,
  });

  final String name;
  final String phone;
  final String email;
  final String address;
  final String status;
  final String? avatarUrl;
  final double rating;
  final int totalCollections;
  final double totalSold;
  final int assignedTasks;
  final int? todayCollections;
  final int? totalItems;
  final DateTime? approvedAt;
  final List<Map<String, dynamic>>? recentCollections;
  final String collectorId;
  final Map<String, dynamic>? vehicle;

  @override
  State<CollectorProfileScreen> createState() => _CollectorProfileScreenState();
}

class _CollectorProfileScreenState extends State<CollectorProfileScreen> {
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
  }

  Future<void> _dismissCollector() async {
    if (widget.collectorId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: 10),
            const Text('Dismiss Collector'),
          ],
        ),
        content: Text(
          'Are you sure you want to dismiss ${widget.name}?\n\nThey will lose access to assignments and messaging until they reapply.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final junkshopUid = currentUid;

      await supabase
          .from('collectors')
          .update({
            'application_status': 'fired',
            'fired_at': DateTime.now().toUtc().toIso8601String(),
            'partner_junkshop_id': null,
          })
          .eq('id', widget.collectorId);

      // Kick from group chat and post EcoKuha Assistant message
      if (junkshopUid != null) {
        await _kickCollectorFromGroupChat(
          widget.collectorId,
          junkshopUid,
          widget.name,
        );

        // Log the dismissal to the junkshop's activity logs
        await supabase.from('activity_logs').insert({
          'junkshop_id': junkshopUid,
          'type': 'collector_dismissed',
          'title': 'Dismissed collector: ${widget.name}',
          'details': {
            'collectorId': widget.collectorId,
            'collectorName': widget.name,
          },
        });
      }

      if (!mounted) return;

      setState(() {
        _currentStatus = 'fired';
      });

      // Return true so CollectorsScreen knows to refresh
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss collector: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Removes the collector from the junkshop's group chat and posts a
  /// EcoKuha Assistant system message announcing the dismissal.
  Future<void> _kickCollectorFromGroupChat(
    String collectorUid,
    String junkshopId,
    String collectorName,
  ) async {
    try {
      final groupChats = await supabase
          .from('conversations')
          .select('id')
          .eq('is_group_chat', true)
          .eq('junkshop_id', junkshopId)
          .limit(1);

      if (groupChats.isEmpty) return;

      // Removes the collector from participants and posts the EcoKuha Assistant
      // announcement (also updates the conversation preview).
      await ChatRepository().removeParticipant(
        conversationId: groupChats.first['id'].toString(),
        userId: collectorUid,
        systemMessage: '$collectorName has been dismissed from the team.',
      );
    } catch (e) {
      debugPrint('Error kicking collector from group chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_currentStatus);
    final statusLabel = _getStatusLabel(_currentStatus);

    debugPrint('CollectorProfileScreen - approvedAt: ${widget.approvedAt}');
    debugPrint('CollectorProfileScreen - collectorId: ${widget.collectorId}');
    debugPrint(
      'CollectorProfileScreen - recentCollections: ${widget.recentCollections?.length ?? 'null'}',
    );
    if (widget.recentCollections != null &&
        widget.recentCollections!.isNotEmpty) {
      debugPrint(
        'CollectorProfileScreen - First collection: ${widget.recentCollections!.first}',
      );
      final first = widget.recentCollections!.first;
      debugPrint('  - items: ${first['items']}');
      debugPrint('  - itemCount: ${first['itemCount']}');
      debugPrint('  - price: ${first['price']}');
      debugPrint('  - weight: ${first['weight']}');
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            actions: [
              if (_currentStatus != 'fired')
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'dismiss') _dismissCollector();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'dismiss',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_remove_rounded,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Dismiss Collector',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Dismissed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreen.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (widget.avatarUrl != null &&
                                  widget.avatarUrl!.isNotEmpty) {
                                _showFullScreenAvatar(
                                  context,
                                  widget.avatarUrl!,
                                );
                              }
                            },
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child:
                                    (widget.avatarUrl != null &&
                                        widget.avatarUrl!.isNotEmpty &&
                                        (widget.avatarUrl!.startsWith(
                                              'http://',
                                            ) ||
                                            widget.avatarUrl!.startsWith(
                                              'https://',
                                            )))
                                    ? Image.network(
                                        widget.avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stack) {
                                          return const Center(
                                            child: Icon(
                                              Icons.person_rounded,
                                              color: AppColors.primaryGreen,
                                              size: 40,
                                            ),
                                          );
                                        },
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.person_rounded,
                                          color: AppColors.primaryGreen,
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          // Status indicator
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Name
                      Text(
                        widget.name,
                        style: AppTextStyles.h4.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _statCard(
                      icon: FluentIcons.star_24_filled,
                      label: 'Rating',
                      value: widget.rating.toStringAsFixed(1),
                      color: AppColors.warningColor,
                      onTap: () async {
                        // Get review count
                        final ratingRows = await supabase
                            .from('ratings')
                            .select('id')
                            .eq('target_type', 'collector')
                            .eq('target_id', widget.collectorId);
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CollectorReviewsScreen(
                              collectorId: widget.collectorId,
                              collectorName: widget.name,
                              averageRating: widget.rating,
                              totalReviews: ratingRows.length,
                            ),
                          ),
                        );
                      },
                    ),
                    _statCard(
                      icon: FluentIcons.checkmark_circle_24_filled,
                      label: 'Collections',
                      value: widget.totalCollections.toString(),
                      color: AppColors.successColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CollectorCollectionsScreen(
                              collectorId: widget.collectorId,
                              collectorName: widget.name,
                              collections: widget.recentCollections ?? [],
                            ),
                          ),
                        );
                      },
                    ),
                    _statCard(
                      icon: FluentIcons.box_24_filled,
                      label: 'Assigned',
                      value: widget.assignedTasks.toString(),
                      color: AppColors.primaryGreen,
                    ),
                    _statCard(
                      icon: FluentIcons.money_24_filled,
                      label: 'Total Collected Value',
                      value:
                          '₱${NumberFormat('#,##0.00').format(widget.totalSold)}',
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Contact Information
                _sectionCard(
                  title: 'Contact Information',
                  icon: FluentIcons.person_24_filled,
                  children: [
                    _infoRow(
                      icon: FluentIcons.call_24_regular,
                      label: 'Phone Number',
                      value: widget.phone,
                      onTap: () => _makeCall(widget.phone),
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      icon: FluentIcons.mail_24_regular,
                      label: 'Email Address',
                      value: widget.email,
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      icon: FluentIcons.location_24_regular,
                      label: 'Address',
                      value: widget.address,
                      maxLines: null,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Vehicle Information
                if (widget.vehicle != null)
                  _sectionCard(
                    title: 'Vehicle Information',
                    icon: FluentIcons.vehicle_car_24_filled,
                    children: [
                      _infoRow(
                        icon: FluentIcons.vehicle_truck_24_regular,
                        label: 'Vehicle Type',
                        value:
                            widget.vehicle!['type']?.toString() ??
                            'Not specified',
                      ),
                      const SizedBox(height: 12),
                      _infoRow(
                        icon: FluentIcons.box_24_regular,
                        label: 'Capacity',
                        value:
                            widget.vehicle!['capacity']?.toString() ??
                            'Not specified',
                      ),
                      if (widget.vehicle!['plate_number'] != null &&
                          widget.vehicle!['plate_number']
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _infoRow(
                          icon: FluentIcons.tag_24_regular,
                          label: 'Plate Number',
                          value: widget.vehicle!['plate_number'].toString(),
                        ),
                      ],
                    ],
                  ),

                if (widget.vehicle != null) const SizedBox(height: 16),

                // Approval Information
                _sectionCard(
                  title: 'Approval Information',
                  icon: FluentIcons.checkmark_circle_24_filled,
                  children: [
                    _infoRow(
                      icon: FluentIcons.calendar_checkmark_24_regular,
                      label: 'Approved On',
                      value: widget.approvedAt != null
                          ? _formatDate(widget.approvedAt!)
                          : 'Date not available',
                    ),
                    if (widget.approvedAt != null) ...[
                      const SizedBox(height: 12),
                      _infoRow(
                        icon: FluentIcons.timer_24_regular,
                        label: 'Days Active',
                        value:
                            '${DateTime.now().difference(widget.approvedAt!).inDays} days',
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Performance Metrics
                _sectionCard(
                  title: 'Performance Metrics',
                  icon: FluentIcons.chart_multiple_24_filled,
                  children: [
                    _metricRow(
                      label: 'Completion Rate',
                      value:
                          '${_calculateCompletionRate().toStringAsFixed(0)}%',
                      maxValue: 100,
                      currentValue: _calculateCompletionRate(),
                      color: AppColors.successColor,
                    ),
                    const SizedBox(height: 16),
                    _metricRow(
                      label: 'Average Rating',
                      value: widget.rating.toStringAsFixed(1),
                      maxValue: 5,
                      currentValue: widget.rating,
                      color: AppColors.warningColor,
                      suffix: '/ 5',
                    ),
                    const SizedBox(height: 16),
                    _metricRow(
                      label: 'Total Collections',
                      value: widget.totalCollections.toString(),
                      maxValue: 100,
                      currentValue: widget.totalCollections.toDouble(),
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),

      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _makeCall(widget.phone),
                  icon: const Icon(FluentIcons.call_24_regular),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openCollectorChat,
                  icon: const Icon(FluentIcons.chat_24_regular),
                  label: const Text('Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Methods

  /// Opens an existing direct conversation with the collector, or creates one if none exists.
  Future<void> _openCollectorChat() async {
    final junkshopUid = currentUid;
    if (junkshopUid == null || widget.collectorId.isEmpty) return;

    final chatRepo = ChatRepository();

    // Deterministic ID: sort UIDs so the same conversation is found regardless of who initiates
    final ids = [junkshopUid, widget.collectorId]..sort();
    final conversationId = 'direct_${ids[0]}_${ids[1]}';

    // Try to load an existing conversation directly by ID
    ConversationModel? conversation;
    final existingRow = await supabase
        .from('conversations')
        .select()
        .eq('id', conversationId)
        .maybeSingle();
    if (existingRow != null) {
      conversation = ConversationModel.fromMap(existingRow);
    }

    if (conversation == null) {
      // Fetch junkshop profile for participant details
      final junkshopData =
          await supabase
              .from('junkshops')
              .select('business_name, full_name, profile_image_url')
              .eq('id', junkshopUid)
              .maybeSingle() ??
          <String, dynamic>{};
      final junkshopName =
          ((junkshopData['business_name'] as String?)?.isNotEmpty == true
                  ? junkshopData['business_name'] as String
                  : junkshopData['full_name'] as String?) ??
              'Junkshop';
      final junkshopAvatar = junkshopData['profile_image_url'] as String?;

      final participantDetails = {
        junkshopUid: ParticipantDetails(
          name: junkshopName,
          role: 'junkshop',
          profileImage: junkshopAvatar,
          joinedAt: DateTime.now(),
        ),
        widget.collectorId: ParticipantDetails(
          name: widget.name,
          role: 'collector',
          profileImage: widget.avatarUrl,
          joinedAt: DateTime.now(),
        ),
      };

      await chatRepo.createConversation(
        postingId: conversationId,
        participants: [junkshopUid, widget.collectorId],
        participantDetails: participantDetails,
      );

      final createdRow = await supabase
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .maybeSingle();
      if (createdRow != null) {
        conversation = ConversationModel.fromMap(createdRow);
      }
    }

    if (conversation == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            JunkshopChatDetailScreen(conversation: conversation!),
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      await PhoneLauncher.makePhoneCall(phoneNumber);
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  double _calculateCompletionRate() {
    if (widget.totalCollections == 0) return 0.0;
    return ((widget.totalCollections /
                (widget.totalCollections + widget.assignedTasks)) *
            100)
        .clamp(0, 100);
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return 'Online';
      case 'offline':
        return 'Offline';
      case 'active':
        return 'Active';
      case 'busy':
        return 'On Route';
      case 'approved':
        return 'Approved';
      case 'fired':
        return 'Dismissed';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return AppColors.success;
      case 'offline':
        return Colors.grey;
      case 'active':
        return AppColors.successColor;
      case 'busy':
        return AppColors.warningColor;
      case 'approved':
        return AppColors.successColor;
      case 'fired':
        return Colors.red.shade400;
      default:
        return Colors.grey;
    }
  }

  // Widget Builders
  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    final child = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (onTap != null)
                Icon(
                  FluentIcons.chevron_right_24_regular,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.h5.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: child,
      );
    }
    return child;
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primaryGreen),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    int? maxLines = 1,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: maxLines,
                    overflow: maxLines != null ? TextOverflow.ellipsis : null,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow({
    required String label,
    required String value,
    required double maxValue,
    required double currentValue,
    required Color color,
    String? suffix,
  }) {
    final percentage = (currentValue / maxValue).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              suffix != null ? '$value $suffix' : value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppColors.backgroundLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  void _showFullScreenAvatar(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 80,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(24),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
