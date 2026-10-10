import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors - Easy to change from here
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color darkGreen = Color(0xFF059669);
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF2563EB);
  static const Color primaryOrange = Color(0xFFF59E0B);
  static const Color darkOrange = Color(0xFFD97706);

  // Background Colors
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFFF1F5F9);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color containerGray = Color(0xFFE5E7EB);

  // Text Colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status Colors
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF3B82F6);

  // Border Colors
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderMedium = Color(0xFFCBD5E1);
  static const Color borderDark = Color(0xFF94A3B8);

  // Shadow Colors
  static const Color shadowLight = Color(0x0F000000);
  static const Color shadowMedium = Color(0x1A000000);
  static const Color shadowDark = Color(0x25000000);

  // Role-specific Colors - Unified green branding following 60-30-10 rule
  static const Color householdPrimary = primaryGreen;
  static const Color householdSecondary = darkGreen;
  static const Color collectorPrimary =
      primaryGreen; // Changed from blue to green
  static const Color collectorSecondary =
      darkGreen; // Changed from darkBlue to darkGreen
  static const Color junkshopPrimary =
      primaryGreen; // Changed from orange to green
  static const Color junkshopSecondary =
      darkGreen; // Changed from darkOrange to darkGreen

  // Status Badge Colors
  static const Color statusAvailable = Color(0xFFDCFCE7);
  static const Color statusAvailableText = Color(0xFF166534);
  static const Color statusBusy = Color(0xFFFEF3C7);
  static const Color statusBusyText = Color(0xFFD97706);
  static const Color statusOffline = Color(0xFFE5E7EB);
  static const Color statusOfflineText = Color(0xFF6B7280);

  // Gradient Colors
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primaryGreen, darkGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get blueGradient => LinearGradient(
    colors: [primaryBlue, darkBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get orangeGradient => LinearGradient(
    colors: [primaryOrange, darkOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadow Definitions
  static BoxShadow get cardShadow => BoxShadow(
    color: shadowLight,
    offset: const Offset(0, 4),
    blurRadius: 20,
    spreadRadius: 0,
  );

  static BoxShadow get buttonShadow => BoxShadow(
    color: primaryGreen.withValues(alpha: 0.25),
    offset: const Offset(0, 4),
    blurRadius: 15,
    spreadRadius: 0,
  );

  static BoxShadow get elevatedShadow => BoxShadow(
    color: shadowMedium,
    offset: const Offset(0, 8),
    blurRadius: 30,
    spreadRadius: 0,
  );

  // Material 3 Theme Properties - Green as primary brand color
  static const Color primary = primaryGreen;
  static const Color onPrimary = textWhite;
  static const Color surface = cardBackground;
  static const Color onSurface = textPrimary;
  static const Color surfaceVariant = backgroundDark;
  static const Color onSurfaceVariant = textSecondary;
  static const Color background = backgroundLight;
  static const Color onBackground = textPrimary;
  static const Color secondary = primaryBlue; // Blue as secondary (30%)
  static const Color onSecondary = textWhite;
  static const Color tertiary = primaryOrange; // Orange as accent (10%)
  static const Color onTertiary = textWhite;
  static const Color outline = borderMedium;
  static const Color outlineVariant = borderLight;

  // Helpers: safe opacity using withValues (replacement for deprecated withOpacity)
  // Usage examples:
  // - AppColors.withAlpha(AppColors.primaryGreen, 0.12)
  // - AppColors.primaryGreenWith(0.12)
  static Color withAlpha(Color color, double alpha) =>
      color.withValues(alpha: alpha);

  static Color primaryGreenWith(double alpha) =>
      primaryGreen.withValues(alpha: alpha);
  static Color darkGreenWith(double alpha) =>
      darkGreen.withValues(alpha: alpha);
  static Color primaryBlueWith(double alpha) =>
      primaryBlue.withValues(alpha: alpha);
  static Color darkBlueWith(double alpha) => darkBlue.withValues(alpha: alpha);
  static Color primaryOrangeWith(double alpha) =>
      primaryOrange.withValues(alpha: alpha);
  static Color darkOrangeWith(double alpha) =>
      darkOrange.withValues(alpha: alpha);

  // Legacy aliases (for backward compatibility with old utils)
  static Color get cardShadowColor => shadowLight;
  static const Color statusCompleted = successColor;
  static const Color statusEnRoute = primaryBlue;
  static const Color borderColor = borderLight;
  static LinearGradient get successGradient => primaryGradient;

  // Additional aliases for common usage
  static const Color success = successColor;
  static const Color error = errorColor;
  static const Color warning = warningColor;
  static const Color surfaceWhite = cardBackground;
  static const Color shadow = shadowLight;
}
