import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_dimensions.dart';

class NavigationTestScreen extends StatelessWidget {
  const NavigationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('EcoKuha - UI Testing'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Welcome to EcoKuha',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingLg),
              const Text(
                'Choose which UI to explore:',
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingXl),

              // Household UI Button
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/household-home'),
                icon: const Text('🏠', style: TextStyle(fontSize: 24)),
                label: const Text('Household UI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.householdPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.paddingLg),

              // Collector UI Button
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/collector-home'),
                icon: const Text('🚛', style: TextStyle(fontSize: 24)),
                label: const Text('Collector UI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.collectorPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.paddingLg),

              // Junk Shop UI Button
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/junkshop-dashboard'),
                icon: const Text('🏪', style: TextStyle(fontSize: 24)),
                label: const Text('Junk Shop Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.junkshopPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.paddingXl),

              // Registration Flow Button - Made more prominent
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/role-selection'),
                icon: const Icon(Icons.app_registration, color: Colors.white),
                label: const Text('Registration Flow'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen.withValues(
                    alpha: 0.8,
                  ),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.primaryGreen, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.paddingXl),
            ],
          ),
        ),
      ),
    );
  }
}
