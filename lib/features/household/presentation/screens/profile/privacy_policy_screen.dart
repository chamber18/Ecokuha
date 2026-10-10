import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _lastUpdated = 'February 23, 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            FluentIcons.arrow_left_24_regular,
            size: 18,
            color: Color(0xFF1A1A2E),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: AppTextStyles.h4.copyWith(
            color: const Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSection(
              icon: FluentIcons.info_24_regular,
              title: '1. Introduction',
              body:
                  'EcoKuha ("we", "our", or "us") is committed to protecting your personal information. '
                  'This Privacy Policy explains how we collect, use, share, and safeguard the data you provide '
                  'when using the EcoKuha mobile application ("App"), which connects households, collectors, '
                  'and junkshops for recyclable-waste collection across Filipino communities.\n\n'
                  'By using the App, you agree to the terms of this Privacy Policy.',
            ),
            _buildSection(
              icon: FluentIcons.database_24_regular,
              title: '2. Information We Collect',
              body: 'We collect the following categories of information:',
              bullets: [
                'Account details — name, email address, phone number, and role (Household / Collector / Junkshop).',
                'Profile data — profile photo, pickup address, and saved location coordinates.',
                'Posting data — photos of recyclable items, material types, estimated quantities, and junkshop preferences.',
                'Transaction records — verified weights, earnings, pickup history, and junkshop purchase logs.',
                'Location data — GPS coordinates when you use the live tracking or map picker features (only while the App is in use).',
                'Device information — device model, operating system version, and push notification tokens.',
                'Usage data — in-app actions, screen views, and feature interactions to improve the App.',
              ],
            ),
            _buildSection(
              icon: FluentIcons.target_24_regular,
              title: '3. How We Use Your Information',
              body: 'Your data is used to:',
              bullets: [
                'Create and manage your account.',
                'Match household postings with available junkshops and collectors.',
                'Enable real-time pickup tracking on the map.',
                'Process and record transactions and earnings.',
                'Calculate and display your carbon savings and eco-impact metrics.',
                'Send push notifications about posting status, collector assignments, and app updates.',
                'Improve App features, fix bugs, and personalise your experience.',
                'Comply with applicable Philippine laws and regulations.',
              ],
            ),
            _buildSection(
              icon: FluentIcons.share_24_regular,
              title: '4. Information Sharing',
              body:
                  'We do not sell your personal information. We share data only in the following circumstances:',
              bullets: [
                'With other App users — your name, profile photo, and posting details are visible to the junkshop and collector assigned to your pickup.',
                'With service providers — Supabase handles authentication, database storage, and file storage. Google Maps is used for location and routing features. These providers process data on our behalf under strict data agreements.',
                'For legal compliance — if required by law, court order, or government authority, we may disclose information as necessary.',
                'Business transfers — in the event of a merger or acquisition, user data may be transferred as part of the transaction, subject to the same protections.',
              ],
            ),
            _buildSection(
              icon: FluentIcons.location_24_regular,
              title: '5. Location Data',
              body:
                  'Location access is requested only when needed for map-based features such as address selection and live collector tracking. '
                  'We do not track your location in the background. You can revoke location permissions at any time through your device settings.',
            ),
            _buildSection(
              icon: FluentIcons.image_24_regular,
              title: '6. Photos & Media',
              body:
                  'Photos you upload for item postings are stored in Supabase Storage and are accessible to the junkshop and collector associated with your posting. '
                  'We do not use your photos for any purpose beyond facilitating the collection workflow.',
            ),
            _buildSection(
              icon: FluentIcons.lock_closed_24_regular,
              title: '7. Data Security',
              body:
                  'We implement industry-standard security measures including:\n\n'
                  '• Secure authentication with email and Google sign-in.\n'
                  '• Row Level Security policies restricting data access by user role.\n'
                  '• HTTPS encryption for all data in transit.\n\n'
                  'While we take reasonable steps to protect your data, no system is completely secure. '
                  'You are responsible for keeping your account credentials confidential.',
            ),
            _buildSection(
              icon: FluentIcons.person_24_regular,
              title: '8. Your Rights',
              body: 'You have the right to:',
              bullets: [
                'Access the personal information we hold about you.',
                'Correct inaccurate or incomplete data via the Profile settings.',
                'Delete your account and associated data by contacting support@EcoKuha.com.',
                'Withdraw consent for location or notification permissions through device settings.',
                'Request a copy of your data in a portable format.',
              ],
            ),
            _buildSection(
              icon: FluentIcons.people_24_regular,
              title: '9. Children\'s Privacy',
              body:
                  'EcoKuha is not intended for children under 13 years of age. We do not knowingly collect personal information from children. '
                  'If you believe a child has provided us with personal information, please contact us immediately.',
            ),
            _buildSection(
              icon: FluentIcons.globe_24_regular,
              title: '10. Data Retention',
              body:
                  'We retain your account and transaction data for as long as your account is active. '
                  'If you delete your account, we will remove your personal data within 30 days, '
                  'except where retention is required for legal or regulatory purposes.',
            ),
            _buildSection(
              icon: FluentIcons.edit_24_regular,
              title: '11. Changes to This Policy',
              body:
                  'We may update this Privacy Policy from time to time. When we do, we will update the "Last Updated" date at the top of this page and notify you via the App or email. '
                  'Continued use of the App after changes are posted constitutes your acceptance of the updated policy.',
            ),
            _buildSection(
              icon: FluentIcons.mail_24_regular,
              title: '12. Contact Us',
              body:
                  'If you have questions or concerns about this Privacy Policy, please contact us:\n\n'
                  'Email: support@EcoKuha.com\n'
                  'Website: www.EcoKuha.com\n\n'
                  'We will respond to your inquiry within 5 business days.',
            ),
            const SizedBox(height: 12),
            _buildFooter(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.shield_24_regular,
            size: 28,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EcoKuha Privacy Policy',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Last updated: $_lastUpdated',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String body,
    List<String>? bullets,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey.shade700,
                height: 1.6,
              ),
            ),
            if (bullets != null) ...[
              const SizedBox(height: 8),
              ...bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          b,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey.shade700,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      '© 2026 EcoKuha — Bote Bakal Plastic. All rights reserved.',
      style: AppTextStyles.bodySmall.copyWith(
        color: Colors.grey.shade400,
        fontSize: 11,
      ),
      textAlign: TextAlign.center,
    );
  }
}
