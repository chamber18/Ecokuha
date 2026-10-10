import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/repositories/pickups_repository.dart';

/// Reusable function to show purchase/collection details in a modal bottom sheet
/// Can be called from any screen (inventory, history, dashboard, etc.)
void showPurchaseDetailsModal(BuildContext context, NewPickupItem purchase) {
  final isManualPayout = purchase.householdId == 'manual_payout';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                  isManualPayout ? Icons.point_of_sale : Icons.recycling,
                  size: 32,
                  color: AppColors.successColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isManualPayout
                            ? 'Onsite Purchase Details'
                            : 'Purchase Details',
                        style: AppTextStyles.h6.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _getTimeAgo(purchase.createdAt),
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
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    isManualPayout ? 'Transaction ID' : 'Purchase ID',
                    purchase.id,
                  ),
                  if (!isManualPayout) ...[
                    _buildDetailRow(
                      'Household',
                      purchase.householdName ?? 'Unknown',
                    ),
                    if (purchase.addressShort != null)
                      _buildDetailRow('Address', purchase.addressShort!),
                  ],
                  _buildDetailRow(
                    isManualPayout ? 'Total Payout' : 'Total Value',
                    '₱${purchase.totalValue.toStringAsFixed(2)}',
                  ),
                  _buildDetailRow('Items', '${purchase.items.length} items'),
                  if (!isManualPayout && purchase.dateOfCollection != null)
                    _buildDetailRow(
                      'Collection Date',
                      DateFormat(
                        'MMM d, y • h:mm a',
                      ).format(purchase.dateOfCollection!),
                    ),
                  _buildDetailRow(
                    isManualPayout ? 'Transaction Date' : 'Reviewed Date',
                    DateFormat(
                      'MMM d, y • h:mm a',
                    ).format(purchase.createdAt ?? DateTime.now()),
                    valueColor: AppColors.successColor,
                  ),
                  if (!isManualPayout && purchase.assignedCollectorName != null)
                    _buildDetailRow(
                      'Collected By',
                      purchase.assignedCollectorName!,
                    ),
                  const SizedBox(height: 16),
                  if (purchase.itemDetails.isNotEmpty) ...[
                    Text(
                      isManualPayout ? 'Items Purchased' : 'Items Collected',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...purchase.itemDetails.map((item) {
                      final qty = double.tryParse(item.quantity) ?? 0.0;
                      // Derive pricePerUnit if missing but totalPrice is available
                      // Prioritize junkshop pricing if available
                      double derivedPricePerUnit =
                          item.junkshopPricePerUnit ?? item.pricePerUnit ?? 0.0;
                      final rawTotal =
                          item.junkshopTotalPrice ?? item.totalPrice;

                      if (derivedPricePerUnit == 0.0 &&
                          rawTotal != null &&
                          rawTotal > 0 &&
                          qty > 0) {
                        derivedPricePerUnit = rawTotal / qty;
                      }
                      final totalPrice =
                          rawTotal ?? (qty * derivedPricePerUnit);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.name,
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      // Promotion Boost Badge
                                      if (item.promotionBoostPercentage !=
                                              null &&
                                          item.promotionBoostPercentage! >
                                              0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.successColor,
                                                AppColors.successColor
                                                    .withValues(alpha: 0.8),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.successColor
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.trending_up,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '+${item.promotionBoostPercentage!.toStringAsFixed(0)}%',
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 0.5,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    derivedPricePerUnit > 0
                                        ? '${item.quantity} ${item.unit} • ₱${derivedPricePerUnit.toStringAsFixed(2)} per ${item.unit}'
                                        : '${item.quantity} ${item.unit}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (totalPrice > 0)
                              Text(
                                '₱${totalPrice.toStringAsFixed(2)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                  if (isManualPayout &&
                      purchase.specialInstructions != null) ...[
                    Text(
                      'Notes',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        purchase.specialInstructions!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Helper function to format time ago
String _getTimeAgo(DateTime? date) {
  if (date == null) return 'Unknown';
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays > 7) {
    return DateFormat('MMM d, y').format(date);
  } else if (difference.inDays > 0) {
    return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  } else {
    return 'Just now';
  }
}

// Helper widget to build detail rows
Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
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
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    ),
  );
}
