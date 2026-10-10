import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get real data from navigation arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final postingId = args?['postingId'] as String?;
    final junkshopName = args?['junkshopName'] as String? ?? 'Any Available';
    final totalEstimatedValue = args?['totalEstimatedValue'] as double? ?? 0.0;
    final itemCount = args?['itemCount'] as int? ?? 0;
    final scheduledTime = args?['scheduledTime'] as String?;

    // Generate tracking ID based on posting ID or timestamp
    final trackingId = postingId != null
        ? 'ECO-${postingId.substring(0, 8).toUpperCase()}'
        : 'ECO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // Pickup date is TBD - junkshop will select from available dates
    String pickupDate = 'TBD - Junkshop will schedule';
    // Note: With unavailable dates approach, we don't show a specific date
    // Junkshop will select any date except the blocked ones

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppDimensions.spacingXl),
                    _buildHero(),
                    const SizedBox(height: AppDimensions.spacing16),
                    const Text(
                      'Collection Request Confirmed',
                      style: AppTextStyles.h3,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                    const Text(
                      'We\'ll notify you once a collector is assigned to your pickup.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacing16),
                    _buildTrackingRow(context, trackingId),
                    const SizedBox(height: AppDimensions.spacing16),
                    _buildSummaryTiles(
                      junkshopName,
                      totalEstimatedValue,
                      itemCount,
                    ),
                    const SizedBox(height: AppDimensions.spacing16),
                    _buildVerticalTimeline(pickupDate, scheduledTime),
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingXl),
              child: Column(
                children: [
                  // Track collection button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _trackCollection(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusM,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Track Collection',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingM),

                  // Go to home button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _goToHome(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.primaryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusM,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Go to Home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed: older banner and chips/timeline variants after full redesign.

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        gradient: AppColors.successGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: const [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.textWhite,
            child: Icon(
              Icons.check_circle,
              color: AppColors.successColor,
              size: 28,
            ),
          ),
          SizedBox(width: AppDimensions.spacing16),
          Expanded(
            child: Text(
              'You\'re all set! 🎉',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingRow(BuildContext context, String trackingId) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number, color: AppColors.primaryBlue),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracking ID',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  trackingId,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: trackingId));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tracking ID copied')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTiles(
    String junkshopName,
    double totalEstimatedValue,
    int itemCount,
  ) {
    Widget tile(IconData icon, String label, String value) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primaryBlue, size: 18),
              const SizedBox(height: AppDimensions.spacingS),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(Icons.store, 'Junkshop', junkshopName),
        tile(
          Icons.attach_money,
          'Est. Value',
          '₱${totalEstimatedValue.toStringAsFixed(2)}',
        ),
        tile(Icons.inventory_2, 'Items', '$itemCount'),
      ],
    );
  }

  Widget _buildVerticalTimeline(String pickupDate, String? scheduledTime) {
    Widget step({
      required bool active,
      required String title,
      required String subtitle,
      required IconData icon,
      bool isLast = false,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryBlue
                      : AppColors.backgroundLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active
                        ? AppColors.primaryBlue
                        : AppColors.borderColor,
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 12,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 20,
                  color: active ? AppColors.primaryBlue : AppColors.borderColor,
                ),
            ],
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!isLast) const SizedBox(height: AppDimensions.spacingM),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          step(
            active: true,
            title: 'Posted',
            subtitle: 'Request created successfully',
            icon: Icons.check_circle,
          ),
          step(
            active: true,
            title: 'Queued',
            subtitle: 'Waiting for collector assignment',
            icon: Icons.schedule,
          ),
          step(
            active: false,
            title: 'Scheduled',
            subtitle: scheduledTime != null
                ? '$pickupDate at $scheduledTime'
                : pickupDate,
            icon: Icons.calendar_today,
          ),
          step(
            active: false,
            title: 'On the way',
            subtitle: 'You\'ll be notified when started',
            icon: Icons.directions_bike,
            isLast: true,
          ),
        ],
      ),
    );
  }

  void _trackCollection(BuildContext context) {
    // Navigate to household dashboard and open track tab (index 2)
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/household-home',
      (route) => false,
      arguments: {'initialIndex': 2},
    );
  }

  void _goToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/household-home',
      (route) => false,
    );
  }
}
