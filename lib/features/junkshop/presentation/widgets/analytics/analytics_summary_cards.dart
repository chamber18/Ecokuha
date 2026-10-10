import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../utils/formatters.dart';

class AnalyticsSummaryCards extends StatelessWidget {
  final double totalPurchases;
  final double totalSales;
  final double totalInventory;
  final double netProfit;

  const AnalyticsSummaryCards({
    super.key,
    required this.totalPurchases,
    required this.totalSales,
    required this.totalInventory,
    required this.netProfit,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildSummaryCard(
          title: 'Total Purchases',
          value: Formatters.formatCurrency(totalPurchases),
          icon: FluentIcons.cart_24_regular,
          color: AppColors.primaryGreen,
          context: context,
        ),
        _buildSummaryCard(
          title: 'Total Sales',
          value: Formatters.formatCurrency(totalSales),
          icon: FluentIcons.receipt_24_regular,
          color: AppColors.primaryGreen,
          context: context,
        ),
        _buildSummaryCard(
          title: 'Current Inventory',
          value: Formatters.formatCurrency(totalInventory),
          icon: FluentIcons.box_24_regular,
          color: AppColors.primaryGreen,
          context: context,
        ),
        _buildSummaryCard(
          title: 'Net Profit',
          value: Formatters.formatCurrency(netProfit),
          icon: FluentIcons.arrow_up_24_regular,
          color: netProfit >= 0 ? AppColors.primaryGreen : Colors.red,
          context: context,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: AppTextStyles.h5.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
