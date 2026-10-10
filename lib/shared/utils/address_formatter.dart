/// Shared Google Geocoding result formatter to produce a consistent
/// "Full Address" string across registration and account screens.
///
/// Contract
/// - Input: The raw `results` array from Google Geocoding API response
///   (already decoded JSON), i.e. `List<Map<String, dynamic>>`.
/// - Output: A single formatted string composed of:
///   Block/Lot, Street, Premise/Subdivision, Barangay, City (with "City" suffix),
///   Province, Postal Code, Region (with short in parentheses if applicable), Country.
/// - Fallbacks: Scans all results for components; if block/lot or premise are
///   missing, tries to extract them from `formatted_address` of the first result.
String formatFullAddressFromGoogleResults(List<Map<String, dynamic>> results) {
  String? blockLot;
  String? street;
  String? premise;
  String? barangay;
  String? city;
  String? province;
  String? postalCode;
  String? regionLong;
  String? regionShort;
  String? country;

  // Scan all results for the most detailed set of components
  for (final result in results) {
    final components = (result['address_components'] as List)
        .cast<Map<String, dynamic>>();
    for (var component in components) {
      final types = (component['types'] as List).cast<String>();
      final longName = component['long_name'] as String;
      final shortName = component['short_name'] as String;

      if ((blockLot == null || blockLot.isEmpty) &&
          types.contains('street_number')) {
        blockLot = longName;
      }
      if ((street == null || street.isEmpty) && types.contains('route')) {
        street = longName;
      }
      if ((premise == null || premise.isEmpty) && types.contains('premise')) {
        premise = longName;
      }
      final isBarangayType =
          types.contains('neighborhood') ||
          types.contains('sublocality') ||
          types.contains('sublocality_level_1') ||
          types.contains('sublocality_level_2') ||
          types.contains('sublocality_level_3') ||
          types.contains('administrative_area_level_5') ||
          types.contains('administrative_area_level_4');
      if ((barangay == null || barangay.isEmpty) && isBarangayType) {
        barangay = longName;
      }
      if ((city == null || city.isEmpty) && types.contains('locality')) {
        city = longName;
      }
      if ((province == null || province.isEmpty) &&
          types.contains('administrative_area_level_2')) {
        province = longName;
      }
      if (types.contains('administrative_area_level_1')) {
        regionLong ??= longName;
        regionShort ??= shortName;
      }
      if ((postalCode == null || postalCode.isEmpty) &&
          types.contains('postal_code')) {
        postalCode = longName;
      }
      if ((country == null || country.isEmpty) && types.contains('country')) {
        country = longName;
      }
    }
  }

  // Fallback: Try to extract premise and block/lot from formatted_address of the first result
  if (((premise == null || premise.isEmpty) ||
          (blockLot == null || blockLot.isEmpty)) &&
      results.isNotEmpty) {
    final firstResult = results.first;
    final formattedAddr = (firstResult['formatted_address'] as String?) ?? '';
    if (formattedAddr.isNotEmpty) {
      final parts = formattedAddr.split(',').map((s) => s.trim()).toList();
      if (parts.isNotEmpty) {
        final firstPart = parts[0];
        // Skip Google Plus Codes like "CRM3+4F7" which sometimes appear as the
        // first segment of formatted_address in PH results.
        bool isPlusCode(String s) {
          // Open Location Code (OLC) pattern: 4 valid chars, '+', then 2-3 valid chars
          final olc = RegExp(
            r'^[23456789CFGHJMPQRVWX]{4}\+[23456789CFGHJMPQRVWX]{2,3}(\s.*)?$',
          );
          return olc.hasMatch(s);
        }

        if (!isPlusCode(firstPart)) {
          final blockLotMatch = RegExp(
            r'(Block\s+\d+\s+Lot\s+\d+)',
            caseSensitive: false,
          ).firstMatch(firstPart);
          if (blockLotMatch != null && (blockLot == null || blockLot.isEmpty)) {
            blockLot = blockLotMatch.group(1);
          }
          if (premise == null || premise.isEmpty) {
            String remainingText = firstPart;
            if (blockLotMatch != null) {
              remainingText = firstPart.substring(blockLotMatch.end).trim();
            }
            if (remainingText.isNotEmpty) {
              premise = remainingText;
            }
          }
        }
      }
    }
  }

  String formatCity(String? c) {
    if (c == null || c.isEmpty) return '';
    final cl = c.toLowerCase();
    if (cl.endsWith(' city')) return c;
    return '$c City';
  }

  String? regionDisplay;
  if (regionLong != null && regionLong.isNotEmpty) {
    if (regionShort != null &&
        regionShort.isNotEmpty &&
        regionShort != regionLong &&
        regionShort.toLowerCase().contains('region')) {
      regionDisplay = '$regionLong ($regionShort)';
    } else {
      regionDisplay = regionLong;
    }
  }

  final partsForFull = <String>[];
  if (blockLot != null && blockLot.isNotEmpty) partsForFull.add(blockLot);
  if (street != null && street.isNotEmpty) partsForFull.add(street);
  if (premise != null && premise.isNotEmpty) partsForFull.add(premise);
  if (barangay != null && barangay.isNotEmpty) partsForFull.add(barangay);
  final cityFormatted = formatCity(city);
  if (cityFormatted.isNotEmpty) partsForFull.add(cityFormatted);
  if (province != null && province.isNotEmpty) partsForFull.add(province);
  if (postalCode != null && postalCode.isNotEmpty) partsForFull.add(postalCode);
  if (regionDisplay != null && regionDisplay.isNotEmpty) {
    partsForFull.add(regionDisplay);
  }
  if (country != null && country.isNotEmpty) {
    partsForFull.add(country);
  } else {
    partsForFull.add('Philippines');
  }

  return partsForFull.join(', ');
}
