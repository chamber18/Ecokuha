import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class PhoneLauncher {
  /// Launch phone dialer with the given phone number
  static Future<void> makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw 'Could not launch phone dialer';
      }
    } catch (e) {
      if (kDebugMode) print('Error launching phone dialer: $e');
      rethrow;
    }
  }

  /// Check if device can make phone calls
  static Future<bool> canMakePhoneCalls() async {
    final Uri testUri = Uri(scheme: 'tel', path: '');
    return await canLaunchUrl(testUri);
  }
}
