import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'Terms of Service',
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
              title: '1. Acceptance of Terms',
              body:
                  'By downloading, installing, or using EcoKuha ("App"), you agree to be bound by these Terms of Service ("Terms"). '
                  'If you do not agree to these Terms, please do not use the App.\n\n'
                  'EcoKuha is operated by Bote Bakal Plastic ("EcoKuha", "we", "our", "us"). '
                  'These Terms govern your access to and use of the App and all related services.',
            ),
            _buildSection(
              icon: FluentIcons.person_add_24_regular,
              title: '2. User Accounts',
              body: 'To use EcoKuha you must:',
              bullets: [
                'Be at least 13 years of age.',
                'Register with a valid email address and provide accurate information.',
                'Select your correct role — Household, Collector, or Junkshop.',
                'Keep your password confidential and not share your account.',
                'Notify us immediately if you suspect unauthorised access to your account.',
              ],
              footer:
                  'You are responsible for all activity that occurs under your account.',
            ),
            _buildSection(
              icon: FluentIcons.document_add_24_regular,
              title: '3. Household Users',
              body: 'As a Household user, you agree to:',
              bullets: [
                'Provide accurate descriptions and photos of recyclable materials when creating postings.',
                'Ensure materials are accessible and ready for collection at the scheduled pickup time.',
                'Not post non-recyclable, hazardous, or prohibited waste (see Section 8).',
                'Cancel postings promptly if you no longer require a collection.',
                'Treat collectors and junkshop staff with respect.',
              ],
            ),
            _buildSection(
              icon: FluentIcons.vehicle_truck_24_regular,
              title: '4. Collector Users',
              body: 'As a Collector, you agree to:',
              bullets: [
                'Accept only collection tasks you are genuinely able to fulfil.',
                'Arrive at the pickup location within the agreed timeframe.',
                'Accurately verify and record the materials and quantities collected.',
                'Handle all collected materials responsibly and deliver them to the assigned junkshop.',
                'Maintain a professional relationship with households and junkshop operators.',
                'Keep your vehicle and equipment in safe operating condition.',
              ],
            ),
            _buildSection(
              icon: FluentIcons.building_shop_24_regular,
              title: '5. Junkshop Users',
              body: 'As a Junkshop operator, you agree to:',
              bullets: [
                'Provide accurate pricing and availability information.',
                'Assign only verified, available collectors to postings.',
                'Process and confirm purchases promptly upon collector delivery.',
                'Maintain fair pricing practices in line with current market rates.',
                'Ensure your junkshop information (name, address, accepted materials) is kept up to date.',
              ],
            ),
            _buildSection(
              icon: FluentIcons.wallet_24_regular,
              title: '6. Transactions & Payments',
              body:
                  'EcoKuha facilitates connections between users but does not directly process monetary payments '
                  'between households and junkshops. Payment terms are agreed between the parties and settled outside the App '
                  'unless an in-app payment feature is explicitly enabled.\n\n'
                  'We are not responsible for payment disputes between users. Earnings displayed in the App are based on '
                  'verified weights and junkshop pricing entered by junkshop operators.',
            ),
            _buildSection(
              icon: FluentIcons.leaf_one_24_regular,
              title: '7. Prohibited Materials',
              body:
                  'The following materials must not be posted for collection through EcoKuha:',
              bullets: [
                'Biohazardous or medical waste (needles, blood-contaminated items).',
                'Explosive, flammable, or chemical waste.',
                'Live or dead animals.',
                'Illegal substances or paraphernalia.',
                'Items listed as prohibited under Philippine environmental regulations.',
              ],
              footer:
                  'Violation of this section may result in immediate account suspension and reporting to authorities.',
            ),
            _buildSection(
              icon: FluentIcons.camera_24_regular,
              title: '8. User-Generated Content',
              body:
                  'When you upload photos, descriptions, or other content to the App, you grant EcoKuha a non-exclusive, '
                  'royalty-free licence to use, display, and process that content solely for the purpose of operating the App.\n\n'
                  'You must not upload content that is illegal, offensive, misleading, or infringes third-party rights. '
                  'We reserve the right to remove content that violates these Terms.',
            ),
            _buildSection(
              icon: FluentIcons.prohibited_24_regular,
              title: '9. Prohibited Conduct',
              body: 'You must not:',
              bullets: [
                'Use the App to harass, threaten, or defraud other users.',
                'Create fake accounts or impersonate other users or businesses.',
                'Reverse engineer, decompile, or attempt to extract source code from the App.',
                'Use automated bots, scrapers, or tools to access the App.',
                'Interfere with or disrupt the App\'s servers or networks.',
                'Use the App for any unlawful purpose.',
              ],
            ),
            _buildSection(
              icon: FluentIcons.shield_24_regular,
              title: '10. Disclaimer of Warranties',
              body:
                  'The App is provided "as is" without warranties of any kind, express or implied. '
                  'We do not guarantee that the App will be error-free, uninterrupted, or that any defects will be corrected. '
                  'We are not responsible for the conduct of any user, including collectors, households, or junkshop operators.',
            ),
            _buildSection(
              icon: FluentIcons.warning_24_regular,
              title: '11. Limitation of Liability',
              body:
                  'To the maximum extent permitted by applicable law, EcoKuha shall not be liable for any indirect, incidental, '
                  'consequential, or punitive damages arising from your use of the App, including but not limited to: loss of earnings, '
                  'missed pickups, property damage, or disputes between users.\n\n'
                  'Our total liability to you for any claim shall not exceed the amount you paid to use the App in the 12 months preceding the claim.',
            ),
            _buildSection(
              icon: FluentIcons.person_delete_24_regular,
              title: '12. Account Termination',
              body:
                  'We reserve the right to suspend or terminate your account at any time if you violate these Terms or engage in conduct harmful to other users or the App.\n\n'
                  'You may delete your account at any time by contacting support@EcoKuha.com. '
                  'Upon deletion, your personal data will be removed within 30 days, subject to legal retention requirements.',
            ),
            _buildSection(
              icon: FluentIcons.globe_24_regular,
              title: '13. Governing Law',
              body:
                  'These Terms are governed by the laws of the Republic of the Philippines. '
                  'Any disputes arising under these Terms shall be resolved in the courts of competent jurisdiction in the Philippines.',
            ),
            _buildSection(
              icon: FluentIcons.edit_24_regular,
              title: '14. Changes to Terms',
              body:
                  'We may revise these Terms from time to time. Updated Terms will be posted in the App and the "Last Updated" date will be changed. '
                  'Your continued use of the App after changes are posted constitutes acceptance of the revised Terms.',
            ),
            _buildSection(
              icon: FluentIcons.mail_24_regular,
              title: '15. Contact Us',
              body:
                  'For questions about these Terms, please contact:\n\n'
                  'Email: support@EcoKuha.com\n'
                  'Website: www.EcoKuha.com',
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
            FluentIcons.document_text_24_regular,
            size: 28,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EcoKuha Terms of Service',
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
    String? footer,
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
            if (footer != null) ...[
              const SizedBox(height: 8),
              Text(
                footer,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                  height: 1.55,
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
