import 'package:intl/intl.dart';
import '../../../../core/utils/formatters.dart' as app_formatters;

/// Formatting utilities for Junkshop analytics features
class Formatters {
  /// Format currency with peso sign and comma separators
  /// Examples: ₱1,234.56, ₱12,345.67
  static String formatCurrency(double amount) {
    return app_formatters.AppFormatters.currency(amount);
  }

  /// Format weight with dynamic unit
  /// Examples: 1.5 kg, 250.0 kg, 5 pieces
  static String formatWeight(double weight, {String unit = 'kg'}) {
    if (unit == 'piece') {
      return '${weight.toStringAsFixed(0)} ${weight == 1 ? 'piece' : 'pieces'}';
    }
    return '${weight.toStringAsFixed(1)} $unit';
  }

  /// Format date in readable format
  /// Examples: Jan 15, 2024, Dec 31, 2023
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
}
