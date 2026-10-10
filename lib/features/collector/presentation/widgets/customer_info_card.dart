import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class CustomerInfoCard extends StatelessWidget {
  final String name;
  final String phone;
  final String address;
  final String scheduledTime;
  final String? specialInstructions;
  final VoidCallback onCallPressed;
  final VoidCallback onMessagePressed;
  // Navigate button removed (redundant)

  const CustomerInfoCard({
    super.key,
    required this.name,
    required this.phone,
    required this.address,
    required this.scheduledTime,
    this.specialInstructions,
    required this.onCallPressed,
    required this.onMessagePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppColors.cardShadow],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.collectorPrimary.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: AppColors.collectorPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _ActionIconButton(
                icon: Icons.call,
                color: AppColors.successColor,
                onPressed: onCallPressed,
              ),
              const SizedBox(width: 8),
              _ActionIconButton(
                icon: Icons.chat_bubble_outline,
                color: AppColors.collectorPrimary,
                onPressed: onMessagePressed,
              ),
            ],
          ),
          if (specialInstructions != null &&
              specialInstructions!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.warningColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.warningColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      specialInstructions!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Navigate button removed (redundant with the map card action)
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
