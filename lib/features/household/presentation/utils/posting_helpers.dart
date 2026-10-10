import 'dart:convert';
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_helpers.dart';
import '../../../../core/constants/firestore_fields/index.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class PostingHelpers {
  /// Loads the material catalog from assets
  static Future<List<dynamic>> loadMaterialCatalog() async {
    final jsonStr = await rootBundle.loadString(
      'assets/config/material_prices.json',
    );
    final Map<String, dynamic> data =
        json.decode(jsonStr) as Map<String, dynamic>;

    // Flatten materials from all categories into a single list
    final List<dynamic> allMaterials = [];
    final categories = data['categories'] as List<dynamic>;

    for (final category in categories) {
      final materials = category['materials'] as List<dynamic>? ?? [];
      for (final material in materials) {
        // Add category ID to each material for consistency with Firebase data
        allMaterials.add({
          ...material as Map<String, dynamic>,
          'category': category['name'] as String,
          // Convert min_price/max_price to householdPriceMin/Max for consistency
          'householdPriceMin': material['min_price'],
          'householdPriceMax': material['max_price'],
        });
      }
    }

    debugPrint(
      '[PostingHelpers] Loaded ${allMaterials.length} materials from JSON catalog',
    );
    return allMaterials;
  }

  /// Calculates distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    // Haversine formula
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lng2 - lng1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Loads available junkshops from Firestore (real junkshop users)
  /// [householdLat] and [householdLng] are optional. If provided, real distances will be calculated.
  static Future<List<Map<String, dynamic>>> loadAvailableJunkshops({
    double? householdLat,
    double? householdLng,
  }) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (kDebugMode) {
        print(
          '[Junkshops] Loading with household coords: lat=$householdLat, lng=$householdLng',
        );
      }

      // Query junkshops table
      final docs = rowsToDocs(
        'junkshops',
        await Supabase.instance.client.from('junkshops').select(),
      );

      if (kDebugMode) {
        print(
          '[Junkshops] Found ${docs.length} junkshop row(s) in Supabase',
        );
      }

      final junkshops = <Map<String, dynamic>>[];

      for (final data in docs) {
        final docId = data['id'].toString();

        // Skip junkshops disabled by admin
        if (data['isActive'] == false) continue;

        // Check if current user is blocked by this junkshop
        if (currentUser != null &&
            data['blockedHouseholds'] is List &&
            (data['blockedHouseholds'] as List).contains(currentUser.id)) {
          if (kDebugMode) {
            print('[Junkshops] Skipping $docId because user is blocked');
          }
          continue;
        }

        // Extract business name from nested structure or root level
        String businessName = 'Unknown Junkshop';
        if (data[UserFields.junkshopProfile] != null &&
            data[UserFields.junkshopProfile]['business'] != null &&
            data[UserFields.junkshopProfile]['business'][UserFields
                    .businessName] !=
                null) {
          businessName =
              data[UserFields.junkshopProfile]['business'][UserFields
                      .businessName]
                  .toString()
                  .trim();
        } else if (data[UserFields.businessName] != null) {
          businessName = data[UserFields.businessName].toString().trim();
        } else if (data[UserFields.name] != null) {
          businessName = data[UserFields.name].toString().trim();
        }

        if (businessName.isEmpty) {
          businessName = 'Unknown Junkshop';
        }

        // Extract location from junkshop_profile/location
        String? address;
        String? city;
        double? junkshopLat;
        double? junkshopLng;
        double? serviceRadius;

        if (data[UserFields.junkshopProfile] != null &&
            data[UserFields.junkshopProfile][UserFields.location] != null) {
          final locData = data[UserFields.junkshopProfile][UserFields.location];
          address = locData[UserFields.address]?.toString();
          city = locData[UserFields.city]?.toString();

          // Extract lat/lng
          if (locData[UserFields.lat] != null) {
            junkshopLat = (locData[UserFields.lat] is num)
                ? (locData[UserFields.lat] as num).toDouble()
                : double.tryParse(locData[UserFields.lat].toString());
          }
          if (locData[UserFields.lng] != null) {
            junkshopLng = (locData[UserFields.lng] is num)
                ? (locData[UserFields.lng] as num).toDouble()
                : double.tryParse(locData[UserFields.lng].toString());
          }

          // Extract service_radius
          if (locData['service_radius'] != null) {
            serviceRadius = (locData['service_radius'] is num)
                ? (locData['service_radius'] as num).toDouble()
                : double.tryParse(locData['service_radius'].toString());
          }
        } else {
          // Fallback to root level
          address = data[UserFields.address]?.toString();
          city = data[UserFields.city]?.toString();

          if (data[UserFields.lat] != null) {
            junkshopLat = (data[UserFields.lat] is num)
                ? (data[UserFields.lat] as num).toDouble()
                : double.tryParse(data[UserFields.lat].toString());
          }
          if (data[UserFields.lng] != null) {
            junkshopLng = (data[UserFields.lng] is num)
                ? (data[UserFields.lng] as num).toDouble()
                : double.tryParse(data[UserFields.lng].toString());
          }

          // Try service_radius at root level
          if (data['service_radius'] != null) {
            serviceRadius = (data['service_radius'] is num)
                ? (data['service_radius'] as num).toDouble()
                : double.tryParse(data['service_radius'].toString());
          }
        }

        // Fallback to the real latitude/longitude columns
        junkshopLat ??= (data['latitude'] as num?)?.toDouble();
        junkshopLng ??= (data['longitude'] as num?)?.toDouble();

        // Try to extract barangay from address
        String? barangay;
        if (address != null && address.isNotEmpty) {
          final addressLower = address.toLowerCase();
          // Look for "barangay" or "brgy" pattern
          final barangayMatch = RegExp(
            r'(?:barangay|brgy\.?|brgy)\s+([^,]+)',
            caseSensitive: false,
          ).firstMatch(addressLower);

          if (barangayMatch != null && barangayMatch.groupCount >= 1) {
            barangay = barangayMatch.group(1)?.trim();
            // Capitalize first letter
            if (barangay != null && barangay.isNotEmpty) {
              barangay = barangay[0].toUpperCase() + barangay.substring(1);
            }
          }
        }

        // Build location string: "Barangay, City" or just "City"
        String location;
        if (barangay != null &&
            barangay.isNotEmpty &&
            city != null &&
            city.isNotEmpty) {
          location = '$barangay, $city';
        } else if (city != null && city.isNotEmpty) {
          location = city;
        } else if (address != null && address.isNotEmpty) {
          // Use full address if no city available
          location = address.length > 50
              ? '${address.substring(0, 50)}...'
              : address;
        } else {
          location = 'Location not set';
        }

        // Calculate distance if both household and junkshop coordinates are available
        double distance;
        if (householdLat != null &&
            householdLng != null &&
            junkshopLat != null &&
            junkshopLng != null) {
          distance = calculateDistance(
            householdLat,
            householdLng,
            junkshopLat,
            junkshopLng,
          );
          if (kDebugMode) {
            print(
              '[Junkshops] $businessName: Real distance = ${distance.toStringAsFixed(2)} km (junkshop: $junkshopLat, $junkshopLng)',
            );
          }
        } else {
          // Use mock distance if coordinates not available
          distance = 2.5 + (junkshops.length * 1.5);
          if (kDebugMode) {
            print(
              '[Junkshops] $businessName: Mock distance = ${distance.toStringAsFixed(2)} km (missing coords: household=$householdLat,$householdLng junkshop=$junkshopLat,$junkshopLng)',
            );
          }
        }

        // Check budget availability from business settings
        bool isAvailable = true;
        String? unavailableReason;

        final settings = data['settings'] as Map<String, dynamic>?;

        // Check if business controls are configured
        bool hasBusinessControls = false;
        if (settings != null) {
          final baseFee = (settings['baseFee'] as num?)?.toDouble();
          final costPerKm = (settings['costPerKm'] as num?)?.toDouble();
          final maxWeightPerValueRatio =
              (settings['maxWeightPerValueRatio'] as num?)?.toDouble();

          // Consider configured if at least one pricing rule is set
          hasBusinessControls =
              (baseFee != null && baseFee > 0) ||
              (costPerKm != null && costPerKm > 0) ||
              (maxWeightPerValueRatio != null && maxWeightPerValueRatio > 0);

          if (kDebugMode) {
            print(
              '[Junkshops] $businessName: hasBusinessControls=$hasBusinessControls (baseFee=$baseFee, costPerKm=$costPerKm, maxRatio=$maxWeightPerValueRatio)',
            );
          }

          // Skip junkshops without business controls
          if (!hasBusinessControls) {
            if (kDebugMode) {
              print(
                '[Junkshops] Skipping $businessName - No business controls configured',
              );
            }
            continue;
          }

          final budget = (settings['monthlyBudget'] as num?)?.toDouble() ?? 0.0;
          final spending =
              (settings['currentMonthSpending'] as num?)?.toDouble() ?? 0.0;

          if (budget > 0 && spending >= budget) {
            isAvailable = false;
            unavailableReason = 'Budget limit reached for this month';
            if (kDebugMode) {
              print(
                '[Junkshops] $businessName: UNAVAILABLE - Budget exhausted ($spending/$budget)',
              );
            }
          }
        } else {
          // No settings at all - skip this junkshop
          if (kDebugMode) {
            print(
              '[Junkshops] Skipping $businessName - No settings configured',
            );
          }
          continue;
        }

        if (kDebugMode) {
          print('[Junkshops] $businessName service_radius: $serviceRadius km');
        }

        junkshops.add({
          'id': docId,
          'uid': docId, // Add uid field for consistency
          'name': businessName,
          'location': location,
          'distance': distance,
          'operationalRange': 10.0, // Mock operational range
          'serviceRadius':
              serviceRadius ?? 10.0, // Service radius from Firestore or default
          'priceMultiplier': 1.0, // Base prices for now
          'rating':
              ((data['business'] as Map<String, dynamic>?)?['rating'] as num?)
                  ?.toDouble() ??
              ((data['business'] as Map<String, dynamic>?)?['averageRating']
                      as num?)
                  ?.toDouble() ??
              (data['rating'] as num?)?.toDouble() ??
              (data['averageRating'] as num?)?.toDouble() ??
              0.0,
          'address': address,
          'lat': junkshopLat,
          'lng': junkshopLng,
          'profileImage': data[UserFields.profileImageUrl]
              ?.toString(), // Match key used in post_items_screen
          'isAvailable': isAvailable,
          'unavailableReason': unavailableReason,
          'hasBusinessControls':
              true, // Only junkshops with controls reach this point
        });
      }

      // Sort by distance (closest first)
      junkshops.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      if (kDebugMode) {
        print(
          '[Junkshops] Returning ${junkshops.length} junkshop(s), sorted by distance',
        );
      }

      return junkshops;
    } catch (e) {
      if (kDebugMode) print('Error loading junkshops from Firestore: $e');
      // Return empty list on error instead of mock data
      return [];
    }
  }

  /// Converts quantity from one unit to another
  static double convertToBaseUnit(
    double qty,
    String fromUnit,
    String baseUnit,
  ) {
    if (fromUnit == baseUnit) return qty;
    // Basic conversions: kg <-> lbs; pcs unchanged unless base is different
    if (fromUnit == 'lbs' && baseUnit == 'kg') {
      return qty * 0.453592;
    }
    if (fromUnit == 'kg' && baseUnit == 'lbs') {
      return qty / 0.453592;
    }
    // If base is 'pcs' or from is 'pcs', no conversion (assume 1:1)
    return qty;
  }

  /// Returns color based on price multiplier
  static Color getPriceColor(double priceMultiplier) {
    if (priceMultiplier > 1.0) {
      return AppColors.successColor; // Higher prices (better for seller)
    } else if (priceMultiplier < 1.0) {
      return AppColors.errorColor; // Lower prices
    } else {
      return AppColors.infoColor; // Base prices
    }
  }

  /// Returns label based on price multiplier
  static String getPriceLabel(double priceMultiplier) {
    if (priceMultiplier > 1.0) {
      final percent = ((priceMultiplier - 1.0) * 100).round();
      return '+$percent% HIGHER';
    } else if (priceMultiplier < 1.0) {
      final percent = ((1.0 - priceMultiplier) * 100).round();
      return '-$percent% LOWER';
    } else {
      return ''; // No label for base prices
    }
  }
}
