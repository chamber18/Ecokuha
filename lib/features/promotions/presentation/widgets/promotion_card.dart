import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/promotion_type.dart';

class PromotionCard extends StatelessWidget {
  final Promotion promotion;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final bool showActions;

  const PromotionCard({
    super.key,
    required this.promotion,
    this.onTap,
    this.onEdit,
    this.onCancel,
    this.onDelete,
    this.showActions = true,
  });

  // ── status palette ──────────────────────────────────────────────────────────
  Color get _accentColor {
    switch (promotion.status) {
      case PromotionStatus.active:
        return const Color(0xFF22C55E);
      case PromotionStatus.expired:
        return const Color(0xFFEF4444);
      case PromotionStatus.cancelled:
        return const Color(0xFFF97316);
      case PromotionStatus.draft:
        return const Color(0xFF94A3B8);
    }
  }

  Color get _statusBgColor {
    switch (promotion.status) {
      case PromotionStatus.active:
        return const Color(0xFFDCFCE7);
      case PromotionStatus.expired:
        return const Color(0xFFFFE4E6);
      case PromotionStatus.cancelled:
        return const Color(0xFFFFF7ED);
      case PromotionStatus.draft:
        return const Color(0xFFF1F5F9);
    }
  }

  String get _statusLabel {
    switch (promotion.status) {
      case PromotionStatus.active:
        return 'Active';
      case PromotionStatus.expired:
        return 'Expired';
      case PromotionStatus.cancelled:
        return 'Cancelled';
      case PromotionStatus.draft:
        return 'Draft';
    }
  }

  bool get _isDimmed =>
      promotion.status == PromotionStatus.expired ||
      promotion.status == PromotionStatus.cancelled;

  // ── helpers ─────────────────────────────────────────────────────────────────
  String get _timeLabel {
    final now = DateTime.now();
    if (promotion.status == PromotionStatus.active) {
      final diff = promotion.endDate.difference(now);
      if (diff.isNegative) return 'Ended';
      if (diff.inDays > 0) return '${diff.inDays}d left';
      if (diff.inHours > 0) return '${diff.inHours}h left';
      return 'Ends soon';
    }
    if (promotion.status == PromotionStatus.expired) {
      final diff = now.difference(promotion.endDate);
      return 'Ended ${diff.inDays}d ago';
    }
    return 'Cancelled';
  }

  Color get _timeColor {
    if (promotion.status != PromotionStatus.active) {
      return AppColors.textSecondary;
    }
    final days = promotion.endDate.difference(DateTime.now()).inDays;
    if (days >= 7) return const Color(0xFF16A34A);
    if (days >= 3) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final boost = promotion.priceBoostDetails.boostPercentage.toStringAsFixed(
      0,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // left accent stripe
                Container(width: 4, color: _accentColor),

                // main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // row 1: title + status badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                promotion.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _isDimmed
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusBgColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel,
                                style: TextStyle(
                                  color: _accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // row 2: boost pill + separator + time + date
                        Row(
                          children: [
                            // boost pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.trending_up_rounded,
                                    size: 11,
                                    color: _accentColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '+$boost%',
                                    style: TextStyle(
                                      color: _accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 12,
                              width: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: AppColors.borderLight,
                            ),
                            // time
                            Icon(
                              promotion.status == PromotionStatus.active
                                  ? Icons.hourglass_bottom_rounded
                                  : Icons.event_busy_rounded,
                              size: 11,
                              color: _timeColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _timeLabel,
                              style: TextStyle(
                                color: _timeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            // compact date range
                            Text(
                              '${DateFormat('MMM d').format(promotion.startDate)} – ${DateFormat('MMM d').format(promotion.endDate)}',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),

                        // action bar (only when there are actions)
                        if (showActions &&
                            (onEdit != null ||
                                onCancel != null ||
                                onDelete != null)) ...[
                          const SizedBox(height: 8),
                          Divider(height: 1, color: AppColors.borderLight),
                          _buildActions(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        if (onEdit != null)
          _actionBtn(
            icon: Icons.edit_outlined,
            label: 'Edit',
            color: AppColors.junkshopPrimary,
            onTap: onEdit!,
          ),
        if (onEdit != null && (onCancel != null || onDelete != null))
          _vDivider(),
        if (onCancel != null && promotion.status == PromotionStatus.active)
          _actionBtn(
            icon: Icons.pause_circle_outline_rounded,
            label: 'Cancel',
            color: const Color(0xFFF97316),
            onTap: onCancel!,
          ),
        if (onDelete != null)
          _actionBtn(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: const Color(0xFFEF4444),
            onTap: onDelete!,
          ),
      ],
    ),
  );

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _vDivider() => Container(
    height: 16,
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: AppColors.borderLight,
  );
}
