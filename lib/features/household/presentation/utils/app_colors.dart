import 'package:flutter/material.dart';

class AppColors {
  // Primary colors from HTML prototype
  static const Color primaryBlue = Color(0xFF1563EB);
  static const Color darkBlue = Color(0xFF1E40AF);
  static const Color darkGreen = Color(0xFF057A55);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);

  // Background colors
  static const Color backgroundLight = Color(0xFF697987);
  static const Color backgroundDark = Color(0xFFEDF0F4);

  // Text colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Card and UI colors
  static const Color cardShadowColor = Color(0x1A000000);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color dividerColor = Color(0xFFE2E8F0);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, darkBlue],
    stops: [0.0, 1.0],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, darkBlue],
    stops: [0.0, 1.0],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [successColor, darkGreen],
    stops: [0.0, 1.0],
  );

  // Status colors
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusEnRoute = Color(0xFF3B82F6);
  static const Color statusCompleted = Color(0xFF10B981);
  static const Color statusCancelled = Color(0xFFEF4444);

  // Navigation colors
  static const Color navBackground = Color(0xFFFFFFFF);
  static const Color navSelected = primaryBlue;
  static const Color navUnselected = Color(0xFF94A3B8);

  // Additional UI colors
  static const Color shimmerBase = Color(0xFFF1F5F9);
  static const Color shimmerHighlight = Color(0xFFFFFFFF);
  static const Color overlayColor = Color(0x80000000);
}
