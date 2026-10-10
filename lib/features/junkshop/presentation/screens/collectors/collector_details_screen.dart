import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_dimensions.dart';

class CollectorDetailsScreen extends StatelessWidget {
  final String collectorId;

  const CollectorDetailsScreen({super.key, required this.collectorId});

  @override
  Widget build(BuildContext context) {
    // Mock collector data - in real app this would come from BLoC/repository
    final collector = _getMockCollectorData();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.junkshopPrimary,
        foregroundColor: Colors.white,
        title: Text(
          'Collector Details',
          style: AppTextStyles.h4.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with collector info
            _buildCollectorHeader(collector),

            // Current activity
            _buildCurrentActivity(collector),

            // Performance stats
            _buildPerformanceStats(collector),

            // Recent activity
            _buildRecentActivity(collector),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectorHeader(Map<String, dynamic> collector) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      decoration: BoxDecoration(
        color: AppColors.junkshopPrimary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppDimensions.radiusXl),
          bottomRight: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Center(
              child: Text(
                collector['avatar'],
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing12),

          // Name and contact
          Text(
            collector['name'],
            style: AppTextStyles.h4.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            collector['phone'],
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing12),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing12,
              vertical: AppDimensions.spacing8,
            ),
            decoration: BoxDecoration(
              color: collector['status'] == 'On Route'
                  ? AppColors.warningColor
                  : AppColors.successColor,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            child: Text(
              collector['status'],
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentActivity(Map<String, dynamic> collector) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacing24),
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Activity',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          Row(
            children: [
              Icon(
                collector['status'] == 'On Route'
                    ? Icons.directions
                    : Icons.location_on,
                color: AppColors.junkshopPrimary,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Text(
                  collector['status'] == 'On Route'
                      ? 'En route to ${collector['currentPickup']}'
                      : 'Arrived at ${collector['currentPickup']}',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing12),

          Row(
            children: [
              Icon(Icons.access_time, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                'Started ${collector['startTime']}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStats(Map<String, dynamic> collector) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.spacing24,
        0,
        AppDimensions.spacing24,
        AppDimensions.spacing24,
      ),
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance (This Month)',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Collections',
                  collector['monthlyCollections'].toString(),
                  Icons.local_shipping,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Rating',
                  '${collector['rating']}⭐',
                  Icons.star,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing16),

          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'On Time',
                  '${collector['onTimePercentage']}%',
                  Icons.schedule,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Earnings',
                  '₱${collector['monthlyEarnings']}',
                  Icons.payments,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.junkshopPrimary, size: 24),
        const SizedBox(height: AppDimensions.spacing8),
        Text(
          value,
          style: AppTextStyles.h5.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.junkshopPrimary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(Map<String, dynamic> collector) {
    final activities =
        collector['recentActivities'] as List<Map<String, dynamic>>;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.spacing24,
        0,
        AppDimensions.spacing24,
        AppDimensions.spacing24,
      ),
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          ...activities.map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: activity['type'] == 'completed'
                  ? AppColors.successColor
                  : AppColors.warningColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['description'], style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  activity['time'],
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getMockCollectorData() {
    return {
      'id': collectorId,
      'name': 'Juan Carlos',
      'avatar': '👨',
      'phone': '+63 912 345 6789',
      'status': 'On Route',
      'currentPickup': 'Barangay San Roque',
      'startTime': '2 hours ago',
      'monthlyCollections': 45,
      'rating': 4.8,
      'onTimePercentage': 95,
      'monthlyEarnings': 15450,
      'recentActivities': [
        {
          'type': 'completed',
          'description': 'Completed pickup at Sunset Village',
          'time': '45 minutes ago',
        },
        {
          'type': 'in_progress',
          'description': 'Started route to Barangay San Roque',
          'time': '2 hours ago',
        },
        {
          'type': 'completed',
          'description': 'Completed pickup at Green Valley',
          'time': '3 hours ago',
        },
        {
          'type': 'completed',
          'description': 'Started shift',
          'time': '4 hours ago',
        },
      ],
    };
  }
}
