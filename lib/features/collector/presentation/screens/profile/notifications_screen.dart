import 'package:flutter/material.dart';
import 'package:ecokuha/core/theme/app_colors.dart';
import 'package:ecokuha/core/theme/app_text_styles.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.collectorPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Manage notifications coming soon',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}
