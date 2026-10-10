import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../shared/widgets/common/common_widgets.dart';

class HouseholdPendingScreen extends StatefulWidget {
  const HouseholdPendingScreen({super.key});

  @override
  State<HouseholdPendingScreen> createState() => _HouseholdPendingScreenState();
}

class _HouseholdPendingScreenState extends State<HouseholdPendingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(),
              const SizedBox(height: AppDimensions.spacing24),
              _buildSummaryCard(),
              const SizedBox(height: AppDimensions.spacing24),
              _buildActions(),
              const SizedBox(height: AppDimensions.spacing16),
              _buildFooterNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.householdPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(42),
                  border: Border.all(
                    color: AppColors.householdPrimary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 44,
                    color: AppColors.householdPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            'Application Submitted',
            style: AppTextStyles.h5.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.householdPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            'Your household registration is under review.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.successColor),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                'Thanks for joining EcoKuha!',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Text(
            'We’ll verify your details within 1–2 business days. You’ll receive updates via email or SMS.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          _buildDetailRow('Application ID', 'HSE-2024-009876'),
          _buildDetailRow('Status', 'Under Review', isStatus: true),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            text: 'Back to Login',
            isOutlined: true,
            backgroundColor: Colors.white,
            textColor: AppColors.householdPrimary,
            borderColor: AppColors.householdPrimary,
          ),
        ),
        const SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child: CustomButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/household-home'),
            text: 'Go to Home',
            backgroundColor: AppColors.householdPrimary,
            textColor: AppColors.textWhite,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.infoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Text(
        'We’ll notify you when your application status changes. You can start exploring the app meanwhile.',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: isStatus
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      value,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warningColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
