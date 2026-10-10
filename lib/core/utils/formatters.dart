import 'package:intl/intl.dart';

class AppFormatters {
  /// Format currency with peso sign and comma separators
  /// Examples: ₱1,234.56, ₱12,345.67, ₱123,456.78
  static String currency(double amount, {int decimals = 2}) {
    final pattern = decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0';
    final formatter = NumberFormat(pattern, 'en_US');
    return '₱${formatter.format(amount)}';
  }

  /// Format number with comma separators (no currency sign)
  /// Examples: 1,234, 12,345.67, 123,456
  static String number(num value, {int decimals = 0}) {
    final pattern = decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0';
    final formatter = NumberFormat(pattern, 'en_US');
    return formatter.format(value);
  }

  /// Format currency without decimals
  /// Examples: ₱1,234, ₱12,345, ₱123,456
  static String currencyWhole(double amount) {
    return currency(amount, decimals: 0);
  }

  /// Format compact currency (K for thousands, M for millions)
  /// Examples: ₱1.2K, ₱15K, ₱1.5M
  static String currencyCompact(double amount) {
    if (amount >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(amount >= 10000 ? 0 : 1)}K';
    } else {
      return '₱${amount.toStringAsFixed(0)}';
    }
  }

  /// Format weight with proper unit
  /// Examples: 1.5 kg, 250 g, 2.3 tons
  static String weight(double amount, String unit) {
    return '${number(amount, decimals: 1)} $unit';
  }

  /// Format percentage
  /// Examples: 15.5%, 100%, 0.5%
  static String percentage(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }
}
