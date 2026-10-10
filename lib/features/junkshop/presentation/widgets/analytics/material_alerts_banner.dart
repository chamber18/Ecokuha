import 'package:flutter/material.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../bloc/material_alerts/material_alerts_state.dart';

class MaterialAlertsBanner extends StatelessWidget {
  final List<MaterialAlert> alerts;
  final VoidCallback onViewDetails;

  const MaterialAlertsBanner({
    super.key,
    required this.alerts,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    final criticalCount = alerts
        .where((a) => a.severity == AlertSeverity.critical)
        .length;
    final warningCount = alerts
        .where((a) => a.severity == AlertSeverity.warning)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: criticalCount > 0 ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: criticalCount > 0
              ? Colors.red.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: criticalCount > 0
                  ? Colors.red.shade100
                  : Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              criticalCount > 0 ? Icons.warning : Icons.info_outline,
              color: criticalCount > 0
                  ? Colors.red.shade700
                  : Colors.orange.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  criticalCount > 0
                      ? 'Material Stock Alerts'
                      : 'Material Attention Needed',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: criticalCount > 0
                        ? Colors.red.shade900
                        : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  criticalCount > 0
                      ? '$criticalCount stagnant materials (>30 days no sales)'
                      : '$warningCount slow-moving materials (7-30 days)',
                  style: AppTextStyles.caption.copyWith(
                    color: criticalCount > 0
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onViewDetails,
            child: Text(
              'View',
              style: TextStyle(
                color: criticalCount > 0
                    ? Colors.red.shade700
                    : Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
