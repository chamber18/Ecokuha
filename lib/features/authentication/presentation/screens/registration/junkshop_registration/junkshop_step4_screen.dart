import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';

class JunkshopStep4Screen extends StatefulWidget {
  const JunkshopStep4Screen({super.key});

  @override
  State<JunkshopStep4Screen> createState() => _JunkshopStep4ScreenState();
}

class _JunkshopStep4ScreenState extends State<JunkshopStep4Screen> {
  final _formKey = GlobalKey<FormState>();

  bool _agreeToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _submitApplication() async {
    if (_formKey.currentState!.validate() && _agreeToTerms) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      await Future.delayed(const Duration(seconds: 3));

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      final previousData =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ??
          {};

      final junkshopData = {
        ...previousData,
        'agreeToTerms': _agreeToTerms,
        'step': 4,
      };

      // Navigate to review step (step 5)
      Navigator.pushNamed(
        context,
        '/junkshop-register-5',
        arguments: junkshopData,
      );
    } else if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to all terms and conditions'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppDimensions.paddingLg),
                child: _buildVerificationForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacing32),

          // Registration Summary
          _buildSummaryCard(),

          const SizedBox(height: AppDimensions.spacing24),

          // Agreements Section (no account security in non-auth flow)
          Text(
            'Agreements',
            style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Terms and Conditions
          Text(
            'Terms & Agreements',
            style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // General Terms Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: (value) {
                  setState(() {
                    _agreeToTerms = value ?? false;
                  });
                },
                activeColor: AppColors.junkshopPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _agreeToTerms = !_agreeToTerms;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        children: const [
                          TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: AppColors.junkshopPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: AppColors.junkshopPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing24),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: () => Navigator.pop(context),
                  text: 'Back',
                  backgroundColor: AppColors.backgroundDark,
                  textColor: AppColors.textPrimary,
                  height: 56,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing16),
              Expanded(
                child: CustomButton(
                  onPressed: _isLoading ? null : _submitApplication,
                  text: _isLoading ? 'Processing...' : 'Next Step',
                  backgroundColor: AppColors.junkshopPrimary,
                  isLoading: _isLoading,
                  height: 56,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing24),

          // Progress info
          Text(
            'Next step: Review',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppDimensions.spacing24),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rtl,
                color: AppColors.junkshopPrimary,
                size: 24,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                'Registration Summary',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing16),

          _buildSummaryItem('✅', 'Business Information', 'Complete'),
          _buildSummaryItem('✅', 'Location Details', 'Complete'),
          _buildSummaryItem('⏳', 'Business Verification', 'In Progress'),

          const SizedBox(height: AppDimensions.spacing16),

          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.junkshopPrimary,
                  size: 16,
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    'All information has been verified. Complete this final step to submit your application.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.junkshopPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String emoji, String title, String status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppDimensions.spacing8),
          Expanded(child: Text(title, style: AppTextStyles.bodyMedium)),
          Text(
            status,
            style: AppTextStyles.bodySmall.copyWith(
              color: status == 'Complete'
                  ? AppColors.successColor
                  : AppColors.warningColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
