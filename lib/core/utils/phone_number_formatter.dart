import 'package:flutter/services.dart';

/// Formats Philippine phone numbers as: 09 000 000 000
/// - Accepts input with or without +63 prefix
/// - Displays with spaces for better readability
/// - Stores as plain digits (no spaces)
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Get only digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    // If empty, return empty
    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    // Handle +63 prefix (remove it for display, keep as 09)
    String workingDigits = digitsOnly;
    if (workingDigits.startsWith('63') && workingDigits.length >= 12) {
      // Convert +63 9XX XXX XXXX to 09XX XXX XXXX
      workingDigits = '0${workingDigits.substring(2)}';
    }

    // Ensure it starts with 0
    if (!workingDigits.startsWith('0')) {
      workingDigits = '0$workingDigits';
    }

    // Limit to 11 digits (09 + 9 digits)
    if (workingDigits.length > 11) {
      workingDigits = workingDigits.substring(0, 11);
    }

    // Format as: 09 000 000 000
    final buffer = StringBuffer();
    for (int i = 0; i < workingDigits.length; i++) {
      if (i == 2 || i == 5 || i == 8) {
        buffer.write(' ');
      }
      buffer.write(workingDigits[i]);
    }

    final formatted = buffer.toString();

    // Calculate new cursor position
    int selectionIndex = formatted.length;

    // If user is typing (not deleting), put cursor at end
    if (newValue.text.length >= oldValue.text.length) {
      selectionIndex = formatted.length;
    } else {
      // If deleting, try to maintain relative position
      final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
      final diff = oldDigits.length - digitsOnly.length;
      if (diff > 0) {
        selectionIndex = formatted.length;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

/// Helper function to format phone number string for display
String formatPhoneNumber(String? phone) {
  if (phone == null || phone.isEmpty) return '';

  // Get only digits
  final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');

  if (digitsOnly.isEmpty) return '';

  // Handle +63 prefix
  String workingDigits = digitsOnly;
  if (workingDigits.startsWith('63') && workingDigits.length >= 12) {
    workingDigits = '0${workingDigits.substring(2)}';
  }

  // Ensure starts with 0
  if (!workingDigits.startsWith('0')) {
    workingDigits = '0$workingDigits';
  }

  // Limit to 11 digits
  if (workingDigits.length > 11) {
    workingDigits = workingDigits.substring(0, 11);
  }

  // Format as: 09 000 000 000
  final buffer = StringBuffer();
  for (int i = 0; i < workingDigits.length; i++) {
    if (i == 2 || i == 5 || i == 8) {
      buffer.write(' ');
    }
    buffer.write(workingDigits[i]);
  }

  return buffer.toString();
}

/// Helper function to get plain phone number (digits only) for storage
String getPlainPhoneNumber(String? phone) {
  if (phone == null || phone.isEmpty) return '';
  return phone.replaceAll(RegExp(r'\D'), '');
}
