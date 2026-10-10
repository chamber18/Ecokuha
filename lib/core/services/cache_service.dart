import 'package:hive_flutter/hive_flutter.dart';

/// Local cache service using Hive for fast data retrieval
class CacheService {
  static const String _historyBox = 'history_cache';
  static const String _customersBox = 'customers_cache';
  static const String _materialsBox = 'materials_cache';
  static const String _metadataBox = 'cache_metadata';
  static const String _leaderboardBox = 'leaderboard_cache';
  static const String _overviewBox = 'overview_cache';

  /// Initialize Hive and open boxes
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_historyBox);
    await Hive.openBox(_customersBox);
    await Hive.openBox(_materialsBox);
    await Hive.openBox(_metadataBox);
    await Hive.openBox(_leaderboardBox);
    await Hive.openBox(_overviewBox);
  }

  /// Ensure a box is opened before accessing it
  Future<Box> _ensureBox(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }

  // ============ HISTORY CACHE ============

  /// Save history data with timestamp
  Future<void> saveHistory({
    required String junkshopId,
    required List<Map<String, dynamic>> purchases,
    required List<Map<String, dynamic>> sales,
  }) async {
    final box = await _ensureBox(_historyBox);
    await box.put('${junkshopId}_purchases', purchases);
    await box.put('${junkshopId}_sales', sales);
    await _updateLastSyncTime('history_$junkshopId');
  }

  /// Get cached history data
  Future<Map<String, List<Map<String, dynamic>>>?> getHistory(
    String junkshopId,
  ) async {
    final box = await _ensureBox(_historyBox);
    final purchases = box.get('${junkshopId}_purchases') as List<dynamic>?;
    final sales = box.get('${junkshopId}_sales') as List<dynamic>?;

    if (purchases == null || sales == null) return null;

    return {
      'purchases': purchases.map((e) => Map<String, dynamic>.from(e)).toList(),
      'sales': sales.map((e) => Map<String, dynamic>.from(e)).toList(),
    };
  }

  /// Get last sync timestamp for history
  Future<DateTime?> getHistoryLastSync(String junkshopId) async {
    return await _getLastSyncTime('history_$junkshopId');
  }

  /// Clear history cache
  Future<void> clearHistory(String junkshopId) async {
    final box = await _ensureBox(_historyBox);
    await box.delete('${junkshopId}_purchases');
    await box.delete('${junkshopId}_sales');
    await _clearLastSyncTime('history_$junkshopId');
  }

  // ============ CUSTOMERS CACHE ============

  /// Save customers data
  Future<void> saveCustomers({
    required String junkshopId,
    required List<Map<String, dynamic>> customers,
  }) async {
    final box = await _ensureBox(_customersBox);
    await box.put('${junkshopId}_customers', customers);
    await _updateLastSyncTime('customers_$junkshopId');
  }

  /// Get cached customers data
  Future<List<Map<String, dynamic>>?> getCustomers(String junkshopId) async {
    final box = await _ensureBox(_customersBox);
    final customers = box.get('${junkshopId}_customers') as List<dynamic>?;

    if (customers == null) return null;

    return customers.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Get last sync timestamp for customers
  Future<DateTime?> getCustomersLastSync(String junkshopId) async {
    return await _getLastSyncTime('customers_$junkshopId');
  }

  /// Clear customers cache
  Future<void> clearCustomers(String junkshopId) async {
    final box = await _ensureBox(_customersBox);
    await box.delete('${junkshopId}_customers');
    await _clearLastSyncTime('customers_$junkshopId');
  }

  // ============ MATERIALS CACHE ============

  /// Save materials data
  Future<void> saveMaterials({
    required String junkshopId,
    required Map<String, Map<String, dynamic>> materials,
  }) async {
    final box = await _ensureBox(_materialsBox);
    await box.put('${junkshopId}_materials', materials);
    await _updateLastSyncTime('materials_$junkshopId');
  }

  /// Get cached materials data
  Future<Map<String, Map<String, dynamic>>?> getMaterials(
    String junkshopId,
  ) async {
    final box = await _ensureBox(_materialsBox);
    final materials =
        box.get('${junkshopId}_materials') as Map<dynamic, dynamic>?;

    if (materials == null) return null;

    return materials.map(
      (key, value) =>
          MapEntry(key.toString(), Map<String, dynamic>.from(value)),
    );
  }

  /// Get last sync timestamp for materials
  Future<DateTime?> getMaterialsLastSync(String junkshopId) async {
    return await _getLastSyncTime('materials_$junkshopId');
  }

  /// Clear materials cache
  Future<void> clearMaterials(String junkshopId) async {
    final box = await _ensureBox(_materialsBox);
    await box.delete('${junkshopId}_materials');
    await _clearLastSyncTime('materials_$junkshopId');
  }

  // ============ LEADERBOARD CACHE ============

  /// Save leaderboard data with city filter
  Future<void> saveLeaderboard({
    required String city,
    required List<Map<String, dynamic>> topHouseholds,
    required Map<String, dynamic>? userRanking,
  }) async {
    final box = await _ensureBox(_leaderboardBox);
    await box.put('${city}_leaderboard', {
      'topHouseholds': topHouseholds,
      'userRanking': userRanking,
    });
    await _updateLastSyncTime('leaderboard_$city');
  }

  /// Get cached leaderboard data for a city
  Future<Map<String, dynamic>?> getLeaderboard(String city) async {
    final box = await _ensureBox(_leaderboardBox);
    final data = box.get('${city}_leaderboard') as Map<dynamic, dynamic>?;

    if (data == null) return null;

    return {
      'topHouseholds': (data['topHouseholds'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      'userRanking': data['userRanking'] != null
          ? Map<String, dynamic>.from(data['userRanking'])
          : null,
    };
  }

  /// Get last sync timestamp for leaderboard
  Future<DateTime?> getLeaderboardLastSync(String city) async {
    return await _getLastSyncTime('leaderboard_$city');
  }

  /// Clear leaderboard cache for a city
  Future<void> clearLeaderboard(String city) async {
    final box = await _ensureBox(_leaderboardBox);
    await box.delete('${city}_leaderboard');
    await _clearLastSyncTime('leaderboard_$city');
  }

  // ============ OVERVIEW CACHE ============

  /// Save overview data with timestamp
  Future<void> saveOverviewData({
    required String junkshopId,
    required Map<String, dynamic> data,
  }) async {
    final box = await _ensureBox(_overviewBox);
    await box.put(junkshopId, data);
    await _updateLastSyncTime('overview_$junkshopId');
  }

  /// Get cached overview data
  Future<Map<String, dynamic>?> getOverviewData(String junkshopId) async {
    final box = await _ensureBox(_overviewBox);
    final data = box.get(junkshopId);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  /// Get last sync timestamp for overview
  Future<DateTime?> getOverviewLastSync(String junkshopId) async {
    return await _getLastSyncTime('overview_$junkshopId');
  }

  /// Clear overview cache
  Future<void> clearOverview(String junkshopId) async {
    final box = await _ensureBox(_overviewBox);
    await box.delete(junkshopId);
    await _clearLastSyncTime('overview_$junkshopId');
  }

  // ============ METADATA HELPERS ============

  /// Update last sync timestamp
  Future<void> _updateLastSyncTime(String key) async {
    final box = await _ensureBox(_metadataBox);
    await box.put('${key}_lastSync', DateTime.now().toIso8601String());
  }

  /// Get last sync timestamp
  Future<DateTime?> _getLastSyncTime(String key) async {
    final box = await _ensureBox(_metadataBox);
    final timestamp = box.get('${key}_lastSync') as String?;
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  /// Clear last sync timestamp
  Future<void> _clearLastSyncTime(String key) async {
    final box = await _ensureBox(_metadataBox);
    await box.delete('${key}_lastSync');
  }

  /// Check if cache is stale (older than 24 hours)
  Future<bool> isCacheStale(
    String key, {
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final lastSync = await _getLastSyncTime(key);
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > maxAge;
  }

  // ============ MATERIAL ANALYTICS CACHE ============

  /// Save material analytics data
  Future<void> saveMaterialAnalytics({
    required String junkshopId,
    required List<Map<String, dynamic>> materials,
  }) async {
    final box = await _ensureBox(_materialsBox);
    await box.put('${junkshopId}_analytics', materials);
    await _updateLastSyncTime('analytics_$junkshopId');
  }

  /// Get cached material analytics data
  Future<List<Map<String, dynamic>>?> getMaterialAnalytics(
    String junkshopId,
  ) async {
    final box = await _ensureBox(_materialsBox);
    final data = box.get('${junkshopId}_analytics') as List<dynamic>?;

    if (data == null) return null;

    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Get last sync timestamp for material analytics
  Future<DateTime?> getMaterialAnalyticsLastSync(String junkshopId) async {
    return await _getLastSyncTime('analytics_$junkshopId');
  }

  /// Clear material analytics cache
  Future<void> clearMaterialAnalytics(String junkshopId) async {
    final box = await _ensureBox(_materialsBox);
    await box.delete('${junkshopId}_analytics');
    await _clearLastSyncTime('analytics_$junkshopId');
  }

  // ============ CLEAR ALL ============

  /// Clear all caches for a junkshop
  Future<void> clearAllCaches(String junkshopId) async {
    await clearHistory(junkshopId);
    await clearCustomers(junkshopId);
    await clearMaterials(junkshopId);
    await clearMaterialAnalytics(junkshopId);
  }

  /// Clear all caches globally
  static Future<void> clearAll() async {
    if (Hive.isBoxOpen(_historyBox)) await Hive.box(_historyBox).clear();
    if (Hive.isBoxOpen(_customersBox)) await Hive.box(_customersBox).clear();
    if (Hive.isBoxOpen(_materialsBox)) await Hive.box(_materialsBox).clear();
    if (Hive.isBoxOpen(_metadataBox)) await Hive.box(_metadataBox).clear();
    if (Hive.isBoxOpen(_leaderboardBox)) {
      await Hive.box(_leaderboardBox).clear();
    }
  }
}
