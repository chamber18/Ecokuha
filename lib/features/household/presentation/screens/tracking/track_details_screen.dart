import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/utils/phone_launcher.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import 'live_tracking_screen.dart';

class TrackDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const TrackDetailsScreen({super.key, required this.order});

  @override
  State<TrackDetailsScreen> createState() => _TrackDetailsScreenState();
}

class _TrackDetailsScreenState extends State<TrackDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.order['status'] == 'in_progress') {
      _pulseController.repeat(reverse: true);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_progress':
        return AppColors.primaryBlue;
      case 'scheduled':
        return AppColors.primaryGreen;
      case 'completed':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'in_progress':
        return Icons.local_shipping;
      case 'scheduled':
        return Icons.schedule;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Status Card
                  _buildStatusCard(),

                  // Timeline
                  _buildTimeline(),

                  // Order Details
                  _buildOrderDetails(),

                  // Collector Info
                  _buildCollectorInfo(),

                  // Items List
                  _buildItemsList(),

                  // Address Info
                  _buildAddressInfo(),

                  const SizedBox(height: AppDimensions.spacing24),
                ],
              ),
            ),
          ),

          // Bottom Actions
          if (widget.order['status'] != 'completed') _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(widget.order['status']),
            _getStatusColor(widget.order['status']).withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios),
              color: AppColors.textWhite,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    widget.order['id'],
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.order['statusLabel'],
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _shareOrder(),
              icon: const Icon(Icons.share),
              color: AppColors.textWhite,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: _getStatusColor(widget.order['status']).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(widget.order['status']).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status Icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.order['status'] == 'in_progress'
                    ? _pulseAnimation.value
                    : 1.0,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      widget.order['status'],
                    ).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(widget.order['status']),
                    size: 40,
                    color: _getStatusColor(widget.order['status']),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: AppDimensions.spacing16),

          Text(
            widget.order['statusLabel'],
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.w700,
              color: _getStatusColor(widget.order['status']),
            ),
          ),

          const SizedBox(height: AppDimensions.spacing8),

          if (widget.order['progress'] != null) ...[
            Text(
              '${(widget.order['progress'] * 100).toInt()}% Complete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            LinearProgressIndicator(
              value: widget.order['progress'],
              backgroundColor: AppColors.backgroundDark,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getStatusColor(widget.order['status']),
              ),
            ),
          ],

          if (widget.order['status'] == 'completed') ...[
            Text(
              'Collection completed successfully!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              _getTimeAgo(widget.order['completedDate']),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final timeline = widget.order['timeline'] as List<Map<String, dynamic>>?;

    if (timeline == null || timeline.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          ...List.generate(timeline.length, (index) {
            final step = timeline[index];
            final isCompleted = step['completed'] as bool;
            final isLast = index == timeline.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline Indicator
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.primaryGreen
                            : AppColors.borderLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted
                              ? AppColors.primaryGreen
                              : AppColors.borderLight,
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: AppColors.borderLight,
                      ),
                  ],
                ),

                const SizedBox(width: AppDimensions.spacing12),

                // Timeline Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['status'],
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step['time'],
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Details',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          _buildDetailRow('Order ID', widget.order['id']),
          _buildDetailRow('Status', widget.order['statusLabel']),

          if (widget.order['scheduledDate'] != null)
            _buildDetailRow(
              'Scheduled Date',
              _formatDate(widget.order['scheduledDate']),
            ),

          if (widget.order['completedDate'] != null)
            _buildDetailRow(
              'Completed Date',
              _formatDate(widget.order['completedDate']),
            ),

          if (widget.order['estimatedValue'] != null)
            _buildDetailRow(
              'Estimated Value',
              '₱${widget.order['estimatedValue'].toStringAsFixed(2)}',
            ),

          if (widget.order['finalValue'] != null)
            _buildDetailRow(
              'Final Value',
              '₱${widget.order['finalValue'].toStringAsFixed(2)}',
              valueColor: AppColors.primaryGreen,
            ),

          if (widget.order['rating'] != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rating',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 16,
                      color: index < widget.order['rating']
                          ? AppColors.primaryBlue
                          : AppColors.borderLight,
                    );
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCollectorInfo() {
    if (widget.order['collectorName'] == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collector Information',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.2),
                child: Text(
                  widget.order['collectorName'][0],
                  style: AppTextStyles.h6.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),

              const SizedBox(width: AppDimensions.spacing16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.order['collectorName'],
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Waste Collector',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.order['collectorPhone'] != null)
                IconButton(
                  onPressed: () =>
                      _callCollector(widget.order['collectorPhone']),
                  icon: const Icon(Icons.phone, color: AppColors.primaryGreen),
                ),

              IconButton(
                onPressed: () => _messageCollector(),
                icon: const Icon(Icons.message, color: AppColors.primaryBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    final items = widget.order['items'] as List<dynamic>;

    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items for Collection',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          ...items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppDimensions.spacing8),
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    _getItemIcon(item),
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Text(
                    item,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAddressInfo() {
    if (widget.order['address'] == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection Address',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Text(
                  widget.order['address'],
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              IconButton(
                onPressed: () => _openInMaps(),
                icon: const Icon(
                  Icons.open_in_new,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final bool isInProgress = widget.order['status'] == 'in_progress';

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track Live button (only show when in_progress)
          if (isInProgress)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
              child: CustomButton(
                onPressed: _openLiveTracking,
                text: 'Track Live',
                backgroundColor: AppColors.primaryGreen,
                textColor: Colors.white,
                icon: const Icon(Icons.near_me, color: Colors.white),
              ),
            ),

          // Existing action buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: () => _cancelOrder(),
                  text: 'Cancel Order',
                  backgroundColor: AppColors.errorColor,
                  textColor: Colors.white,
                  icon: const Icon(Icons.cancel, color: Colors.white),
                ),
              ),

              const SizedBox(width: AppDimensions.spacing12),

              Expanded(
                child: CustomButton(
                  onPressed: () =>
                      _callCollector(widget.order['collectorPhone']),
                  text: 'Call Collector',
                  backgroundColor: AppColors.primaryGreen,
                  textColor: Colors.white,
                  icon: const Icon(Icons.phone, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getItemIcon(String item) {
    final itemLower = item.toLowerCase();
    if (itemLower.contains('plastic')) {
      return Icons.recycling;
    } else if (itemLower.contains('paper') || itemLower.contains('cardboard')) {
      return Icons.article;
    } else if (itemLower.contains('glass')) {
      return Icons.wine_bar;
    } else if (itemLower.contains('metal') || itemLower.contains('aluminum')) {
      return Icons.build;
    } else {
      return Icons.inventory;
    }
  }

  String _formatDate(DateTime date) {
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

    return '${date.day} ${months[date.month - 1]} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
  }

  void _shareOrder() {
    // Implement share functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share Order'),
        content: Text('Share order details with someone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement actual sharing
            },
            child: Text('Share'),
          ),
        ],
      ),
    );
  }

  void _callCollector(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
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

  void _openLiveTracking() {
    // Navigate to live tracking screen
    final postingId = widget.order['id'];
    final collectorName = widget.order['collectorName'] ?? 'Collector';

    if (postingId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveTrackingScreen(
            postingId: postingId,
            collectorName: collectorName,
          ),
        ),
      );
    }
  }

  void _messageCollector() {
    // Navigate to messaging screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message Collector'),
        content: Text('This feature will open a chat with your collector.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement messaging
            },
            child: Text('Open Chat'),
          ),
        ],
      ),
    );
  }

  void _openInMaps() {
    // Open address in maps
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open in Maps'),
        content: Text(
          'This will open the collection address in your maps app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement maps opening
            },
            child: Text('Open Maps'),
          ),
        ],
      ),
    );
  }

  void _cancelOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Order'),
        content: Text(
          'Are you sure you want to cancel this collection request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to tracking screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Order ${widget.order['id']} has been cancelled',
                  ),
                  backgroundColor: AppColors.errorColor,
                ),
              );
            },
            child: Text('Cancel Order'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}
