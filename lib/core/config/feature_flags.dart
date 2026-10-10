import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class FeatureFlags {
  FeatureFlags();

  Map<String, dynamic>? _raw;

  Future<void> load() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/config/feature_flags.json',
      );
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      _raw = data['feature_flags'] as Map<String, dynamic>?;
    } catch (_) {
      // If loading fails, keep _raw null; all flags will default to false
      _raw = null;
    }
  }

  bool isEnabled(String key) {
    final flags = _raw;
    if (flags == null) return false;
    final entry = flags[key];
    if (entry is Map<String, dynamic>) {
      final enabled = entry['enabled'];
      if (enabled is bool) return enabled;
    }
    return false;
  }
}
