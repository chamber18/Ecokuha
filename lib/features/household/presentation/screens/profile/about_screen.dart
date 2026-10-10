import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _version = '1.0.0';
  static const String _email = 'support@EcoKuha.com';

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
          'About EcoKuha',
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 20),
            _buildMissionCard(),
            const SizedBox(height: 20),
            _buildHowItWorksCard(),
            const SizedBox(height: 20),
            _buildRolesCard(),
            const SizedBox(height: 20),
            _buildEcoCard(),
            const SizedBox(height: 20),
            _buildTechCard(),
            const SizedBox(height: 20),
            _buildContactCard(context),
            const SizedBox(height: 20),
            _buildLegalCard(context),
            const SizedBox(height: 32),
            _buildFooter(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Hero ────────────────────────────────────────────────────────────────────
  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/logos/bbp logo-200px.png',
            width: 80,
            height: 80,
          ),
          const SizedBox(height: 14),
          const Text(
            'EcoKuha',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bote Bakal Plastic',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Version $_version',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mission ─────────────────────────────────────────────────────────────────
  Widget _buildMissionCard() {
    return _buildCard(
      title: 'Our Mission',
      icon: FluentIcons.flag_24_regular,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBodyText(
            'EcoKuha bridges households, collectors, and junkshops to make '
            'recycling simple, transparent, and rewarding for Filipino communities.',
          ),
          const SizedBox(height: 12),
          _buildBodyText(
            'We believe every piece of waste has value — not just economically, '
            'but for the environment and the people who depend on it. Our platform '
            'empowers barangay residents to turn clutter into cash while reducing '
            'their carbon footprint one pickup at a time.',
          ),
        ],
      ),
    );
  }

  // ─── How It Works ────────────────────────────────────────────────────────────
  Widget _buildHowItWorksCard() {
    final steps = [
      (
        '1',
        FluentIcons.document_add_24_regular,
        const Color(0xFF2196F3),
        'Post Your Waste',
        'Take a photo of your recyclables using our AI scanner or add items manually. Specify quantities and choose a nearby junkshop.',
      ),
      (
        '2',
        FluentIcons.vehicle_truck_24_regular,
        const Color(0xFF9C27B0),
        'Get Picked Up',
        'A junkshop reviews your posting and assigns a verified collector. Track their arrival in real time on the map.',
      ),
      (
        '3',
        FluentIcons.scale_fit_24_regular,
        const Color(0xFFFF9800),
        'Weigh & Verify',
        'The collector verifies the materials and quantities on-site. Both parties confirm the final weights before pricing.',
      ),
      (
        '4',
        FluentIcons.wallet_24_regular,
        const Color(0xFF4CAF50),
        'Get Paid',
        'Receive your earnings based on verified weights and current market prices. Track every transaction in your history.',
      ),
    ];

    return _buildCard(
      title: 'How It Works',
      icon: FluentIcons.map_24_regular,
      child: Column(
        children: steps
            .map(
              (s) =>
                  _buildStep(s.$1, s.$2, s.$3, s.$4, s.$5, isLast: s.$1 == '4'),
            )
            .toList(),
      ),
    );
  }

  Widget _buildStep(
    String number,
    IconData icon,
    Color color,
    String title,
    String desc, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, size: 22, color: Colors.grey.shade600),
              if (!isLast)
                Container(
                  width: 2,
                  height: 20,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.grey.shade200,
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Step $number',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Roles ───────────────────────────────────────────────────────────────────
  Widget _buildRolesCard() {
    final roles = [
      (
        FluentIcons.home_24_regular,
        const Color(0xFF4CAF50),
        'Household',
        'Post recyclables, track pickups, earn money, and monitor your eco impact.',
      ),
      (
        FluentIcons.person_24_regular,
        const Color(0xFF2196F3),
        'Collector',
        'Accept collection tasks, navigate routes, and verify materials on-site.',
      ),
      (
        FluentIcons.building_shop_24_regular,
        const Color(0xFF9C27B0),
        'Junkshop',
        'Manage inventory, assign collectors, track purchases, and grow your business.',
      ),
    ];

    return _buildCard(
      title: 'Who Uses EcoKuha',
      icon: FluentIcons.people_24_regular,
      child: Column(
        children: roles.asMap().entries.map((e) {
          final isLast = e.key == roles.length - 1;
          final r = e.value;
          return Column(
            children: [
              _buildRoleTile(r.$1, r.$2, r.$3, r.$4),
              if (!isLast) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 10),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoleTile(IconData icon, Color color, String role, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.grey.shade600),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Eco Impact ──────────────────────────────────────────────────────────────
  Widget _buildEcoCard() {
    final stats = [
      (
        FluentIcons.leaf_one_24_regular,
        AppColors.primaryGreen,
        'CO₂ Tracking',
        'Every pickup calculates carbon savings using material-specific emission factors.',
      ),
      (
        FluentIcons.tree_deciduous_24_regular,
        const Color(0xFF00796B),
        'Tree Equivalents',
        'See your impact visualised as trees planted and car travel avoided.',
      ),
      (
        FluentIcons.trophy_24_regular,
        const Color(0xFF1976D2),
        'Eco Leaderboard',
        'Compete with neighbours and earn your place on the community leaderboard.',
      ),
    ];

    return _buildCard(
      title: 'Eco Impact',
      icon: FluentIcons.leaf_one_24_regular,
      child: Column(
        children: [
          _buildBodyText(
            'Every kilogram you recycle prevents CO\u2082 emissions compared to producing '
            'new materials from scratch. EcoKuha calculates your exact environmental '
            'contribution and turns it into a story you can share.',
          ),
          const SizedBox(height: 16),
          ...stats.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(s.$1, size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.$3,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.$4,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Technology ──────────────────────────────────────────────────────────────
  Widget _buildTechCard() {
    final items = [
      (
        FluentIcons.flash_24_regular,
        const Color(0xFFFF9800),
        'Flutter',
        'Cross-platform app built with Flutter for a smooth, native-like experience on Android & iOS.',
      ),
      (
        FluentIcons.cloud_24_regular,
        const Color(0xFF1976D2),
        'Supabase',
        'Supabase Postgres database, Auth, Realtime, and Storage power the backend.',
      ),
      (
        FluentIcons.brain_circuit_24_regular,
        const Color(0xFF7B1FA2),
        'AI Detection',
        'On-device TFLite model identifies recyclable materials from photos instantly.',
      ),
      (
        FluentIcons.map_24_regular,
        const Color(0xFF00796B),
        'Google Maps',
        'Live route navigation and location tracking for collectors and households.',
      ),
    ];

    return _buildCard(
      title: 'Built With',
      icon: FluentIcons.code_24_regular,
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(item.$1, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$3,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$4,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Contact ─────────────────────────────────────────────────────────────────
  Widget _buildContactCard(BuildContext context) {
    return _buildCard(
      title: 'Get in Touch',
      icon: FluentIcons.person_support_24_regular,
      child: Column(
        children: [
          _buildContactRow(
            context,
            icon: FluentIcons.mail_24_regular,
            color: const Color(0xFF9C27B0),
            label: 'Email Support',
            value: _email,
            onTap: () => _copyToClipboard(context, _email, 'Email copied'),
          ),
          Divider(height: 24, color: Colors.grey.shade100),
          _buildContactRow(
            context,
            icon: FluentIcons.globe_24_regular,
            color: const Color(0xFF1976D2),
            label: 'Website',
            value: 'www.EcoKuha.com',
            onTap: () =>
                _copyToClipboard(context, 'www.EcoKuha.com', 'URL copied'),
          ),
          Divider(height: 24, color: Colors.grey.shade100),
          _buildContactRow(
            context,
            icon: FluentIcons.share_android_24_regular,
            color: const Color(0xFF1877F2),
            label: 'Facebook',
            value: 'EcoKuha Official',
            onTap: () =>
                _copyToClipboard(context, 'EcoKuha Official', 'Copied'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            FluentIcons.copy_24_regular,
            size: 15,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  // ─── Legal ───────────────────────────────────────────────────────────────────
  Widget _buildLegalCard(BuildContext context) {
    return _buildCard(
      title: 'Legal',
      icon: FluentIcons.certificate_24_regular,
      child: Column(
        children: [
          _buildLegalTile(
            context,
            icon: FluentIcons.shield_24_regular,
            color: const Color(0xFF00796B),
            title: 'Privacy Policy',
            subtitle: 'How we collect and use your data',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          Divider(height: 20, color: Colors.grey.shade100),
          _buildLegalTile(
            context,
            icon: FluentIcons.document_text_24_regular,
            color: const Color(0xFF1976D2),
            title: 'Terms of Service',
            subtitle: 'Rules and guidelines for using EcoKuha',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            FluentIcons.chevron_right_24_regular,
            size: 13,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  // ─── Footer ──────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: [
        Image.asset(
          'assets/images/logos/bbp logo-50px.png',
          width: 32,
          height: 32,
        ),
        const SizedBox(height: 8),
        Text(
          '© 2026 EcoKuha — Bote Bakal Plastic. All rights reserved.',
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Made with ♥ for Filipino communities',
          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Version $_version',
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.grey.shade400,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBodyText(String text) {
    return Text(
      text,
      style: AppTextStyles.bodyMedium.copyWith(
        color: Colors.grey.shade700,
        height: 1.6,
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.primaryGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
