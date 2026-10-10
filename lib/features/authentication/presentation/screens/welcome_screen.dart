import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/common/common_widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _goToLogin(BuildContext context) {
    Navigator.pushNamed(context, '/login');
  }

  void _goToCreateAccount(BuildContext context) {
    Navigator.pushNamed(context, '/role-selection');
  }

  // Removed Firebase test navigation per request

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 8),

                    // Hero + copy (no box)
                    Column(
                      children: [
                        Image.asset(
                          'assets/images/logos/bbp logo-200px.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'B.B.P. Tracker',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Turn Trash into Cash',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 24),
                        Text(
                          'Connect Households, Collectors, and Junkshops to recycle smarter and earn more.',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    // CTAs
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CustomButton(
                          text: 'Login',
                          onPressed: () => _goToLogin(context),
                          backgroundColor: AppColors.primaryGreen,
                          height: 52,
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 12),
                        // Create account
                        CustomButton(
                          text: 'Create Account',
                          onPressed: () => _goToCreateAccount(context),
                          backgroundColor: Colors.transparent,
                          isOutlined: true,
                          borderColor: AppColors.borderLight,
                          borderWidth: 1,
                          textColor: AppColors.textPrimary,
                          height: 48,
                        ),
                        const SizedBox(height: 12),
                        // Firebase test button removed
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
