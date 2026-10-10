/// Utility functions for text formatting and manipulation
class TextUtils {
  /// Capitalizes the first letter of each word in a string
  /// Example: "john doe" -> "John Doe"
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;

    return text
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  /// Capitalizes only the first letter of the entire string
  /// Example: "hello world" -> "Hello world"
  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    final trimmed = text.trim();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}
