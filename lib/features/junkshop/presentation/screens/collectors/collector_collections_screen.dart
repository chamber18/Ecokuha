import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';

class CollectorCollectionsScreen extends StatelessWidget {
  final String collectorId;
  final String collectorName;
  final List<Map<String, dynamic>> collections;

  const CollectorCollectionsScreen({
    super.key,
    required this.collectorId,
    required this.collectorName,
    required this.collections,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('=== CollectorCollectionsScreen Build ===');
    debugPrint('Collections count: ${collections.length}');
    if (collections.isNotEmpty) {
      debugPrint('First collection: ${collections.first}');
      debugPrint('Date type: ${collections.first['date'].runtimeType}');
      debugPrint('Items type: ${collections.first['items'].runtimeType}');
    }
    debugPrint('========================================');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Collections',
              style: AppTextStyles.h5.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              collectorName,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
      body: collections.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.history_24_regular,
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No collections found',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: collections.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final collection = collections[index];

                // Handle date conversion safely
                DateTime? dateTime;
                final dateValue = collection['date'];
                if (dateValue is DateTime) {
                  dateTime = dateValue;
                } else if (dateValue is Timestamp) {
                  dateTime = dateValue.toDate();
                } else if (dateValue is int) {
                  dateTime = DateTime.fromMillisecondsSinceEpoch(dateValue);
                }

                return _collectionHistoryItem(
                  context: context,
                  date: _formatDate(dateTime ?? DateTime.now()),
                  items: collection['items'] as String? ?? 'Items',
                  itemCount: collection['itemCount'] as int? ?? 0,
                  weight: (collection['weight'] as num?)?.toDouble() ?? 0.0,
                  price: (collection['price'] as num?)?.toDouble() ?? 0.0,
                  status: collection['status'] as String? ?? 'Completed',
                  onTap: () => _navigateToHistory(context, collection),
                );
              },
            ),
    );
  }

  Widget _collectionHistoryItem({
    required BuildContext context,
    required String date,
    required String items,
    required int itemCount,
    required double weight,
    required double price,
    required String status,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    FluentIcons.checkmark_circle_24_filled,
                    color: AppColors.successColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _collectionInfoChip(
                    icon: FluentIcons.box_24_regular,
                    label: '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _collectionInfoChip(
                    icon: FluentIcons.money_24_regular,
                    label: '₱${NumberFormat('#,##0.00').format(price)}',
                    color: AppColors.warningColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _collectionInfoChip(
                    icon: FluentIcons.cube_24_regular,
                    label: '${weight.toStringAsFixed(1)} kg',
                    color: AppColors.infoColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectionInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToHistory(
    BuildContext context,
    Map<String, dynamic> collection,
  ) async {
    debugPrint('=== Showing Collection Details ===');
    debugPrint('Collection data: $collection');
    debugPrint('Posting ID: ${collection['postingId']}');

    final postingId = collection['postingId'] as String?;

    if (postingId == null || postingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection details not available')),
      );
      return;
    }

    // Fetch full posting data and show the existing pickups screen modal
    try {
      Map<String, dynamic>? fullPostingData;

      final row = await supabase
          .from('postings')
          .select()
          .eq('id', postingId)
          .maybeSingle();

      if (row != null) {
        fullPostingData = rowToDoc('postings', row);
        fullPostingData['id'] = row['id'];
        fullPostingData['householdId'] = row['household_id'];
      }

      if (!context.mounted) return;

      if (fullPostingData != null) {
        debugPrint('Found posting data, showing details modal');
        _showCollectionDetailsSheet(context, collection);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load collection details')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching collection details: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  void _showCollectionDetailsSheet(
    BuildContext context,
    Map<String, dynamic> collection,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.box_checkmark_24_filled,
                      color: AppColors.primaryGreen,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Collection Details',
                            style: AppTextStyles.h5.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatDate(collection['date'] as DateTime),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Items Section
                    _detailSection(
                      'Items Collected',
                      FluentIcons.box_24_regular,
                      [
                        _detailRow(
                          'Materials',
                          collection['items'] as String? ?? 'N/A',
                        ),
                        _detailRow(
                          'Quantity',
                          '${collection['itemCount'] ?? 0} items',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Weight & Price Section
                    _detailSection(
                      'Purchase Summary',
                      FluentIcons.money_24_regular,
                      [
                        _detailRow(
                          'Total Weight',
                          '${(collection['weight'] as double?)?.toStringAsFixed(1) ?? '0.0'} kg',
                        ),
                        _detailRow(
                          'Total Price',
                          '₱${NumberFormat('#,##0.00').format((collection['price'] as double?) ?? 0.0)}',
                          valueColor: AppColors.primaryGreen,
                          valueStyle: AppTextStyles.h6.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Status Section
                    _detailSection(
                      'Status',
                      FluentIcons.checkmark_circle_24_regular,
                      [
                        _detailRow(
                          'Collection Status',
                          (collection['status'] as String? ?? 'Completed')
                              .toUpperCase(),
                          valueColor: AppColors.successColor,
                        ),
                        _detailRow(
                          'Posting ID',
                          collection['postingId'] as String? ?? 'N/A',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              maxLines: null,
              style:
                  valueStyle ??
                  AppTextStyles.bodyMedium.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
