import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'carbon_factors_service.dart';

/// Enhanced carbon calculation service with detailed reporting
///
/// Provides scientifically-backed carbon savings calculations with
/// material-specific emission factors, confidence levels, and equivalents
class CarbonCalculatorService {
  final SupabaseClient _db;
  final CarbonFactorsService _factorsService;

  CarbonCalculatorService({
    SupabaseClient? supabase,
    CarbonFactorsService? factorsService,
  }) : _db = supabase ?? Supabase.instance.client,
       _factorsService = factorsService ?? CarbonFactorsService.instance;

  /// Calculate carbon saved from a single posting
  double calculateCarbonFromPosting(Map<String, dynamic> postingData) {
    double totalCarbon = 0.0;

    final items = _extractItems(postingData);

    for (final item in items) {
      final category =
          item['itemName'] as String? ??
          item['category'] as String? ??
          item['name'] as String? ??
          'Other';
      final weight = _extractWeight(item);

      if (weight > 0) {
        final factor = _factorsService.getFactorForMaterial(category);
        totalCarbon += weight * factor;
      }
    }

    return totalCarbon;
  }

  /// Calculate total carbon savings for a user with detailed breakdown
  Future<CarbonSavingsReport> calculateTotalCarbon({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _db
        .from('postings')
        .select()
        .eq('household_id', userId)
        .eq('status', 'completed');

    if (startDate != null) {
      query = query.gte('completed_at', startDate.toUtc().toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('completed_at', endDate.toUtc().toIso8601String());
    }

    final rows = rowsToDocs('postings', await query);
    double totalCarbon = 0.0;
    final Map<String, MaterialCarbonData> breakdown = {};
    int totalCollections = rows.length;

    for (final data in rows) {
      final items = _extractItems(data);

      for (final item in items) {
        final category =
            item['itemName'] as String? ??
            item['category'] as String? ??
            item['name'] as String? ??
            'Other';
        final weight = _extractWeight(item);

        if (weight > 0) {
          final factor = _factorsService.getFactorForMaterial(category);
          final carbonSaved = weight * factor;

          totalCarbon += carbonSaved;

          if (breakdown.containsKey(category)) {
            breakdown[category] = MaterialCarbonData(
              totalWeight: breakdown[category]!.totalWeight + weight,
              totalCarbon: breakdown[category]!.totalCarbon + carbonSaved,
              carbonFactor: factor,
              itemCount: breakdown[category]!.itemCount + 1,
            );
          } else {
            breakdown[category] = MaterialCarbonData(
              totalWeight: weight,
              totalCarbon: carbonSaved,
              carbonFactor: factor,
              itemCount: 1,
            );
          }
        }
      }
    }

    return CarbonSavingsReport(
      totalKgCO2: totalCarbon,
      breakdown: breakdown,
      totalCollections: totalCollections,
      startDate: startDate,
      endDate: endDate,
      calculatedAt: DateTime.now(),
    );
  }

  /// Convert carbon savings to relatable real-world equivalents
  CarbonEquivalents getEquivalents(double kgCO2) {
    return CarbonEquivalents(
      treesPlanted: kgCO2 / 25, // 1 tree absorbs ~25kg CO2/year
      carMilesSaved: kgCO2 / 0.404, // Average car emits 404g CO2/mile
      carKilometersSaved: kgCO2 / 0.251, // Average car emits 251g CO2/km
      homeEnergyDaysSaved: kgCO2 / 28.9, // Average home uses 28.9kg CO2/day
      plasticBottlesSaved: kgCO2 / 0.082, // 1 plastic bottle = 82g CO2
      phoneChargesSaved: kgCO2 / 0.008, // 1 phone charge = 8g CO2
      lightbulbHoursSaved: kgCO2 / 0.06, // 1 hour LED bulb = 60g CO2
    );
  }

  /// Extract items from posting data (handles multiple formats)
  List<Map<String, dynamic>> _extractItems(Map<String, dynamic> postingData) {
    // Priority 1: Check purchasedItems.list (final junkshop items)
    if (postingData['purchasedItems'] is Map<String, dynamic>) {
      final purchasedItems =
          postingData['purchasedItems'] as Map<String, dynamic>;
      if (purchasedItems['list'] is List) {
        return List<Map<String, dynamic>>.from(purchasedItems['list']);
      }
    }

    // Priority 2: Check verifiedItems (collector verified)
    if (postingData['verifiedItems'] is Map<String, dynamic>) {
      final verifiedItems =
          postingData['verifiedItems'] as Map<String, dynamic>;
      if (verifiedItems['items'] is List) {
        return List<Map<String, dynamic>>.from(verifiedItems['items']);
      } else if (verifiedItems['itemsList'] is List) {
        return List<Map<String, dynamic>>.from(verifiedItems['itemsList']);
      }
    }

    // Priority 3: Check direct items field (household posting)
    if (postingData['items'] is List) {
      return List<Map<String, dynamic>>.from(postingData['items']);
    } else if (postingData['items'] is Map && postingData['items']['list'] is List) {
      return List<Map<String, dynamic>>.from(postingData['items']['list']);
    }

    return [];
  }

  /// Extract weight from item (handles String and num types)
  double _extractWeight(Map<String, dynamic> item) {
    // Check multiple field names for compatibility - SAME ORDER AS HOME SCREEN
    // Priority 1: itemWeightKg (standard field)
    final weightValue =
        item['itemWeightKg'] ??
        item['itemQuantity'] ??
        item['weightKg'] ??
        item['weight'] ??
        item['quantity'];

    if (weightValue is num) {
      return weightValue.toDouble();
    } else if (weightValue is String) {
      return double.tryParse(weightValue) ?? 0.0;
    }

    return 0.0;
  }
}

/// Represents carbon data for a specific material
class MaterialCarbonData {
  final double totalWeight;
  final double totalCarbon;
  final double carbonFactor;
  final int itemCount;

  MaterialCarbonData({
    required this.totalWeight,
    required this.totalCarbon,
    required this.carbonFactor,
    required this.itemCount,
  });

  double get averageWeight => totalWeight / itemCount;
}

/// Complete carbon savings report with breakdown
class CarbonSavingsReport {
  final double totalKgCO2;
  final Map<String, MaterialCarbonData> breakdown;
  final int totalCollections;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime calculatedAt;

  CarbonSavingsReport({
    required this.totalKgCO2,
    required this.breakdown,
    required this.totalCollections,
    this.startDate,
    this.endDate,
    required this.calculatedAt,
  });

  /// Get top materials by carbon impact
  List<MapEntry<String, MaterialCarbonData>> getTopMaterials({int limit = 5}) {
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.totalCarbon.compareTo(a.value.totalCarbon));
    return sorted.take(limit).toList();
  }
}

/// Real-world equivalents for carbon savings
class CarbonEquivalents {
  final double treesPlanted;
  final double carMilesSaved;
  final double carKilometersSaved;
  final double homeEnergyDaysSaved;
  final double plasticBottlesSaved;
  final double phoneChargesSaved;
  final double lightbulbHoursSaved;

  CarbonEquivalents({
    required this.treesPlanted,
    required this.carMilesSaved,
    required this.carKilometersSaved,
    required this.homeEnergyDaysSaved,
    required this.plasticBottlesSaved,
    required this.phoneChargesSaved,
    required this.lightbulbHoursSaved,
  });
}
