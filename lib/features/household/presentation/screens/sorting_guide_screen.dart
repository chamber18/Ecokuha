import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class SortingGuideScreen extends StatelessWidget {
  const SortingGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.successColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Sorting Guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        children: const [
          _GuideCard(
            title: 'Plastics',
            description:
                'Bottles, containers, and bags. Rinse and dry before posting.',
            icon: Icons.recycling,
            color: Color(0xFF3B82F6),
          ),
          SizedBox(height: AppDimensions.spacing12),
          _GuideCard(
            title: 'Paper & Cardboard',
            description: 'Keep clean and dry. Flatten boxes to save space.',
            icon: Icons.description_outlined,
            color: Color(0xFFF59E0B),
          ),
          SizedBox(height: AppDimensions.spacing12),
          _GuideCard(
            title: 'Metals',
            description: 'Aluminum cans and tins. No sharp edges.',
            icon: Icons.coffee_outlined,
            color: Color(0xFF10B981),
          ),
          SizedBox(height: AppDimensions.spacing12),
          _GuideCard(
            title: 'Glass',
            description: 'Bottles and jars. Separate by color if possible.',
            icon: Icons.local_drink_outlined,
            color: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _GuideCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 20.0,
            offset: Offset(0, 4.0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.h5),
                  const SizedBox(height: 6),
                  Text(description, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
