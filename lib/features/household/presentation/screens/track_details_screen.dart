import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class TrackDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> collection;

  const TrackDetailsScreen({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    final String status = collection['status'] as String? ?? '';
    if (status == 'En Route') {
      // Grab-style layout: full-screen map with a draggable bottom sheet for details
      return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('On the way'),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // Map placeholder (replace with real map later)
            Positioned.fill(
              child: Container(
                color: AppColors.backgroundDark,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 120,
                        color: AppColors.textSecondary.withValues(alpha: 0.35),
                      ),
                      const SizedBox(height: 8),
                      Text('Live Map', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ),
            ),

            // Top overlay ETA chip (visible even when sheet is collapsed)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        collection['estimatedTime']?.toString() ?? '--',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Draggable sheet
            DraggableScrollableSheet(
              initialChildSize: 0.32,
              minChildSize: 0.2,
              maxChildSize: 0.88,
              builder: (context, scrollController) {
                return DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: _buildBottomSheetContent(scrollController),
                );
              },
            ),
          ],
        ),
      );
    }

    // Non–En Route: Completed or Pending
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: (status == 'Completed')
            ? AppColors.successColor
            : AppColors.primaryBlue,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Collection Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingSmd),
        child: (status == 'Completed')
            ? _buildCompletedCard()
            : _buildPendingCard(),
      ),
    );
  }

  Widget _buildBottomSheetContent(ScrollController scrollController) {
    final eta = (collection['estimatedTime'] ?? '--') as String;
    final distance = collection['distance']?.toString();
    final lastUpdated = collection['lastUpdated']?.toString() ?? '1 min ago';
    final double rating = (collection['rating'] as num?)?.toDouble() ?? 4.8;
    final int? reviews = collection['reviews'] as int?; // optional

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingSmd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ID + status row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          collection['id'] ?? 'COLLECTION',
                          style: AppTextStyles.h4,
                        ),
                        // keep header clean; status already in app bar
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (distance != null && distance.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.route,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(distance, style: AppTextStyles.caption),
                            ],
                          )
                        else
                          const SizedBox.shrink(),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Updated $lastUpdated',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.paddingSmd),
                    // Collector row
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.backgroundLight,
                          child: Icon(
                            Icons.person,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                collection['collector'] ?? 'Collector',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                collection['phone'] ?? '',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (reviews != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '($reviews)',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Icon-only actions to reduce width usage
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.message,
                            color: AppColors.primaryBlue,
                          ),
                          tooltip: 'Message',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.phone,
                            color: AppColors.primaryBlue,
                          ),
                          tooltip: 'Call',
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.paddingSmd),
                    // quick stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoItem('ETA', eta),
                        _buildInfoItem('Weight', collection['weight'] ?? '--'),
                        _buildInfoItem(
                          'Earnings',
                          collection['earnings'] ?? '--',
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.paddingSmd),
                    // items
                    Text(
                      'Items',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...((collection['items'] as List<dynamic>? ?? [])).map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.08),
                              border: Border.all(color: AppColors.primaryBlue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.toString(),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.paddingSmd),
                    _buildChecklistSection(),
                    const SizedBox(height: AppDimensions.paddingXl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Completed details card (polished design)
  Widget _buildCompletedCard() {
    final completedDate =
        collection['completedDate']?.toString() ?? 'Oct 10, 2025 at 2:30 PM';
    final weight = collection['weight']?.toString() ?? '12.5 kg';
    final earnings = collection['earnings']?.toString() ?? '₱245.50';
    final payment = collection['paymentMethod']?.toString() ?? 'GCash';
    final co2Saved = collection['co2Saved']?.toString() ?? '8.2 kg';
    final itemsRecycled =
        ((collection['items'] as List<dynamic>? ?? [])).length;

    return Column(
      children: [
        // Success Banner Card
        Card(
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.successColor.withValues(alpha: 0.1),
                  AppColors.successColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.successColor.withValues(alpha: 0.2),
              ),
            ),
            padding: const EdgeInsets.all(AppDimensions.paddingSmd),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.successColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Collection Completed!',
                        style: AppTextStyles.h4.copyWith(
                          color: AppColors.successColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completed on $completedDate',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.successColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    collection['id']?.toString() ?? '#COL001',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.successColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Summary Stats Card
        Card(
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingSmd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Collection Summary',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco,
                            size: 14,
                            color: AppColors.successColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$co2Saved CO₂ saved',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingSm),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Weight',
                        weight,
                        Icons.scale,
                        AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Earnings',
                        earnings,
                        Icons.payments,
                        AppColors.successColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Payment Method',
                        payment,
                        Icons.account_balance_wallet,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Items Recycled',
                        '$itemsRecycled items',
                        Icons.recycling,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Collector Info Card
        Card(
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingSmd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Collector',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingSm),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryBlue,
                            AppColors.primaryBlue.withValues(alpha: 0.8),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collection['collector']?.toString() ?? 'Juan Cruz',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            collection['phone']?.toString() ??
                                '+63 917 123 4567',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                final rating =
                                    (collection['rating'] as num?)
                                        ?.toDouble() ??
                                    4.8;
                                return Icon(
                                  index < rating.floor()
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 16,
                                  color: Colors.amber,
                                );
                              }),
                              const SizedBox(width: 8),
                              Text(
                                ((collection['rating'] as num?)?.toDouble() ??
                                        4.8)
                                    .toStringAsFixed(1),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (collection['reviews'] != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${collection['reviews']} reviews)',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.phone,
                            color: AppColors.primaryBlue,
                          ),
                          tooltip: 'Call Collector',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue.withValues(alpha: 
                              0.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.message,
                            color: AppColors.primaryBlue,
                          ),
                          tooltip: 'Message Collector',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue.withValues(alpha: 
                              0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Items & Photos Card
        Card(
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingSmd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collection Details',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingSm),
                Text(
                  'Items Collected',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...((collection['items'] as List<dynamic>? ??
                            ['Plastic Bottles', 'Cardboard', 'Newspapers']))
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.08),
                              border: Border.all(
                                color: AppColors.primaryBlue.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: AppColors.successColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.toString(),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingSmd),
                Text(
                  'Collection Photos',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) => _buildPhotoCard(index),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Actions Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingSmd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actions',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingSm),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download Receipt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.star_border, size: 18),
                        label: const Text('Rate Collector'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          side: const BorderSide(color: AppColors.primaryBlue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.report_problem, size: 18),
                    label: const Text('Report an Issue'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(int index) {
    final photoLabels = ['Before', 'Items', 'Weighing', 'Completed'];
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            index == 0 ? Icons.photo_camera : Icons.photo_library,
            color: AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            photoLabels[index % photoLabels.length],
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Fallback for non-En Route, non-Completed states
  Widget _buildPendingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingSmd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  collection['id']?.toString() ?? '',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingS,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      collection['status']?.toString() ?? '',
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                    border: Border.all(
                      color: _getStatusColor(
                        collection['status']?.toString() ?? '',
                      ),
                    ),
                  ),
                  child: Text(
                    collection['status']?.toString() ?? '',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _getStatusColor(
                        collection['status']?.toString() ?? '',
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingSmd),
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection['collector']?.toString() ?? '',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      collection['phone']?.toString() ?? '',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          ((collection['rating'] as num?)?.toDouble() ?? 4.8)
                              .toStringAsFixed(1),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (collection['reviews'] != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${collection['reviews']})',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingSmd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  'ETA',
                  collection['estimatedTime']?.toString() ?? '--',
                ),
                _buildInfoItem(
                  'Weight',
                  collection['weight']?.toString() ?? '--',
                ),
                _buildInfoItem(
                  'Earnings',
                  collection['earnings']?.toString() ?? '--',
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingSmd),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...((collection['items'] as List<dynamic>? ?? [])).map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.primaryBlue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.toString(),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingSmd),
            _buildPostMediaSection(),
          ],
        ),
      ),
    );
  }

  // _chip helper removed after simplification to reduce visual clutter

  Widget _buildPostMediaSection() {
    // Placeholder images/details for the post (can be wired to real media later)
    final images = [Icons.photo, Icons.photo_library, Icons.inventory_2];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Post Details',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: images
              .map(
                (ic) => Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Icon(ic, color: AppColors.textSecondary),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildChecklistSection() {
    final steps = [
      {'label': 'Collector assigned', 'done': true},
      {'label': 'On the way', 'done': true},
      {'label': 'Arriving soon', 'done': false},
      {'label': 'Items verified', 'done': false},
      {'label': 'Collection completed', 'done': false},
    ];

    final currentIndex = steps.indexWhere((s) => !(s['done'] as bool));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pickup Progress',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...List.generate(steps.length, (i) {
          final s = steps[i];
          final isDone = s['done'] as bool;
          final isCurrent = i == currentIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // timeline gutter
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.successColor
                            : (isCurrent
                                  ? AppColors.primaryBlue
                                  : Colors.white),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDone
                              ? AppColors.successColor
                              : AppColors.borderLight,
                        ),
                      ),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 1,
                        height: 24,
                        color: isDone
                            ? AppColors.successColor.withValues(alpha: 0.4)
                            : AppColors.borderLight,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['label'] as String,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isDone
                              ? AppColors.textPrimary
                              : (isCurrent
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'En Route':
        return AppColors.primaryBlue;
      case 'Pending':
        return Colors.orange;
      case 'Completed':
        return AppColors.successColor;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
