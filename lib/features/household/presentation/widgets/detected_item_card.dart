import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/detected_item.dart';

/// Widget for displaying a detected item card with all details
class DetectedItemCard extends StatelessWidget {
  final DetectedItem item;
  final VoidCallback onRemove;
  final Function(DetectedItem) onRecomputeValue;

  const DetectedItemCard({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onRecomputeValue,
  });

  @override
  Widget build(BuildContext context) {
    final isAiScanned = item.isAiScanned;
    final borderColor = isAiScanned
        ? AppColors.successColor.withValues(alpha: 0.3)
        : AppColors.primaryBlue.withValues(alpha: 0.3);
    final accentColor = isAiScanned
        ? AppColors.successColor
        : AppColors.primaryBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context, accentColor, isAiScanned),
          _buildDetails(context),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color accentColor,
    bool isAiScanned,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.08),
            accentColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: isAiScanned
                  ? LinearGradient(
                      colors: [
                        AppColors.successColor,
                        AppColors.successColor.withValues(alpha: 0.8),
                      ],
                    )
                  : null,
              color: isAiScanned ? null : AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: isAiScanned
                  ? const Text('🤖', style: TextStyle(fontSize: 26))
                  : const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTextStyles.cardTitle.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    // Source badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAiScanned ? Icons.auto_awesome : Icons.edit,
                            size: 12,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAiScanned ? 'AI' : 'MANUAL',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.category,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Remove button
          Container(
            decoration: BoxDecoration(
              color: AppColors.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.errorColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible condition checklist
          _buildCollapsibleConditionSection(context),
          const SizedBox(height: 16),
          // Quantity and value row
          Row(
            children: [
              Expanded(child: _buildQuantityChip()),
              const SizedBox(width: 12),
              Expanded(child: _buildValueChip()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleConditionSection(BuildContext context) {
    final hasUnsellableConditions =
        item.isCracked ||
        item.isDented ||
        item.isFaded ||
        item.hasRust ||
        item.hasPaint;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: Row(
          children: [
            Icon(
              Icons.fact_check_rounded,
              size: 16,
              color: AppColors.darkGreen,
            ),
            const SizedBox(width: 8),
            Text(
              'ITEM CONDITION',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (hasUnsellableConditions)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.errorColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      size: 12,
                      color: AppColors.errorColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ISSUES',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildConditionCheckbox(context, 'Clean', item.isClean, true),
              _buildConditionCheckbox(
                context,
                'Complete',
                item.isComplete,
                true,
              ),
              _buildConditionCheckbox(
                context,
                'Cracked',
                item.isCracked,
                false,
              ),
              _buildConditionCheckbox(context, 'Dented', item.isDented, false),
              _buildConditionCheckbox(context, 'Faded', item.isFaded, false),
              _buildConditionCheckbox(
                context,
                'Stickers',
                item.hasStickers,
                true,
              ),
              _buildConditionCheckbox(context, 'Rust', item.hasRust, false),
              _buildConditionCheckbox(context, 'Paint', item.hasPaint, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionCheckbox(
    BuildContext context,
    String label,
    bool value,
    bool isSellableWhenTrue,
  ) {
    final isUnsellable = value && !isSellableWhenTrue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: value
            ? (isUnsellable
                  ? AppColors.errorColor.withValues(alpha: 0.1)
                  : AppColors.successColor.withValues(alpha: 0.1))
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value
              ? (isUnsellable
                    ? AppColors.errorColor.withValues(alpha: 0.3)
                    : AppColors.successColor.withValues(alpha: 0.3))
              : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: value
                ? (isUnsellable ? AppColors.errorColor : AppColors.successColor)
                : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 11,
              fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              color: value
                  ? (isUnsellable
                        ? AppColors.errorColor
                        : AppColors.successColor)
                  : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityChip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUANTITY', style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '${item.quantity}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                item.unit,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValueChip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.successColor.withValues(alpha: 0.1),
            AppColors.successColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.successColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EST. VALUE', style: AppTextStyles.caption),
          const SizedBox(height: 2),
          // Show price range if available, otherwise just estimated value
          if (item.priceMin != null &&
              item.priceMax != null &&
              item.priceMin != item.priceMax)
            Row(
              children: [
                Text(
                  '₱',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item.priceMin!.toStringAsFixed(2)} - ${item.priceMax!.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.successColor,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  '₱',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.estimatedValue.toStringAsFixed(2),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.successColor,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
