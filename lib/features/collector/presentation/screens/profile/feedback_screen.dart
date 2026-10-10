import 'package:flutter/material.dart';
import 'package:ecokuha/core/theme/app_colors.dart';
import 'package:ecokuha/core/theme/app_text_styles.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: AppColors.collectorPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Send feedback coming soon',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}
