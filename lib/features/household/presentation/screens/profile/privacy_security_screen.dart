import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool shareAnalytics = true;
  bool allowLocation = true;
  bool faceIdEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: AppColors.householdPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        children: [
          _switchCard(
            title: 'Share Anonymous Analytics',
            subtitle: 'Help us improve the app by sharing usage statistics',
            value: shareAnalytics,
            onChanged: (v) => setState(() => shareAnalytics = v),
          ),
          _switchCard(
            title: 'Location Access',
            subtitle: 'Enable precise location for better pickup matching',
            value: allowLocation,
            onChanged: (v) => setState(() => allowLocation = v),
          ),
          _switchCard(
            title: 'Biometric Login',
            subtitle: 'Use Face ID / Fingerprint for quick sign-in',
            value: faceIdEnabled,
            onChanged: (v) => setState(() => faceIdEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _switchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.householdPrimary,
          ),
        ],
      ),
    );
  }
}
