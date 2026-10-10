import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Service to query and format junkshop business data for AI chat
class JunkshopDataService {
  final SupabaseClient _db;

  JunkshopDataService({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;

  /// Signed-in junkshop (null when signed out).
  ({String uid})? get _currentUser {
    final id = currentUid;
    return id == null ? null : (uid: id);
  }

  /// Rows of [table] owned by [junkshopId] as legacy-shaped docs.
  Future<_Snap> _q(
    String table,
    String junkshopId, {
    DateTime? from,
    DateTime? to,
    Map<String, Object>? eq,
    String? orderBy,
    bool desc = false,
  }) async {
    var query = _db.from(table).select().eq('junkshop_id', junkshopId);
    if (from != null) {
      query = query.gte('created_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lte('created_at', to.toUtc().toIso8601String());
    }
    eq?.forEach((k, v) => query = query.eq(k, v));
    final rows = orderBy != null
        ? await query.order(orderBy, ascending: !desc)
        : await query;
    return _Snap(_toDocs(table, rows));
  }

  dynamic _purchasedAtRaw(Map<String, dynamic> data) {
    final p = data['purchasedItems'];
    return p is Map ? p['purchasedAt'] : null;
  }

  List? _purchasedList(Map<String, dynamic> data) {
    final p = data['purchasedItems'];
    if (p is Map) return p['list'] as List?;
    return p is List ? p : null;
  }

  /// Postings of this junkshop with one of [statuses].
  Future<_Snap> _postings(String junkshopId, List<String> statuses) async {
    final rows = await _db
        .from('postings')
        .select()
        .eq('junkshop_id', junkshopId)
        .inFilter('status', statuses);
    return _Snap(_toDocs('postings', rows));
  }

  List<_Doc> _toDocs(String table, List<dynamic> rows) {
    return rowsToDocs(table, rows).map((d) {
      if (table == 'purchases') {
        // legacy field aliases used by the report code
        d['date'] = d['createdAt'];
        d['timestamp'] = d['createdAt'];
        d['purchasedAt'] = d['createdAt'];
        d['totalPrice'] ??= d['totalAmount'];
      } else if (table == 'postings') {
        final collector = d['collector'];
        if (collector is Map) {
          d['collectorName'] ??= collector['full_name'] ?? collector['name'];
        }
      }
      return _Doc(d);
    }).toList();
  }

  /// Get today's sales summary
  Future<Map<String, dynamic>> getSalesToday() async {
    try {
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final salesSnapshot = await _q('sales', user.uid, from: startOfDay);

      double totalAmount = 0;
      int transactionCount = 0;
      final List<Map<String, dynamic>> transactions = [];

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalAmount += amount;
        transactionCount++;

        transactions.add({
          'amount': amount,
          'buyer': data['buyer'] ?? 'Unknown',
          'items': data['verifiedItems'] ?? data['items'] ?? [],
          'time': (data['createdAt'] as Timestamp?)?.toDate().toString() ?? '',
        });
      }

      return {
        'totalAmount': totalAmount,
        'transactionCount': transactionCount,
        'transactions': transactions,
        'date': DateFormat('MMMM d, yyyy').format(now),
      };
    } catch (e) {
      return {'error': 'Failed to fetch sales data: $e'};
    }
  }

  /// Get sales for a specific time period
  Future<Map<String, dynamic>> getSalesForPeriod(int days) async {
    try {
      if (kDebugMode) print('💰 getSalesForPeriod: Starting (days=$days)...');
      final user = _currentUser;
      if (user == null) {
        if (kDebugMode) print('❌ getSalesForPeriod: User not authenticated');
        return {'error': 'User not authenticated'};
      }
      if (kDebugMode) {
        print('✅ getSalesForPeriod: User authenticated: ${user.uid}');
      }

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days - 1));
      final startOfDay = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );

      final salesSnapshot = await _q('sales', user.uid, from: startOfDay);

      double totalAmount = 0;
      int transactionCount = 0;
      final Map<String, double> byDay = {};

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        totalAmount += amount;
        transactionCount++;

        if (createdAt != null) {
          final dayKey = DateFormat('yyyy-MM-dd').format(createdAt);
          byDay[dayKey] = (byDay[dayKey] ?? 0.0) + amount;
        }
      }

      return {
        'totalAmount': totalAmount,
        'transactionCount': transactionCount,
        'averagePerDay': transactionCount > 0 ? totalAmount / days : 0.0,
        'byDay': byDay,
        'period': '$days days',
      };
    } catch (e) {
      return {'error': 'Failed to fetch sales data: $e'};
    }
  }

  /// Get sales and materials sold for a specific date
  Future<Map<String, dynamic>> getSalesByDate(String dateStr) async {
    try {
      if (kDebugMode) print('📅 getSalesByDate: Starting (date=$dateStr)...');
      final user = _currentUser;
      if (user == null) {
        if (kDebugMode) print('❌ getSalesByDate: User not authenticated');
        return {'error': 'User not authenticated'};
      }

      // Parse the date string
      DateTime targetDate;
      try {
        targetDate = DateTime.parse(dateStr);
      } catch (e) {
        return {
          'error': 'Invalid date format. Use YYYY-MM-DD (e.g., 2025-12-01)',
        };
      }

      // Get start and end of the target day
      final startOfDay = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      final endOfDay = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        23,
        59,
        59,
      );

      // Query Sales collection for this specific date
      final salesSnapshot = await _q('sales', user.uid, from: startOfDay, to: endOfDay);

      double totalAmount = 0;
      int transactionCount = 0;
      final Map<String, Map<String, dynamic>> materialsSold = {};

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final items = data['items'] as List<dynamic>? ?? [];

        totalAmount += amount;
        transactionCount++;

        // Process each material sold in this transaction
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final materialName =
                item['material'] as String? ??
                item['name'] as String? ??
                'Unknown';
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            final price =
                (item['pricePerUnit'] as num?)?.toDouble() ??
                (item['price'] as num?)?.toDouble() ??
                0.0;
            final subtotal =
                (item['subtotal'] as num?)?.toDouble() ?? (quantity * price);

            if (materialsSold.containsKey(materialName)) {
              materialsSold[materialName]!['quantity'] =
                  (materialsSold[materialName]!['quantity'] as double) +
                  quantity;
              materialsSold[materialName]!['totalValue'] =
                  (materialsSold[materialName]!['totalValue'] as double) +
                  subtotal;
            } else {
              materialsSold[materialName] = {
                'material': materialName,
                'quantity': quantity,
                'totalValue': subtotal,
                'averagePrice': price,
              };
            }
          }
        }
      }

      // Convert map to list and sort by value
      final materialsList = materialsSold.values.toList()
        ..sort(
          (a, b) =>
              (b['totalValue'] as double).compareTo(a['totalValue'] as double),
        );

      return {
        'date': DateFormat('yyyy-MM-dd').format(targetDate),
        'totalAmount': totalAmount,
        'transactionCount': transactionCount,
        'materialsSold': materialsList,
        'materialsCount': materialsList.length,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getSalesByDate error: $e');
      return {'error': 'Failed to fetch sales data for date: $e'};
    }
  }

  /// Get individual transaction details for a specific date
  Future<Map<String, dynamic>> getTransactionsByDate(String dateStr) async {
    try {
      if (kDebugMode) {
        print('📋 getTransactionsByDate: Starting (date=$dateStr)...');
      }
      final user = _currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('❌ getTransactionsByDate: User not authenticated');
        }
        return {'error': 'User not authenticated'};
      }

      // Parse the date string
      DateTime targetDate;
      try {
        targetDate = DateTime.parse(dateStr);
      } catch (e) {
        return {
          'error': 'Invalid date format. Use YYYY-MM-DD (e.g., 2025-12-01)',
        };
      }

      // Get start and end of the target day
      final startOfDay = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      final endOfDay = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        23,
        59,
        59,
      );

      // Query Sales collection for this specific date
      final salesSnapshot = await _q('sales', user.uid, from: startOfDay, to: endOfDay, orderBy: 'created_at', desc: true);

      double totalAmount = 0;
      final List<Map<String, dynamic>> transactions = [];

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final items = data['items'] as List<dynamic>? ?? [];
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final customerName =
            data['customerName'] as String? ??
            data['buyer'] as String? ??
            'Unknown Customer';
        final transactionId = doc.id;

        totalAmount += amount;

        // Format items for this transaction
        final transactionItems = items
            .map((item) {
              if (item is Map<String, dynamic>) {
                return {
                  'material':
                      item['material'] as String? ??
                      item['name'] as String? ??
                      'Unknown',
                  'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
                  'price':
                      (item['pricePerUnit'] as num?)?.toDouble() ??
                      (item['price'] as num?)?.toDouble() ??
                      0.0,
                  'subtotal': (item['subtotal'] as num?)?.toDouble() ?? 0.0,
                };
              }
              return null;
            })
            .where((item) => item != null)
            .toList();

        transactions.add({
          'transactionId': transactionId,
          'customerName': customerName,
          'totalAmount': amount,
          'items': transactionItems,
          'itemCount': transactionItems.length,
          'timestamp': createdAt != null
              ? DateFormat('HH:mm:ss').format(createdAt)
              : 'Unknown',
        });
      }

      return {
        'date': DateFormat('yyyy-MM-dd').format(targetDate),
        'totalAmount': totalAmount,
        'transactionCount': transactions.length,
        'transactions': transactions,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getTransactionsByDate error: $e');
      return {'error': 'Failed to fetch transaction details for date: $e'};
    }
  }

  /// Get inventory status (low stock materials)
  Future<Map<String, dynamic>> getInventoryStatus() async {
    try {
      if (kDebugMode) print('📦 getInventoryStatus: Starting...');
      final user = _currentUser;
      if (user == null) {
        if (kDebugMode) print('❌ getInventoryStatus: User not authenticated');
        return {'error': 'User not authenticated'};
      }
      if (kDebugMode) {
        print('✅ getInventoryStatus: User authenticated: ${user.uid}');
      }

      final inventorySnapshot = await _q('junkshop_materials', user.uid);

      final List<Map<String, dynamic>> allMaterials = [];
      final List<Map<String, dynamic>> lowStock = [];
      double totalValue = 0;

      for (final doc in inventorySnapshot.docs) {
        final data = doc.data();
        final stock = (data['stock'] as num?)?.toDouble() ?? 0.0;
        // Use priceMax as the selling price for value calculation
        final priceMax = (data['priceMax'] as num?)?.toDouble() ?? 0.0;
        final priceMin = (data['priceMin'] as num?)?.toDouble() ?? 0.0;
        final material = data['name'] ?? doc.id;
        final unit = data['unit'] ?? 'kg';
        final category = data['category'] ?? 'others';
        final lowStockThreshold =
            (data['lowStockThreshold'] as num?)?.toDouble() ?? 10.0;
        final isActive = data['isActive'] ?? true;

        final value = stock * priceMax; // Use max price for inventory value
        totalValue += value;

        final materialData = {
          'material': material,
          'stock': stock,
          'priceMin': priceMin,
          'priceMax': priceMax,
          'value': value,
          'unit': unit,
          'category': category,
          'lowStockThreshold': lowStockThreshold,
          'isActive': isActive,
        };

        allMaterials.add(materialData);

        if (stock < lowStockThreshold && isActive) {
          lowStock.add(materialData);
        }
      }

      // Sort by stock level (ascending)
      lowStock.sort(
        (a, b) => (a['stock'] as double).compareTo(b['stock'] as double),
      );

      final result = {
        'totalMaterials': allMaterials.length,
        'totalValue': totalValue,
        'lowStockCount': lowStock.length,
        'lowStockMaterials': lowStock,
        'allMaterials': allMaterials,
      };
      if (kDebugMode) {
        print(
          '✅ getInventoryStatus: Success - ${allMaterials.length} materials, value: ₱$totalValue',
        );
      }
      return result;
    } catch (e) {
      if (kDebugMode) print('❌ getInventoryStatus: Error - $e');
      return {'error': 'Failed to fetch inventory data: $e'};
    }
  }

  /// Get total inventory value (using average purchase price like the dashboard)
  Future<Map<String, dynamic>> getInventoryValue() async {
    try {
      if (kDebugMode) print('💰 getInventoryValue: Starting...');
      final user = _currentUser;
      if (user == null) {
        if (kDebugMode) print('❌ getInventoryValue: User not authenticated');
        return {'error': 'User not authenticated'};
      }

      // Get all materials
      final materialsSnapshot = await _q('junkshop_materials', user.uid);

      // Get all purchases to calculate average purchase prices
      final purchasesSnapshot = await _q('purchases', user.uid);

      // Build a map of material name → list of purchase prices
      final Map<String, List<double>> materialPurchasePrices = {};
      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        if (data['items'] != null && data['items'] is List) {
          for (final item in data['items']) {
            final materialName = item['material'] as String? ?? '';
            final pricePerUnit = (item['pricePerUnit'] as num?)?.toDouble();
            if (materialName.isNotEmpty &&
                pricePerUnit != null &&
                pricePerUnit > 0) {
              materialPurchasePrices.putIfAbsent(materialName, () => []);
              materialPurchasePrices[materialName]!.add(pricePerUnit);
            }
          }
        }
      }

      // Calculate total inventory value using average purchase price
      double totalValue = 0.0;
      final List<Map<String, dynamic>> materials = [];

      for (final doc in materialsSnapshot.docs) {
        final data = doc.data();
        final materialName = data['name'] as String? ?? 'Unknown';
        final stock = (data['stock'] as num?)?.toDouble() ?? 0.0;

        if (stock <= 0) continue; // Skip materials with no stock

        // Calculate average purchase price from actual purchases
        double avgPurchasePrice = 0.0;
        if (materialPurchasePrices.containsKey(materialName) &&
            materialPurchasePrices[materialName]!.isNotEmpty) {
          final prices = materialPurchasePrices[materialName]!;
          avgPurchasePrice = prices.reduce((a, b) => a + b) / prices.length;
        } else {
          // Fallback: use stored avgPurchaseCost or selling price average
          final avgPurchaseCost = (data['avgPurchaseCost'] as num?)?.toDouble();
          final priceMin = (data['priceMin'] as num?)?.toDouble() ?? 0.0;
          final priceMax = (data['priceMax'] as num?)?.toDouble() ?? 0.0;
          avgPurchasePrice =
              avgPurchaseCost ??
              (priceMin > 0 ? (priceMin + priceMax) / 2 : priceMax);
        }

        final itemValue = stock * avgPurchasePrice;
        totalValue += itemValue;

        materials.add({
          'material': materialName,
          'stock': stock,
          'avgPurchasePrice': avgPurchasePrice,
          'value': itemValue,
          'unit': data['unit'] ?? 'kg',
        });
      }

      if (kDebugMode) {
        print(
          '✅ getInventoryValue: Total value = ₱${totalValue.toStringAsFixed(2)} from ${materials.length} materials',
        );
      }

      return {
        'totalValue': totalValue,
        'totalMaterials': materials.length,
        'materials': materials,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getInventoryValue: Error - $e');
      return {'error': 'Failed to calculate inventory value: $e'};
    }
  }

  /// Get top materials by quantity or value
  Future<Map<String, dynamic>> getTopMaterials({
    required int period,
    int limit = 5,
    String sortBy = 'quantity',
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📊 getTopMaterials: Starting (period=$period, limit=$limit, sortBy=$sortBy)...',
        );
      }
      final user = _currentUser;
      if (user == null) {
        if (kDebugMode) print('❌ getTopMaterials: User not authenticated');
        return {'error': 'User not authenticated'};
      }
      if (kDebugMode) {
        print('✅ getTopMaterials: User authenticated: ${user.uid}');
      }

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: period - 1));
      final startOfDay = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );

      // Aggregate from both Purchase collection and postings
      final Map<String, Map<String, dynamic>> materialStats = {};

      // Load purchases (manual entry)
      final purchasesSnapshot = await _q('purchases', user.uid, from: startOfDay);

      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final materialType = data['materialType'] ?? 'Unknown';
        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
        final totalPrice = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;

        if (!materialStats.containsKey(materialType)) {
          materialStats[materialType] = {
            'material': materialType,
            'quantity': 0.0,
            'value': 0.0,
            'transactions': 0,
          };
        }

        materialStats[materialType]!['quantity'] =
            (materialStats[materialType]!['quantity'] as double) + quantity;
        materialStats[materialType]!['value'] =
            (materialStats[materialType]!['value'] as double) + totalPrice;
        materialStats[materialType]!['transactions'] =
            (materialStats[materialType]!['transactions'] as int) + 1;
      }

      // Load postings (household collections) - dual query strategy
      final postingsSnapshot1 = await _postings(user.uid, ['completed']);

      final postingsSnapshot2 = await Future.value(const _Snap([]));

      // Combine and deduplicate
      final Map<String, _Doc> allPostings =
          {};
      for (var doc in postingsSnapshot1.docs) {
        allPostings[doc.id] = doc;
      }
      for (var doc in postingsSnapshot2.docs) {
        allPostings[doc.id] = doc;
      }

      for (final entry in allPostings.entries) {
        final data = entry.value.data();

        // Get purchasedAt from purchasedItems Map
        final purchasedAt = (data['purchasedItems'] is Map)
            ? toDateTime(data['purchasedItems']['purchasedAt'])
            : null;

        if (purchasedAt != null && purchasedAt.isAfter(startOfDay)) {
          // Extract items from purchasedItems.list
          final purchasedItemsRaw = data['purchasedItems'];
          List<dynamic> items = [];

          if (purchasedItemsRaw is Map && purchasedItemsRaw['list'] is List) {
            items = purchasedItemsRaw['list'] as List<dynamic>;
          } else if (purchasedItemsRaw is List) {
            items = purchasedItemsRaw;
          }

          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final materialType = item['name'] ?? 'Unknown';

              final quantityValue = item['quantity'];
              final quantity = quantityValue is num
                  ? quantityValue.toDouble()
                  : (quantityValue is String
                        ? double.tryParse(quantityValue) ?? 0.0
                        : 0.0);

              final priceValue = item['junkshopPricePerUnit'];
              final price = priceValue is num
                  ? priceValue.toDouble()
                  : (priceValue is String
                        ? double.tryParse(priceValue) ?? 0.0
                        : 0.0);

              final value = quantity * price;

              if (!materialStats.containsKey(materialType)) {
                materialStats[materialType] = {
                  'material': materialType,
                  'quantity': 0.0,
                  'value': 0.0,
                  'transactions': 0,
                };
              }

              materialStats[materialType]!['quantity'] =
                  (materialStats[materialType]!['quantity'] as double) +
                  quantity;
              materialStats[materialType]!['value'] =
                  (materialStats[materialType]!['value'] as double) + value;
              materialStats[materialType]!['transactions'] =
                  (materialStats[materialType]!['transactions'] as int) + 1;
            }
          }
        }
      }

      // Convert to list and sort
      final materialList = materialStats.values.toList();

      if (sortBy == 'value') {
        materialList.sort(
          (a, b) => (b['value'] as double).compareTo(a['value'] as double),
        );
      } else {
        materialList.sort(
          (a, b) =>
              (b['quantity'] as double).compareTo(a['quantity'] as double),
        );
      }

      final topMaterials = materialList.take(limit).toList();

      return {
        'topMaterials': topMaterials,
        'period': '$period days',
        'totalMaterialTypes': materialStats.length,
        'sortedBy': sortBy,
      };
    } catch (e) {
      return {'error': 'Failed to fetch top materials: $e'};
    }
  }

  /// Get collections/pickups count for today
  Future<Map<String, dynamic>> getCollectionsToday() async {
    try {
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Dual query strategy for postings
      final postingsSnapshot1 = await _postings(user.uid, ['completed']);

      final postingsSnapshot2 = await Future.value(const _Snap([]));

      // Combine and deduplicate
      final Map<String, _Doc> allPostings =
          {};
      for (var doc in postingsSnapshot1.docs) {
        allPostings[doc.id] = doc;
      }
      for (var doc in postingsSnapshot2.docs) {
        allPostings[doc.id] = doc;
      }

      int todayCount = 0;
      double todayValue = 0;

      for (final entry in allPostings.entries) {
        final data = entry.value.data();

        // Get purchasedAt from purchasedItems Map
        final purchasedAt = (data['purchasedItems'] is Map)
            ? toDateTime(data['purchasedItems']['purchasedAt'])
            : null;

        if (purchasedAt != null && purchasedAt.isAfter(startOfDay)) {
          todayCount++;

          // Calculate value from purchasedItems
          final purchasedItemsRaw = data['purchasedItems'];
          if (purchasedItemsRaw is Map && purchasedItemsRaw['list'] is List) {
            final items = purchasedItemsRaw['list'] as List<dynamic>;
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                final quantityValue = item['quantity'];
                final quantity = quantityValue is num
                    ? quantityValue.toDouble()
                    : (quantityValue is String
                          ? double.tryParse(quantityValue) ?? 0.0
                          : 0.0);

                final priceValue = item['junkshopPricePerUnit'];
                final price = priceValue is num
                    ? priceValue.toDouble()
                    : (priceValue is String
                          ? double.tryParse(priceValue) ?? 0.0
                          : 0.0);

                todayValue += quantity * price;
              }
            }
          }
        }
      }

      return {
        'count': todayCount,
        'totalValue': todayValue,
        'date': DateFormat('MMMM d, yyyy').format(now),
      };
    } catch (e) {
      return {'error': 'Failed to fetch collections data: $e'};
    }
  }

  /// Get dashboard summary (all key metrics)
  Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final salesToday = await getSalesToday();
      final collectionsToday = await getCollectionsToday();
      final inventoryStatus = await getInventoryStatus();

      return {
        'salesToday': salesToday,
        'collectionsToday': collectionsToday,
        'inventory': inventoryStatus,
        'timestamp': DateTime.now().toString(),
      };
    } catch (e) {
      return {'error': 'Failed to fetch dashboard summary: $e'};
    }
  }

  /// Get today's purchases (manual onsite collections)
  Future<Map<String, dynamic>> getPurchasesToday() async {
    try {
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      double totalAmount = 0;
      int transactionCount = 0;
      final Map<String, double> materialBreakdown = {};

      // Get purchases from Purchase collection
      final purchasesSnapshot = await _q('purchases', user.uid);

      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final purchaseDate = (data['date'] as Timestamp?)?.toDate();

        if (purchaseDate != null && purchaseDate.isAfter(startOfDay)) {
          final amount = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
          totalAmount += amount;
          transactionCount++;

          // Aggregate by material - handle items as Map or List
          final itemsData = data['items'];
          List<dynamic> items = [];

          if (itemsData is List) {
            items = itemsData;
          } else if (itemsData is Map) {
            items = itemsData.values.toList();
          }

          for (final item in items) {
            if (item is Map) {
              final material =
                  item['material'] as String? ??
                  item['name'] as String? ??
                  'Unknown';
              final itemAmount =
                  (item['total'] as num?)?.toDouble() ??
                  (item['price'] as num?)?.toDouble() ??
                  0.0;
              materialBreakdown[material] =
                  (materialBreakdown[material] ?? 0.0) + itemAmount;
            }
          }
        }
      }

      // Get postings (household collections) - dual query strategy
      final postingsSnapshot1 = await _postings(user.uid, ['completed']);

      final postingsSnapshot2 = await Future.value(const _Snap([]));

      // Combine and deduplicate
      final Map<String, _Doc> allPostings =
          {};
      for (var doc in postingsSnapshot1.docs) {
        allPostings[doc.id] = doc;
      }
      for (var doc in postingsSnapshot2.docs) {
        allPostings[doc.id] = doc;
      }

      for (final entry in allPostings.entries) {
        final data = entry.value.data();

        // Get purchasedAt from purchasedItems Map
        final purchasedAt = (data['purchasedItems'] is Map)
            ? toDateTime(data['purchasedItems']['purchasedAt'])
            : null;

        if (purchasedAt != null && purchasedAt.isAfter(startOfDay)) {
          transactionCount++;

          // Get total value
          final totalVal = (data['purchasedItems'] is Map)
              ? (data['purchasedItems']['total'] as num?)?.toDouble() ?? 0.0
              : 0.0;
          totalAmount += totalVal;

          // Aggregate by material from purchasedItems.list
          final purchasedItemsRaw = data['purchasedItems'];
          if (purchasedItemsRaw is Map && purchasedItemsRaw['list'] is List) {
            final items = purchasedItemsRaw['list'] as List<dynamic>;
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                final material = item['name'] as String? ?? 'Unknown';

                final quantityValue = item['quantity'];
                final quantity = quantityValue is num
                    ? quantityValue.toDouble()
                    : (quantityValue is String
                          ? double.tryParse(quantityValue) ?? 0.0
                          : 0.0);

                final priceValue = item['junkshopPricePerUnit'];
                final price = priceValue is num
                    ? priceValue.toDouble()
                    : (priceValue is String
                          ? double.tryParse(priceValue) ?? 0.0
                          : 0.0);

                final itemAmount = quantity * price;
                materialBreakdown[material] =
                    (materialBreakdown[material] ?? 0.0) + itemAmount;
              }
            }
          }
        }
      }

      return {
        'totalAmount': totalAmount,
        'transactionCount': transactionCount,
        'materialBreakdown': materialBreakdown,
        'date': DateFormat('MMMM d, yyyy').format(now),
      };
    } catch (e) {
      return {'error': 'Failed to fetch purchases: $e'};
    }
  }

  /// Get purchases for a specific period
  Future<Map<String, dynamic>> getPurchasesForPeriod(int days) async {
    try {
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      double totalAmount = 0;
      int transactionCount = 0;
      final Map<String, double> materialBreakdown = {};
      final Map<String, int> dailyCount = {};

      // Get purchases from Purchase collection
      final purchasesSnapshot = await _q('purchases', user.uid);

      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final purchaseDate = (data['date'] as Timestamp?)?.toDate();

        if (purchaseDate != null && purchaseDate.isAfter(startDate)) {
          final amount = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
          totalAmount += amount;
          transactionCount++;

          // Track daily purchases
          final dateKey = DateFormat('MMM d').format(purchaseDate);
          dailyCount[dateKey] = (dailyCount[dateKey] ?? 0) + 1;

          // Aggregate by material - handle items as Map or List
          final itemsData = data['items'];
          List<dynamic> items = [];

          if (itemsData is List) {
            items = itemsData;
          } else if (itemsData is Map) {
            items = itemsData.values.toList();
          }

          for (final item in items) {
            if (item is Map) {
              final material =
                  item['material'] as String? ??
                  item['name'] as String? ??
                  'Unknown';
              final itemAmount =
                  (item['total'] as num?)?.toDouble() ??
                  (item['price'] as num?)?.toDouble() ??
                  0.0;
              materialBreakdown[material] =
                  (materialBreakdown[material] ?? 0.0) + itemAmount;
            }
          }
        }
      }

      // Get postings (household collections) - dual query strategy
      final postingsSnapshot1 = await _postings(user.uid, ['completed']);

      final postingsSnapshot2 = await Future.value(const _Snap([]));

      // Combine and deduplicate
      final Map<String, _Doc> allPostings =
          {};
      for (var doc in postingsSnapshot1.docs) {
        allPostings[doc.id] = doc;
      }
      for (var doc in postingsSnapshot2.docs) {
        allPostings[doc.id] = doc;
      }

      for (final entry in allPostings.entries) {
        final data = entry.value.data();

        // Get purchasedAt from purchasedItems Map
        final purchasedAt = (data['purchasedItems'] is Map)
            ? toDateTime(data['purchasedItems']['purchasedAt'])
            : null;

        if (purchasedAt != null && purchasedAt.isAfter(startDate)) {
          transactionCount++;

          // Get total value
          final totalVal = (data['purchasedItems'] is Map)
              ? (data['purchasedItems']['total'] as num?)?.toDouble() ?? 0.0
              : 0.0;
          totalAmount += totalVal;

          // Track daily purchases
          final dateKey = DateFormat('MMM d').format(purchasedAt);
          dailyCount[dateKey] = (dailyCount[dateKey] ?? 0) + 1;

          // Aggregate by material from purchasedItems.list
          final purchasedItemsRaw = data['purchasedItems'];
          if (purchasedItemsRaw is Map && purchasedItemsRaw['list'] is List) {
            final items = purchasedItemsRaw['list'] as List<dynamic>;
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                final material = item['name'] as String? ?? 'Unknown';

                final quantityValue = item['quantity'];
                final quantity = quantityValue is num
                    ? quantityValue.toDouble()
                    : (quantityValue is String
                          ? double.tryParse(quantityValue) ?? 0.0
                          : 0.0);

                final priceValue = item['junkshopPricePerUnit'];
                final price = priceValue is num
                    ? priceValue.toDouble()
                    : (priceValue is String
                          ? double.tryParse(priceValue) ?? 0.0
                          : 0.0);

                final itemAmount = quantity * price;
                materialBreakdown[material] =
                    (materialBreakdown[material] ?? 0.0) + itemAmount;
              }
            }
          }
        }
      }

      final result = {
        'totalAmount': totalAmount,
        'transactionCount': transactionCount,
        'materialBreakdown': materialBreakdown,
        'dailyCount': dailyCount,
        'period': '$days days',
        'averagePerDay': transactionCount / days,
      };
      if (kDebugMode) {
        print(
          '✅ getSalesForPeriod: Success - $transactionCount transactions, ₱$totalAmount',
        );
      }
      return result;
    } catch (e) {
      if (kDebugMode) print('❌ getSalesForPeriod: Error - $e');
      return {'error': 'Failed to fetch sales period: $e'};
    }
  }

  /// Get active collectors currently on route
  Future<Map<String, dynamic>> getActiveCollectors() async {
    try {
      if (kDebugMode) print('🚚 getActiveCollectors: Starting...');
      final user = _currentUser;
      if (user == null) {
        if (kDebugMode) print('❌ getActiveCollectors: User not authenticated');
        return {'error': 'User not authenticated'};
      }
      if (kDebugMode) {
        print('✅ getActiveCollectors: User authenticated: ${user.uid}');
      }

      // Query postings assigned to this junkshop with status 'in_progress' - dual query strategy
      final postingsSnapshot1 = await _postings(user.uid, ['in_transit', 'arrived', 'collecting']);

      final postingsSnapshot2 = await Future.value(const _Snap([]));

      // Combine and deduplicate
      final Map<String, _Doc> allPostings =
          {};
      for (var doc in postingsSnapshot1.docs) {
        allPostings[doc.id] = doc;
      }
      for (var doc in postingsSnapshot2.docs) {
        allPostings[doc.id] = doc;
      }

      final Map<String, int> collectorStats = {};
      final List<Map<String, dynamic>> activeRoutes = [];

      for (final entry in allPostings.entries) {
        final data = entry.value.data();

        final collectorId = data['collectorId'] as String?;
        final collectorName = data['collectorName'] as String? ?? 'Unknown';

        if (collectorId != null) {
          collectorStats[collectorName] =
              (collectorStats[collectorName] ?? 0) + 1;

          activeRoutes.add({
            'collectorName': collectorName,
            'location': data['location'] ?? 'Unknown',
            'status': data['status'] ?? 'in_progress',
          });
        }
      }

      final result = {
        'activeCollectors': collectorStats.length,
        'totalActivePickups': allPostings.length,
        'collectorStats': collectorStats,
        'activeRoutes': activeRoutes,
      };
      if (kDebugMode) {
        print(
          '✅ getActiveCollectors: Success - ${collectorStats.length} active, ${allPostings.length} pickups',
        );
      }
      return result;
    } catch (e) {
      if (kDebugMode) print('❌ getActiveCollectors: Error - $e');
      return {'error': 'Failed to fetch active collectors: $e'};
    }
  }

  /// Get pending pickup requests
  Future<Map<String, dynamic>> getPendingPickups() async {
    try {
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      // Query postings assigned to this junkshop with status 'pending' or 'assigned' - dual query strategy
      final pendingSnapshot1 = await _postings(user.uid, ['pending', 'assigned']);

      final pendingSnapshot2 = await Future.value(const _Snap([]));

      // Combine and deduplicate
      final Map<String, _Doc> allPostings =
          {};
      for (var doc in pendingSnapshot1.docs) {
        allPostings[doc.id] = doc;
      }
      for (var doc in pendingSnapshot2.docs) {
        allPostings[doc.id] = doc;
      }

      final List<Map<String, dynamic>> pendingList = [];
      final Map<String, int> statusBreakdown = {};

      for (final entry in allPostings.entries) {
        final data = entry.value.data();

        final status = data['status'] as String? ?? 'pending';
        statusBreakdown[status] = (statusBreakdown[status] ?? 0) + 1;

        // Count items from verifiedItems or items
        int itemCount = 0;
        final itemsData = data['verifiedItems'] ?? data['items'];
        if (itemsData is List) {
          itemCount = itemsData.length;
        } else if (itemsData is Map) {
          itemCount = itemsData.length;
        }

        pendingList.add({
          'location': data['location'] ?? 'Unknown',
          'status': status,
          'createdAt':
              (data['createdAt'] as Timestamp?)?.toDate().toString() ?? '',
          'items': itemCount,
        });
      }

      return {
        'totalPending': allPostings.length,
        'statusBreakdown': statusBreakdown,
        'pendingPickups': pendingList,
      };
    } catch (e) {
      return {'error': 'Failed to fetch pending pickups: $e'};
    }
  }

  /// Get current material buy/sell prices
  Future<Map<String, dynamic>> getMaterialPrices() async {
    try {
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final materialsSnapshot = await _q('junkshop_materials', user.uid, eq: {'is_active': true});

      final List<Map<String, dynamic>> priceList = [];
      final Map<String, List<Map<String, dynamic>>> categoryPrices = {};

      for (final doc in materialsSnapshot.docs) {
        final data = doc.data();
        final material = data['name'] ?? doc.id;
        final category = data['category'] as String? ?? 'Other';
        final priceMin = (data['priceMin'] as num?)?.toDouble() ?? 0.0;
        final priceMax = (data['priceMax'] as num?)?.toDouble() ?? 0.0;
        final unit = data['unit'] as String? ?? 'kg';

        final priceInfo = {
          'material': material,
          'priceMin': priceMin,
          'priceMax': priceMax,
          'unit': unit,
          'priceRange': '₱$priceMin - ₱$priceMax per $unit',
        };

        priceList.add(priceInfo);

        if (!categoryPrices.containsKey(category)) {
          categoryPrices[category] = [];
        }
        categoryPrices[category]!.add(priceInfo);
      }

      return {
        'totalMaterials': materialsSnapshot.docs.length,
        'priceList': priceList,
        'categoryPrices': categoryPrices,
      };
    } catch (e) {
      return {'error': 'Failed to fetch material prices: $e'};
    }
  }

  // ==================== HIGH PRIORITY: BUYER INSIGHTS ====================

  /// Get top buyers (companies/customers who purchase materials FROM the junkshop)
  Future<Map<String, dynamic>> getTopBuyers({
    int days = 30,
    int limit = 10,
    String sortBy = 'value',
  }) async {
    try {
      if (kDebugMode) {
        print(
          '👥 getTopBuyers: Starting (days=$days, limit=$limit, sortBy=$sortBy)...',
        );
      }
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final DateTime startDate = DateTime.now().subtract(Duration(days: days));

      final salesSnapshot = await _q('sales', user.uid, from: startDate);

      final Map<String, Map<String, dynamic>> buyerStats = {};

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final buyerName =
            data['customerName'] as String? ??
            data['buyer'] as String? ??
            'Unknown Buyer';
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final items = data['items'] as List<dynamic>? ?? [];

        if (buyerStats.containsKey(buyerName)) {
          buyerStats[buyerName]!['totalValue'] =
              (buyerStats[buyerName]!['totalValue'] as double) + amount;
          buyerStats[buyerName]!['transactionCount'] =
              (buyerStats[buyerName]!['transactionCount'] as int) + 1;
          buyerStats[buyerName]!['itemCount'] =
              (buyerStats[buyerName]!['itemCount'] as int) + items.length;
        } else {
          buyerStats[buyerName] = {
            'buyerName': buyerName,
            'totalValue': amount,
            'transactionCount': 1,
            'itemCount': items.length,
          };
        }
      }

      // Calculate average transaction value
      for (final buyer in buyerStats.values) {
        buyer['averageTransactionValue'] =
            (buyer['totalValue'] as double) /
            (buyer['transactionCount'] as int);
      }

      // Sort by value or frequency
      final buyerList = buyerStats.values.toList();
      if (sortBy == 'frequency') {
        buyerList.sort(
          (a, b) => (b['transactionCount'] as int).compareTo(
            a['transactionCount'] as int,
          ),
        );
      } else {
        buyerList.sort(
          (a, b) =>
              (b['totalValue'] as double).compareTo(a['totalValue'] as double),
        );
      }

      final topBuyers = buyerList.take(limit).toList();
      final totalRevenue = buyerStats.values.fold<double>(
        0,
        (acc, c) => acc + (c['totalValue'] as double),
      );

      if (kDebugMode) {
        print('✅ getTopBuyers: Found ${topBuyers.length} top buyers');
      }
      return {
        'period': '$days days',
        'totalBuyers': buyerStats.length,
        'totalRevenue': totalRevenue,
        'topBuyers': topBuyers,
        'sortedBy': sortBy,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getTopBuyers error: $e');
      return {'error': 'Failed to fetch top buyers: $e'};
    }
  }

  /// Get transaction history for a specific buyer (company that purchases materials from junkshop)
  Future<Map<String, dynamic>> getBuyerTransactions({
    required String buyerName,
    int days = 30,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📋 getBuyerTransactions: Starting (buyer=$buyerName, days=$days)...',
        );
      }
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final DateTime startDate = DateTime.now().subtract(Duration(days: days));

      final salesSnapshot = await _q('sales', user.uid, from: startDate, orderBy: 'created_at', desc: true);

      final List<Map<String, dynamic>> transactions = [];
      double totalSpent = 0;

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final docBuyerName =
            data['customerName'] as String? ??
            data['buyer'] as String? ??
            'Unknown Buyer';

        if (docBuyerName.toLowerCase() == buyerName.toLowerCase()) {
          final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final items = data['items'] as List<dynamic>? ?? [];
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

          totalSpent += amount;

          transactions.add({
            'transactionId': doc.id,
            'date': createdAt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
                : 'Unknown',
            'totalAmount': amount,
            'itemCount': items.length,
            'items': items
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return {
                      'material':
                          item['material'] as String? ??
                          item['name'] as String? ??
                          'Unknown',
                      'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
                      'subtotal': (item['subtotal'] as num?)?.toDouble() ?? 0.0,
                    };
                  }
                  return null;
                })
                .where((item) => item != null)
                .toList(),
          });
        }
      }

      if (kDebugMode) {
        print(
          '✅ getBuyerTransactions: Found ${transactions.length} transactions',
        );
      }
      return {
        'buyerName': buyerName,
        'period': '$days days',
        'transactionCount': transactions.length,
        'totalPurchased': totalSpent,
        'averageTransaction': transactions.isNotEmpty
            ? totalSpent / transactions.length
            : 0,
        'transactions': transactions,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getBuyerTransactions error: $e');
      return {'error': 'Failed to fetch buyer transactions: $e'};
    }
  }

  // ==================== HIGH PRIORITY: MATERIAL INSIGHTS ====================

  /// Get sales trends for a specific material over time
  Future<Map<String, dynamic>> getMaterialTrends({
    required String materialName,
    int days = 30,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📈 getMaterialTrends: Starting (material=$materialName, days=$days)...',
        );
      }
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final DateTime startDate = DateTime.now().subtract(Duration(days: days));

      final salesSnapshot = await _q('sales', user.uid, from: startDate, orderBy: 'created_at');

      double totalQuantitySold = 0;
      double totalRevenue = 0;
      int transactionCount = 0;
      final Map<String, Map<String, dynamic>> dailySales = {};

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final itemMaterialName =
                item['material'] as String? ??
                item['name'] as String? ??
                'Unknown';

            if (itemMaterialName.toLowerCase() == materialName.toLowerCase()) {
              final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
              final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;

              totalQuantitySold += quantity;
              totalRevenue += subtotal;
              transactionCount++;

              if (createdAt != null) {
                final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
                if (dailySales.containsKey(dateKey)) {
                  dailySales[dateKey]!['quantity'] =
                      (dailySales[dateKey]!['quantity'] as double) + quantity;
                  dailySales[dateKey]!['revenue'] =
                      (dailySales[dateKey]!['revenue'] as double) + subtotal;
                } else {
                  dailySales[dateKey] = {
                    'date': dateKey,
                    'quantity': quantity,
                    'revenue': subtotal,
                  };
                }
              }
            }
          }
        }
      }

      final salesTrend = dailySales.values.toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      if (kDebugMode) {
        print('✅ getMaterialTrends: Found ${salesTrend.length} days of data');
      }
      return {
        'materialName': materialName,
        'period': '$days days',
        'totalQuantitySold': totalQuantitySold,
        'totalRevenue': totalRevenue,
        'transactionCount': transactionCount,
        'averagePrice': totalQuantitySold > 0
            ? totalRevenue / totalQuantitySold
            : 0,
        'dailyTrend': salesTrend,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getMaterialTrends error: $e');
      return {'error': 'Failed to fetch material trends: $e'};
    }
  }

  /// Get most profitable materials by margin
  Future<Map<String, dynamic>> getProfitableMaterials({
    int days = 30,
    int limit = 10,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '💰 getProfitableMaterials: Starting (days=$days, limit=$limit)...',
        );
      }
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final DateTime startDate = DateTime.now().subtract(Duration(days: days));

      // Get sales data
      final salesSnapshot = await _q('sales', user.uid, from: startDate);

      // Get purchase data
      final purchaseSnapshot = await _q('purchases', user.uid, from: startDate);

      final Map<String, Map<String, dynamic>> materialStats = {};

      // Process sales
      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];

        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final materialName =
                item['material'] as String? ??
                item['name'] as String? ??
                'Unknown';
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            final revenue = (item['subtotal'] as num?)?.toDouble() ?? 0.0;

            if (!materialStats.containsKey(materialName)) {
              materialStats[materialName] = {
                'materialName': materialName,
                'quantitySold': 0.0,
                'revenue': 0.0,
                'quantityPurchased': 0.0,
                'cost': 0.0,
              };
            }

            materialStats[materialName]!['quantitySold'] =
                (materialStats[materialName]!['quantitySold'] as double) +
                quantity;
            materialStats[materialName]!['revenue'] =
                (materialStats[materialName]!['revenue'] as double) + revenue;
          }
        }
      }

      // Process purchases
      for (final doc in purchaseSnapshot.docs) {
        final data = doc.data();
        final items = (data['items'] is List)
            ? data['items'] as List<dynamic>
            : (data['items'] is Map)
            ? (data['items'] as Map).values.toList()
            : [];

        for (final item in items) {
          if (item is Map) {
            final materialName =
                item['material'] as String? ??
                item['name'] as String? ??
                'Unknown';
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            final cost =
                (item['total'] as num?)?.toDouble() ??
                (item['price'] as num?)?.toDouble() ??
                0.0;

            if (!materialStats.containsKey(materialName)) {
              materialStats[materialName] = {
                'materialName': materialName,
                'quantitySold': 0.0,
                'revenue': 0.0,
                'quantityPurchased': 0.0,
                'cost': 0.0,
              };
            }

            materialStats[materialName]!['quantityPurchased'] =
                (materialStats[materialName]!['quantityPurchased'] as double) +
                quantity;
            materialStats[materialName]!['cost'] =
                (materialStats[materialName]!['cost'] as double) + cost;
          }
        }
      }

      // Calculate profit and margin
      for (final material in materialStats.values) {
        final revenue = material['revenue'] as double;
        final cost = material['cost'] as double;
        material['profit'] = revenue - cost;
        material['profitMargin'] = revenue > 0
            ? ((revenue - cost) / revenue * 100)
            : 0;
      }

      // Sort by profit
      final materialList = materialStats.values.toList()
        ..sort(
          (a, b) => (b['profit'] as double).compareTo(a['profit'] as double),
        );

      final topMaterials = materialList.take(limit).toList();

      if (kDebugMode) {
        print(
          '✅ getProfitableMaterials: Found ${topMaterials.length} materials',
        );
      }
      return {
        'period': '$days days',
        'totalMaterials': materialStats.length,
        'topMaterials': topMaterials,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getProfitableMaterials error: $e');
      return {'error': 'Failed to fetch profitable materials: $e'};
    }
  }

  // ==================== HIGH PRIORITY: COLLECTOR PERFORMANCE ====================

  /// Get performance metrics for a specific collector by name
  Future<Map<String, dynamic>> getCollectorPerformance({
    required String collectorName,
    int days = 30,
  }) async {
    try {
      if (kDebugMode) {
        print('👤 getCollectorPerformance: $collectorName (days=$days)...');
      }

      final junkshopUid = currentUid;
      if (junkshopUid == null) {
        throw Exception('No authenticated user');
      }

      // First, find the collector by name in collectors collection
      final collectorsSnapshot = _Snap(
        _toDocs(
          'collectors',
          await _db
              .from('collectors')
              .select()
              .eq('preferred_junkshop_id', junkshopUid),
        ),
      );

      String? collectorId;
      Map<String, dynamic>? collectorData;

      for (var doc in collectorsSnapshot.docs) {
        final data = doc.data();
        final collectorProfile =
            data['collector_profile'] as Map<String, dynamic>?;
        final personal = collectorProfile?['personal'] as Map<String, dynamic>?;

        // Extract name from nested personal object
        final fullName =
            personal?['full_name'] as String? ??
            data['full_name'] as String? ??
            data['name'] as String? ??
            '';

        if (fullName.toLowerCase() == collectorName.toLowerCase()) {
          // Verify this collector belongs to this junkshop
          String? preferredJunkshopId =
              data['preferred_junkshop_id'] as String?;
          preferredJunkshopId ??=
              collectorProfile?['preferred_junkshop_id'] as String?;

          if (preferredJunkshopId == junkshopUid) {
            collectorId = doc.id;
            collectorData = data;
            break;
          }
        }
      }

      if (collectorId == null) {
        return {
          'error':
              'Collector "$collectorName" not found or not assigned to this junkshop',
          'collectorName': collectorName,
        };
      }

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      // Query purchases by this collector
      final allCompleted = await _postings(junkshopUid, ['completed']);
      final snapshot = _Snap(
        allCompleted.docs.where((d) {
          final data = d.data();
          if (data['collectorId']?.toString() != collectorId) return false;
          final at = toDateTime(_purchasedAtRaw(data));
          return at != null && !at.isBefore(startDate);
        }).toList(),
      );

      int totalCollections = snapshot.docs.length;
      double totalWeight = 0.0;
      double totalEarnings = 0.0;
      DateTime? lastCollection;
      final Map<String, double> materialBreakdown = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final purchasedItems = _purchasedList(data);
        final purchasedAt = toDateTime(_purchasedAtRaw(data));

        if (purchasedAt != null) {
          if (lastCollection == null || purchasedAt.isAfter(lastCollection)) {
            lastCollection = purchasedAt;
          }
        }

        // Calculate totals from purchased items
        if (purchasedItems != null) {
          for (var item in purchasedItems) {
            if (item is! Map<String, dynamic>) continue;

            final quantity = (item['quantity'] ?? 0).toDouble();
            final pricePerUnit = (item['junkshopPricePerUnit'] ?? 0).toDouble();
            final materialName =
                item['material'] as String? ??
                item['name'] as String? ??
                'Unknown';

            totalWeight += quantity;
            totalEarnings += quantity * pricePerUnit;

            materialBreakdown[materialName] =
                (materialBreakdown[materialName] ?? 0) + quantity;
          }
        }
      }

      // Calculate averages
      final avgWeightPerCollection = totalCollections > 0
          ? totalWeight / totalCollections
          : 0.0;
      final avgEarningsPerCollection = totalCollections > 0
          ? totalEarnings / totalCollections
          : 0.0;

      // Format material breakdown
      final topMaterials =
          materialBreakdown.entries
              .map(
                (e) => {
                  'material': e.key,
                  'weight': '${e.value.toStringAsFixed(2)} kg',
                },
              )
              .toList()
            ..sort((a, b) {
              final weightA = double.parse(a['weight']!.replaceAll(' kg', ''));
              final weightB = double.parse(b['weight']!.replaceAll(' kg', ''));
              return weightB.compareTo(weightA);
            });

      // Extract from nested structure
      final collectorProfile =
          collectorData?['collector_profile'] as Map<String, dynamic>?;
      final personal = collectorProfile?['personal'] as Map<String, dynamic>?;

      final rating =
          (collectorData?['rating'] ?? collectorData?['averageRating'] ?? 0.0)
              .toDouble();
      final phone =
          personal?['phone'] as String? ??
          collectorData?['phone'] as String? ??
          'N/A';
      final status = collectorData?['status'] as String? ?? 'offline';

      if (kDebugMode) {
        print('✅ getCollectorPerformance: $totalCollections collections found');
      }

      return {
        'collectorId': collectorId,
        'collectorName': collectorName,
        'phone': phone,
        'rating': rating.toStringAsFixed(1),
        'status': status,
        'period': '$days days',
        'totalCollections': totalCollections,
        'totalWeight': '${totalWeight.toStringAsFixed(2)} kg',
        'totalEarnings': '₱${totalEarnings.toStringAsFixed(2)}',
        'avgWeightPerCollection':
            '${avgWeightPerCollection.toStringAsFixed(2)} kg',
        'avgEarningsPerCollection':
            '₱${avgEarningsPerCollection.toStringAsFixed(2)}',
        'lastCollection': lastCollection != null
            ? DateFormat('MMM d, yyyy').format(lastCollection)
            : 'Never',
        'topMaterials': topMaterials.take(5).toList(),
      };
    } catch (e) {
      if (kDebugMode) print('❌ getCollectorPerformance error: $e');
      return {'error': e.toString(), 'collectorName': collectorName};
    }
  }

  /// Get list of all collectors assigned to this junkshop
  /// The 'days' parameter only affects performance stats calculation, not which collectors are shown
  Future<Map<String, dynamic>> getAllCollectors({int days = 90}) async {
    try {
      if (kDebugMode) print('👥 getAllCollectors: Starting...');
      if (kDebugMode) {
        print('   Will show ALL approved collectors for this junkshop');
      }
      if (kDebugMode) {
        print('   Performance stats will be calculated for last $days days');
      }

      final junkshopUid = currentUid;
      if (junkshopUid == null) {
        throw Exception('No authenticated user');
      }

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      // Query collectors collection (not users!)
      final collectorsSnapshot = _Snap(
        _toDocs(
          'collectors',
          await _db
              .from('collectors')
              .select()
              .eq('preferred_junkshop_id', junkshopUid),
        ),
      );

      if (kDebugMode) {
        print(
          '🔍 Found ${collectorsSnapshot.docs.length} total collectors in database',
        );
      }
      if (kDebugMode) {
        print('   Filtering for collectors assigned to junkshop: $junkshopUid');
      }

      // Map to track unique collectors and their stats
      final Map<String, Map<String, dynamic>> collectorsMap = {};

      for (var collectorDoc in collectorsSnapshot.docs) {
        final collectorData = collectorDoc.data();
        final collectorProfile =
            collectorData['collector_profile'] as Map<String, dynamic>?;
        final personal = collectorProfile?['personal'] as Map<String, dynamic>?;

        // Check preferred_junkshop_id (can be at root or nested in collector_profile)
        String? preferredJunkshopId =
            collectorData['preferred_junkshop_id'] as String?;
        preferredJunkshopId ??=
            collectorProfile?['preferred_junkshop_id'] as String?;

        final applicationStatus =
            collectorData['application_status'] as String? ?? 'pending';

        // Only include approved collectors for this junkshop
        if (preferredJunkshopId != junkshopUid ||
            applicationStatus != 'approved') {
          continue;
        }

        final collectorId = collectorDoc.id;

        // Extract name from nested personal object
        final collectorName =
            personal?['full_name'] as String? ??
            collectorData['full_name'] as String? ??
            collectorData['name'] as String? ??
            'Unknown';

        // Extract phone from nested personal object
        final phone =
            personal?['phone'] as String? ??
            collectorData['phone'] as String? ??
            'N/A';

        final rating =
            (collectorData['rating'] ?? collectorData['averageRating'] ?? 0.0)
                .toDouble();
        final status = collectorData['status'] as String? ?? 'offline';

        // Initialize collector stats
        collectorsMap[collectorId] = {
          'id': collectorId,
          'name': collectorName,
          'phone': phone,
          'rating': rating.toStringAsFixed(1),
          'status': status,
          'totalCollections': 0,
          'totalWeight': 0.0,
          'totalValue': 0.0,
          'lastCollection': null,
        };
      }

      // Now get performance stats from Purchase collection
      final purchaseSnapshot = await _postings(junkshopUid, ['completed']);

      for (var doc in purchaseSnapshot.docs) {
        final data = doc.data();
        final collectorId = data['collectorId']?.toString();
        final purchasedItems = _purchasedList(data);
        final purchasedAt = toDateTime(_purchasedAtRaw(data));
        if (purchasedAt == null || purchasedAt.isBefore(startDate)) continue;

        if (collectorId == null || !collectorsMap.containsKey(collectorId)) {
          continue;
        }

        final stats = collectorsMap[collectorId]!;
        stats['totalCollections'] += 1;

        // Calculate weight and value from purchased items
        if (purchasedItems != null) {
          double weight = 0.0;
          double value = 0.0;

          for (var item in purchasedItems) {
            if (item is Map<String, dynamic>) {
              final qty = (item['quantity'] ?? 0).toDouble();
              final price = (item['junkshopPricePerUnit'] ?? 0).toDouble();
              weight += qty;
              value += qty * price;
            }
          }

          stats['totalWeight'] += weight;
          stats['totalValue'] += value;
        }

        // Update last collection date
        final lastDate = stats['lastCollection'] as DateTime?;
        if (lastDate == null || purchasedAt.isAfter(lastDate)) {
          stats['lastCollection'] = purchasedAt;
        }
      }

      // Convert to list and format
      final collectors = collectorsMap.values.map((stats) {
        return {
          'id': stats['id'],
          'name': stats['name'],
          'phone': stats['phone'],
          'rating': stats['rating'],
          'status': stats['status'],
          'totalCollections': stats['totalCollections'],
          'totalWeight': '${stats['totalWeight'].toStringAsFixed(2)} kg',
          'totalValue': '₱${stats['totalValue'].toStringAsFixed(2)}',
          'lastCollection': stats['lastCollection'] != null
              ? DateFormat('MMM d, yyyy').format(stats['lastCollection'])
              : 'Never',
        };
      }).toList();

      // Sort by total collections descending
      collectors.sort(
        (a, b) => (b['totalCollections'] as int).compareTo(
          a['totalCollections'] as int,
        ),
      );

      if (kDebugMode) {
        print('✅ getAllCollectors: Found ${collectors.length} collectors');
      }

      return {
        'period': '$days days',
        'totalCollectors': collectors.length,
        'collectors': collectors,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getAllCollectors error: $e');
      return {
        'error': e.toString(),
        'period': '$days days',
        'totalCollectors': 0,
        'collectors': [],
      };
    }
  }

  /// Get collector routes for a specific date
  Future<Map<String, dynamic>> getCollectorRoutes({String? date}) async {
    try {
      if (kDebugMode) print('🗺️ getCollectorRoutes: Starting (date=$date)...');
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      if (date != null) {
        try {
          DateTime.parse(date);
        } catch (e) {
          return {'error': 'Invalid date format. Use YYYY-MM-DD'};
        }
      }

      final postingsSnapshot1 = await _postings(user.uid, ['in_transit', 'arrived', 'collecting']);

      final postingsSnapshot2 = await Future.value(const _Snap([]));

      final Map<String, _Doc> allPostings =
          {};
      for (var doc in postingsSnapshot1.docs) {
        allPostings[doc.id] = doc;
      }
      for (var doc in postingsSnapshot2.docs) {
        allPostings[doc.id] = doc;
      }

      final Map<String, List<Map<String, dynamic>>> collectorRoutes = {};

      for (final entry in allPostings.entries) {
        final data = entry.value.data();

        final collectorId = data['collectorId'] as String?;
        final collectorName = data['collectorName'] as String? ?? 'Unknown';

        if (collectorId != null) {
          if (!collectorRoutes.containsKey(collectorId)) {
            collectorRoutes[collectorId] = [];
          }

          collectorRoutes[collectorId]!.add({
            'collectorName': collectorName,
            'location': data['location'] ?? 'Unknown',
            'householdName': data['householdName'] ?? 'Unknown',
            'status': data['status'] ?? 'in_progress',
            'postingId': entry.key,
          });
        }
      }

      if (kDebugMode) {
        print(
          '✅ getCollectorRoutes: Found ${collectorRoutes.length} active collectors',
        );
      }
      return {
        'date': date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'activeCollectors': collectorRoutes.length,
        'routes': collectorRoutes.entries
            .map(
              (e) => {
                'collectorId': e.key,
                'pickupCount': e.value.length,
                'pickups': e.value,
              },
            )
            .toList(),
      };
    } catch (e) {
      if (kDebugMode) print('❌ getCollectorRoutes error: $e');
      return {'error': 'Failed to fetch collector routes: $e'};
    }
  }

  // ==================== HIGH PRIORITY: COMPARATIVE ANALYTICS ====================

  /// Compare sales between two time periods
  Future<Map<String, dynamic>> comparePeriods({
    required String startDate1,
    required String endDate1,
    required String startDate2,
    required String endDate2,
  }) async {
    try {
      if (kDebugMode) print('📊 comparePeriods: Starting comparison...');
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      DateTime start1, end1, start2, end2;
      try {
        start1 = DateTime.parse(startDate1);
        end1 = DateTime.parse(endDate1);
        start2 = DateTime.parse(startDate2);
        end2 = DateTime.parse(endDate2);
      } catch (e) {
        return {'error': 'Invalid date format. Use YYYY-MM-DD'};
      }

      // Get period 1 data
      final sales1 = await _q('sales', user.uid, from: start1, to: end1);

      // Get period 2 data
      final sales2 = await _q('sales', user.uid, from: start2, to: end2);

      double revenue1 = 0, revenue2 = 0;
      int transactions1 = sales1.docs.length;
      int transactions2 = sales2.docs.length;

      for (final doc in sales1.docs) {
        revenue1 += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0.0;
      }

      for (final doc in sales2.docs) {
        revenue2 += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0.0;
      }

      final revenueChange = revenue1 > 0
          ? ((revenue2 - revenue1) / revenue1 * 100)
          : 0;
      final transactionChange = transactions1 > 0
          ? ((transactions2 - transactions1) / transactions1 * 100)
          : 0;

      if (kDebugMode) {
        print('✅ comparePeriods: Period 1: ₱$revenue1, Period 2: ₱$revenue2');
      }
      return {
        'period1': {
          'startDate': startDate1,
          'endDate': endDate1,
          'revenue': revenue1,
          'transactions': transactions1,
          'averageTransaction': transactions1 > 0
              ? revenue1 / transactions1
              : 0,
        },
        'period2': {
          'startDate': startDate2,
          'endDate': endDate2,
          'revenue': revenue2,
          'transactions': transactions2,
          'averageTransaction': transactions2 > 0
              ? revenue2 / transactions2
              : 0,
        },
        'comparison': {
          'revenueChange': revenueChange,
          'revenueChangeAmount': revenue2 - revenue1,
          'transactionChange': transactionChange,
          'transactionChangeAmount': transactions2 - transactions1,
        },
      };
    } catch (e) {
      if (kDebugMode) print('❌ comparePeriods error: $e');
      return {'error': 'Failed to compare periods: $e'};
    }
  }

  /// Smart period comparison with natural language date parsing
  /// Supports queries like:
  /// - "compare this month to last year's november"
  /// - "compare today to november 8, 2024"
  /// - "compare this week to last week"
  /// - "compare Q3 2024 to Q3 2023"
  Future<Map<String, dynamic>> comparePeriodsNatural({
    required String period1Description,
    required String period2Description,
  }) async {
    try {
      if (kDebugMode) print('🔍 comparePeriodsNatural: Parsing periods...');
      if (kDebugMode) print('   Period 1: "$period1Description"');
      if (kDebugMode) print('   Period 2: "$period2Description"');

      // Parse both periods
      final period1 = _parsePeriodDescription(period1Description);
      final period2 = _parsePeriodDescription(period2Description);

      if (period1 == null) {
        return {
          'error': 'Could not understand period 1: "$period1Description"',
        };
      }
      if (period2 == null) {
        return {
          'error': 'Could not understand period 2: "$period2Description"',
        };
      }

      if (kDebugMode) {
        print('✅ Parsed Period 1: ${period1['start']} to ${period1['end']}');
      }
      if (kDebugMode) {
        print('✅ Parsed Period 2: ${period2['start']} to ${period2['end']}');
      }

      // Use existing comparePeriods function
      return await comparePeriods(
        startDate1: period1['start']!,
        endDate1: period1['end']!,
        startDate2: period2['start']!,
        endDate2: period2['end']!,
      );
    } catch (e) {
      if (kDebugMode) print('❌ comparePeriodsNatural error: $e');
      return {'error': 'Failed to compare periods: $e'};
    }
  }

  /// Parse natural language period descriptions into date ranges
  Map<String, String>? _parsePeriodDescription(String description) {
    final now = DateTime.now();
    final desc = description.toLowerCase().trim();

    // Match specific dates: "november 8, 2024", "2024-11-08", "nov 8"
    final specificDatePattern = RegExp(
      r'(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(\d{1,2}),?\s*(\d{4})?',
      caseSensitive: false,
    );
    final isoDatePattern = RegExp(r'(\d{4})-(\d{2})-(\d{2})');

    // Match ISO date (YYYY-MM-DD)
    final isoMatch = isoDatePattern.firstMatch(desc);
    if (isoMatch != null) {
      final dateStr =
          '${isoMatch.group(1)}-${isoMatch.group(2)}-${isoMatch.group(3)}';
      return {'start': dateStr, 'end': dateStr};
    }

    // Match specific date with month name
    final dateMatch = specificDatePattern.firstMatch(desc);
    if (dateMatch != null) {
      final monthStr = dateMatch.group(1)!.substring(0, 3).toLowerCase();
      final day = int.parse(dateMatch.group(2)!);
      final year = dateMatch.group(3) != null
          ? int.parse(dateMatch.group(3)!)
          : now.year;

      final monthMap = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final month = monthMap[monthStr]!;
      final date = DateTime(year, month, day);
      final dateStr = date.toIso8601String().split('T')[0];
      return {'start': dateStr, 'end': dateStr};
    }

    // Today
    if (desc.contains('today')) {
      final dateStr = now.toIso8601String().split('T')[0];
      return {'start': dateStr, 'end': dateStr};
    }

    // Yesterday
    if (desc.contains('yesterday')) {
      final date = now.subtract(const Duration(days: 1));
      final dateStr = date.toIso8601String().split('T')[0];
      return {'start': dateStr, 'end': dateStr};
    }

    // This week
    if (desc.contains('this week')) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      return {
        'start': weekStart.toIso8601String().split('T')[0],
        'end': weekEnd.toIso8601String().split('T')[0],
      };
    }

    // Last week
    if (desc.contains('last week')) {
      final lastWeekStart = now.subtract(Duration(days: now.weekday + 6));
      final lastWeekEnd = lastWeekStart.add(const Duration(days: 6));
      return {
        'start': lastWeekStart.toIso8601String().split('T')[0],
        'end': lastWeekEnd.toIso8601String().split('T')[0],
      };
    }

    // This month
    if (desc.contains('this month')) {
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      return {
        'start': monthStart.toIso8601String().split('T')[0],
        'end': monthEnd.toIso8601String().split('T')[0],
      };
    }

    // Last month
    if (desc.contains('last month')) {
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);
      return {
        'start': lastMonthStart.toIso8601String().split('T')[0],
        'end': lastMonthEnd.toIso8601String().split('T')[0],
      };
    }

    // Specific month this year: "november", "march"
    final monthOnlyPattern = RegExp(
      r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\b',
      caseSensitive: false,
    );
    final monthOnlyMatch = monthOnlyPattern.firstMatch(desc);
    if (monthOnlyMatch != null) {
      final monthStr = monthOnlyMatch.group(1)!.substring(0, 3).toLowerCase();
      final monthMap = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final month = monthMap[monthStr]!;

      // Check if year is specified: "november 2024", "last year's november"
      final yearPattern = RegExp(r'\b(20\d{2})\b');
      final yearMatch = yearPattern.firstMatch(desc);
      final lastYearPattern = RegExp(r'last\s+year');

      int year;
      if (yearMatch != null) {
        year = int.parse(yearMatch.group(1)!);
      } else if (lastYearPattern.hasMatch(desc)) {
        year = now.year - 1;
      } else {
        year = now.year;
      }

      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0);
      return {
        'start': monthStart.toIso8601String().split('T')[0],
        'end': monthEnd.toIso8601String().split('T')[0],
      };
    }

    // This year
    if (desc.contains('this year')) {
      final yearStart = DateTime(now.year, 1, 1);
      final yearEnd = DateTime(now.year, 12, 31);
      return {
        'start': yearStart.toIso8601String().split('T')[0],
        'end': yearEnd.toIso8601String().split('T')[0],
      };
    }

    // Last year
    if (desc.contains('last year')) {
      final yearStart = DateTime(now.year - 1, 1, 1);
      final yearEnd = DateTime(now.year - 1, 12, 31);
      return {
        'start': yearStart.toIso8601String().split('T')[0],
        'end': yearEnd.toIso8601String().split('T')[0],
      };
    }

    // Quarter patterns: "Q1", "Q1 2024", "first quarter"
    final quarterPattern = RegExp(
      r'q([1-4])|([1-4])(st|nd|rd|th)\s+quarter',
      caseSensitive: false,
    );
    final quarterMatch = quarterPattern.firstMatch(desc);
    if (quarterMatch != null) {
      final quarter = int.parse(
        quarterMatch.group(1) ?? quarterMatch.group(2)!,
      );

      final yearPattern = RegExp(r'\b(20\d{2})\b');
      final yearMatch = yearPattern.firstMatch(desc);
      final year = yearMatch != null
          ? int.parse(yearMatch.group(1)!)
          : now.year;

      final quarterStartMonth = (quarter - 1) * 3 + 1;
      final quarterStart = DateTime(year, quarterStartMonth, 1);
      final quarterEnd = DateTime(year, quarterStartMonth + 3, 0);
      return {
        'start': quarterStart.toIso8601String().split('T')[0],
        'end': quarterEnd.toIso8601String().split('T')[0],
      };
    }

    // If we couldn't parse it, return null
    return null;
  }

  // ==================== HIGH PRIORITY: INVENTORY ALERTS ====================

  /// Get materials with low stock levels
  Future<Map<String, dynamic>> getLowStockAlerts({int threshold = 10}) async {
    try {
      if (kDebugMode) {
        print('⚠️ getLowStockAlerts: Starting (threshold=$threshold)...');
      }
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final materialsSnapshot = await _q('junkshop_materials', user.uid);

      final List<Map<String, dynamic>> lowStockItems = [];
      final List<Map<String, dynamic>> outOfStockItems = [];

      for (final doc in materialsSnapshot.docs) {
        final data = doc.data();
        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
        final name = data['name'] as String? ?? 'Unknown';
        final unit = data['unit'] as String? ?? 'kg';

        if (quantity <= 0) {
          outOfStockItems.add({
            'materialName': name,
            'quantity': quantity,
            'unit': unit,
            'status': 'OUT_OF_STOCK',
          });
        } else if (quantity < threshold) {
          lowStockItems.add({
            'materialName': name,
            'quantity': quantity,
            'unit': unit,
            'status': 'LOW_STOCK',
          });
        }
      }

      if (kDebugMode) {
        print(
          '✅ getLowStockAlerts: ${lowStockItems.length} low stock, ${outOfStockItems.length} out of stock',
        );
      }
      return {
        'threshold': threshold,
        'lowStockCount': lowStockItems.length,
        'outOfStockCount': outOfStockItems.length,
        'lowStockItems': lowStockItems,
        'outOfStockItems': outOfStockItems,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getLowStockAlerts error: $e');
      return {'error': 'Failed to fetch low stock alerts: $e'};
    }
  }

  /// Get materials that are overstocked based on sales velocity
  Future<Map<String, dynamic>> getOverstockedItems({int days = 30}) async {
    try {
      if (kDebugMode) print('📦 getOverstockedItems: Starting (days=$days)...');
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final DateTime startDate = DateTime.now().subtract(Duration(days: days));

      // Get current inventory
      final materialsSnapshot = await _q('junkshop_materials', user.uid);

      // Get sales data
      final salesSnapshot = await _q('sales', user.uid, from: startDate);

      final Map<String, double> materialSales = {};
      final Map<String, double> currentStock = {};

      // Calculate sales velocity
      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];

        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final materialName =
                item['material'] as String? ??
                item['name'] as String? ??
                'Unknown';
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;

            materialSales[materialName] =
                (materialSales[materialName] ?? 0.0) + quantity;
          }
        }
      }

      // Get current stock levels
      for (final doc in materialsSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? 'Unknown';
        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
        currentStock[name] = quantity;
      }

      // Calculate overstocked items (stock > 3x daily sales rate * days)
      final List<Map<String, dynamic>> overstockedItems = [];

      for (final entry in currentStock.entries) {
        final materialName = entry.key;
        final stock = entry.value;
        final totalSold = materialSales[materialName] ?? 0.0;
        final dailySalesRate = totalSold / days;
        final daysOfStock = dailySalesRate > 0 ? stock / dailySalesRate : 999;

        if (daysOfStock > 90 && stock > 0) {
          overstockedItems.add({
            'materialName': materialName,
            'currentStock': stock,
            'dailySalesRate': dailySalesRate,
            'daysOfStock': daysOfStock,
            'status': 'OVERSTOCKED',
          });
        }
      }

      overstockedItems.sort(
        (a, b) =>
            (b['daysOfStock'] as double).compareTo(a['daysOfStock'] as double),
      );

      if (kDebugMode) {
        print(
          '✅ getOverstockedItems: Found ${overstockedItems.length} overstocked items',
        );
      }
      return {
        'period': '$days days',
        'overstockedCount': overstockedItems.length,
        'overstockedItems': overstockedItems,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getOverstockedItems error: $e');
      return {'error': 'Failed to fetch overstocked items: $e'};
    }
  }

  // ==================== MEDIUM PRIORITY: FINANCIAL INSIGHTS ====================

  /// Get profit margins by material or overall
  Future<Map<String, dynamic>> getProfitMargins({
    int days = 30,
    String groupBy = 'material',
  }) async {
    try {
      if (kDebugMode) {
        print(
          '💵 getProfitMargins: Starting (days=$days, groupBy=$groupBy)...',
        );
      }
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final DateTime startDate = DateTime.now().subtract(Duration(days: days));

      // Get sales
      final salesSnapshot = await _q('sales', user.uid, from: startDate);

      // Get purchases
      final purchaseSnapshot = await _q('purchases', user.uid, from: startDate);

      double totalRevenue = 0;
      double totalCost = 0;

      for (final doc in salesSnapshot.docs) {
        totalRevenue += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0.0;
      }

      for (final doc in purchaseSnapshot.docs) {
        totalCost += (doc.data()['totalPrice'] as num?)?.toDouble() ?? 0.0;
      }

      final profit = totalRevenue - totalCost;
      final profitMargin = totalRevenue > 0 ? (profit / totalRevenue * 100) : 0;

      if (kDebugMode) {
        print(
          '✅ getProfitMargins: Revenue=₱$totalRevenue, Cost=₱$totalCost, Margin=$profitMargin%',
        );
      }
      return {
        'period': '$days days',
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'profit': profit,
        'profitMargin': profitMargin,
        'groupBy': groupBy,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getProfitMargins error: $e');
      return {'error': 'Failed to calculate profit margins: $e'};
    }
  }

  /// Get cash flow analysis
  Future<Map<String, dynamic>> getCashFlow({int days = 30}) async {
    try {
      if (kDebugMode) print('💸 getCashFlow: Starting (days=$days)...');
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final DateTime startDate = DateTime.now().subtract(Duration(days: days));

      // Get sales (cash in)
      final salesSnapshot = await _q('sales', user.uid, from: startDate, orderBy: 'created_at');

      // Get purchases (cash out)
      final purchaseSnapshot = await _q('purchases', user.uid, from: startDate, orderBy: 'created_at');

      final Map<String, Map<String, double>> dailyCashFlow = {};

      // Process sales
      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
          if (!dailyCashFlow.containsKey(dateKey)) {
            dailyCashFlow[dateKey] = {'cashIn': 0, 'cashOut': 0};
          }
          dailyCashFlow[dateKey]!['cashIn'] =
              (dailyCashFlow[dateKey]!['cashIn'] ?? 0) + amount;
        }
      }

      // Process purchases
      for (final doc in purchaseSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
        final date = (data['date'] as Timestamp?)?.toDate();

        if (date != null) {
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          if (!dailyCashFlow.containsKey(dateKey)) {
            dailyCashFlow[dateKey] = {'cashIn': 0, 'cashOut': 0};
          }
          dailyCashFlow[dateKey]!['cashOut'] =
              (dailyCashFlow[dateKey]!['cashOut'] ?? 0) + amount;
        }
      }

      // Calculate net cash flow per day
      final cashFlowList =
          dailyCashFlow.entries.map((e) {
            final cashIn = e.value['cashIn'] ?? 0;
            final cashOut = e.value['cashOut'] ?? 0;
            return {
              'date': e.key,
              'cashIn': cashIn,
              'cashOut': cashOut,
              'netCashFlow': cashIn - cashOut,
            };
          }).toList()..sort(
            (a, b) => (a['date'] as String).compareTo(b['date'] as String),
          );

      final totalCashIn = cashFlowList.fold<double>(
        0,
        (acc, day) => acc + (day['cashIn'] as double),
      );
      final totalCashOut = cashFlowList.fold<double>(
        0,
        (acc, day) => acc + (day['cashOut'] as double),
      );

      if (kDebugMode) {
        print('✅ getCashFlow: In=₱$totalCashIn, Out=₱$totalCashOut');
      }
      return {
        'period': '$days days',
        'totalCashIn': totalCashIn,
        'totalCashOut': totalCashOut,
        'netCashFlow': totalCashIn - totalCashOut,
        'dailyCashFlow': cashFlowList,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getCashFlow error: $e');
      return {'error': 'Failed to calculate cash flow: $e'};
    }
  }

  // ==================== MEDIUM PRIORITY: WASTE REDUCTION METRICS ====================

  /// Calculate carbon impact based on materials recycled
  Future<Map<String, dynamic>> getCarbonImpact({int days = 30}) async {
    try {
      if (kDebugMode) print('🌱 getCarbonImpact: Starting (days=$days)...');
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final DateTime startDate = DateTime.now().subtract(Duration(days: days));

      final purchaseSnapshot = await _q('purchases', user.uid, from: startDate);

      // Carbon factors (kg CO2 saved per kg of material)
      final Map<String, double> carbonFactors = {
        'aluminum': 8.5,
        'steel': 1.5,
        'iron': 1.5,
        'plastic': 2.0,
        'pet': 2.5,
        'paper': 1.0,
        'cardboard': 1.0,
        'glass': 0.3,
      };

      double totalCarbonSaved = 0;
      final Map<String, double> carbonByMaterial = {};

      for (final doc in purchaseSnapshot.docs) {
        final data = doc.data();
        final items = (data['items'] is List)
            ? data['items'] as List<dynamic>
            : (data['items'] is Map)
            ? (data['items'] as Map).values.toList()
            : [];

        for (final item in items) {
          if (item is Map) {
            final materialName =
                (item['material'] as String? ??
                        item['name'] as String? ??
                        'Unknown')
                    .toLowerCase();
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;

            double carbonFactor = 0;
            for (final key in carbonFactors.keys) {
              if (materialName.contains(key)) {
                carbonFactor = carbonFactors[key]!;
                break;
              }
            }

            final carbonSaved = quantity * carbonFactor;
            totalCarbonSaved += carbonSaved;

            carbonByMaterial[materialName] =
                (carbonByMaterial[materialName] ?? 0.0) + carbonSaved;
          }
        }
      }

      final carbonList =
          carbonByMaterial.entries
              .map((e) => {'material': e.key, 'carbonSaved': e.value})
              .toList()
            ..sort(
              (a, b) => (b['carbonSaved'] as double).compareTo(
                a['carbonSaved'] as double,
              ),
            );

      if (kDebugMode) {
        print('✅ getCarbonImpact: Total CO2 saved = $totalCarbonSaved kg');
      }
      return {
        'period': '$days days',
        'totalCarbonSaved': totalCarbonSaved,
        'carbonByMaterial': carbonList,
        'equivalents': {
          'treesSaved': (totalCarbonSaved / 21).round(),
          'carsOffRoad': (totalCarbonSaved / 4600).toStringAsFixed(2),
        },
      };
    } catch (e) {
      if (kDebugMode) print('❌ getCarbonImpact error: $e');
      return {'error': 'Failed to calculate carbon impact: $e'};
    }
  }

  /// Calculate waste diversion rate
  Future<Map<String, dynamic>> getDiversionRate({int days = 30}) async {
    try {
      if (kDebugMode) print('♻️ getDiversionRate: Starting (days=$days)...');
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final DateTime startDate = DateTime.now().subtract(Duration(days: days));

      final purchaseSnapshot = await _q('purchases', user.uid, from: startDate);

      double totalWasteDiverted = 0;

      for (final doc in purchaseSnapshot.docs) {
        final data = doc.data();
        final items = (data['items'] is List)
            ? data['items'] as List<dynamic>
            : (data['items'] is Map)
            ? (data['items'] as Map).values.toList()
            : [];

        for (final item in items) {
          if (item is Map) {
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            totalWasteDiverted += quantity;
          }
        }
      }

      final dailyAverage = totalWasteDiverted / days;

      if (kDebugMode) {
        print(
          '✅ getDiversionRate: Total waste diverted = $totalWasteDiverted kg',
        );
      }
      return {
        'period': '$days days',
        'totalWasteDiverted': totalWasteDiverted,
        'dailyAverage': dailyAverage,
        'monthlyProjection': dailyAverage * 30,
        'yearlyProjection': dailyAverage * 365,
      };
    } catch (e) {
      if (kDebugMode) print('❌ getDiversionRate error: $e');
      return {'error': 'Failed to calculate diversion rate: $e'};
    }
  }

  // ==================== EXCEL EXPORT FUNCTIONS ====================

  /// Helper to round doubles to 2 decimal places for Excel
  double _roundToTwo(double value) {
    return (value * 100).round() / 100;
  }

  /// Helper to safely convert any value to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Export sales data to Excel file
  Future<Map<String, dynamic>> exportSalesToExcel({
    required String startDate,
    required String endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('📊 exportSalesToExcel: Starting ($startDate to $endDate)...');
      }
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      // Get business name from main junkshop document
      final junkshopDoc = await _db
          .from('junkshops')
          .select()
          .eq('id', user.uid)
          .maybeSingle();
      if (kDebugMode) {
        print('📋 Sales Export - Junkshop doc exists: ${(junkshopDoc != null)}');
      }
      final junkshopProfile =
          junkshopDoc?['junkshop_profile'] as Map<String, dynamic>?;
      final business = junkshopProfile?['business'] as Map<String, dynamic>?;
      final businessName =
          business?['business_name'] as String? ?? 'EcoKuha Junkshop';
      if (kDebugMode) print('📋 Sales Export - Business name: $businessName');

      DateTime start, end;
      try {
        start = DateTime.parse(startDate);
        end = DateTime.parse(
          endDate,
        ).add(const Duration(hours: 23, minutes: 59, seconds: 59));
      } catch (e) {
        return {'error': 'Invalid date format. Use YYYY-MM-DD'};
      }

      // Query sales data
      final salesSnapshot = await _q('sales', user.uid, from: start, to: end, orderBy: 'created_at');

      if (salesSnapshot.docs.isEmpty) {
        return {
          'error': 'No sales found for the period $startDate to $endDate',
        };
      }

      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Sales Report'];

      // Header styling
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Left,
      );

      // Title row
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('I1'));
      var titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('$businessName - Sales Report');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Left,
      );

      // Period row
      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('I2'));
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Period: ${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}',
      );

      // Generated timestamp
      sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('I3'));
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'Generated: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
      );

      // Column headers
      final headers = [
        'Date',
        'Transaction ID',
        'Buyer',
        'Material',
        'Quantity',
        'Unit',
        'Price/Unit',
        'Subtotal',
        'Total Amount',
      ];
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Data rows
      int rowIndex = 5;
      double totalRevenue = 0;
      int totalTransactions = 0;
      Map<String, double> materialRevenue = {};

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final buyer =
            data['buyer'] as String? ??
            data['customerName'] as String? ??
            'Walk-in';
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final items = data['items'] as List? ?? [];

        totalRevenue += totalAmount;
        totalTransactions++;

        if (items.isEmpty) {
          // No items, just show transaction
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            createdAt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
                : '',
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            doc.id.substring(0, 8),
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            buyer,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
              )
              .value = DoubleCellValue(
            _roundToTwo(totalAmount),
          );
          rowIndex++;
        } else {
          // Show items
          for (var i = 0; i < items.length; i++) {
            final item = items[i] as Map<String, dynamic>;
            final material =
                item['material'] as String? ??
                item['name'] as String? ??
                'Unknown';
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            final unit = item['unit'] as String? ?? 'kg';
            final pricePerUnit =
                (item['pricePerUnit'] as num?)?.toDouble() ??
                (item['price'] as num?)?.toDouble() ??
                0.0;
            final subtotal =
                (item['subtotal'] as num?)?.toDouble() ??
                (quantity * pricePerUnit);

            materialRevenue[material] =
                (materialRevenue[material] ?? 0) + subtotal;

            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: rowIndex,
                  ),
                )
                .value = TextCellValue(
              createdAt != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
                  : '',
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 1,
                    rowIndex: rowIndex,
                  ),
                )
                .value = TextCellValue(
              doc.id.substring(0, 8),
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 2,
                    rowIndex: rowIndex,
                  ),
                )
                .value = TextCellValue(
              buyer,
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 3,
                    rowIndex: rowIndex,
                  ),
                )
                .value = TextCellValue(
              material,
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 4,
                    rowIndex: rowIndex,
                  ),
                )
                .value = DoubleCellValue(
              _roundToTwo(quantity),
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 5,
                    rowIndex: rowIndex,
                  ),
                )
                .value = TextCellValue(
              unit,
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 6,
                    rowIndex: rowIndex,
                  ),
                )
                .value = DoubleCellValue(
              _roundToTwo(pricePerUnit),
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 7,
                    rowIndex: rowIndex,
                  ),
                )
                .value = DoubleCellValue(
              _roundToTwo(subtotal),
            );
            if (i == 0) {
              sheet
                  .cell(
                    CellIndex.indexByColumnRow(
                      columnIndex: 8,
                      rowIndex: rowIndex,
                    ),
                  )
                  .value = DoubleCellValue(
                _roundToTwo(totalAmount),
              );
            }
            rowIndex++;
          }
        }
      }

      // Summary section
      rowIndex += 2;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
      );
      var summaryCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      summaryCell.value = TextCellValue('SUMMARY');
      summaryCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Left,
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Total Revenue:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        _roundToTwo(totalRevenue),
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Total Transactions:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = IntCellValue(
        totalTransactions,
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Average Transaction:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        _roundToTwo(
          totalTransactions > 0 ? totalRevenue / totalTransactions : 0,
        ),
      );
      rowIndex += 2;

      // Top materials
      if (materialRevenue.isNotEmpty) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          'Top Materials:',
        );
        rowIndex++;

        final sortedMaterials = materialRevenue.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        for (var i = 0; i < sortedMaterials.take(5).length; i++) {
          final entry = sortedMaterials[i];
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            '${i + 1}. ${entry.key}',
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
              )
              .value = DoubleCellValue(
            entry.value,
          );
          rowIndex++;
        }
      }

      // Delete default Sheet1 and set column widths
      excel.delete('Sheet1');
      for (int i = 0; i < 10; i++) {
        sheet.setColumnWidth(i, 20);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'Sales_Report_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}_${DateFormat('HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        if (kDebugMode) {
          print(
            '✅ exportSalesToExcel: Saved $totalTransactions transactions to $fileName',
          );
        }
        return {
          'success': true,
          'type': 'excel',
          'filePath': filePath,
          'fileName': fileName,
          'totalTransactions': totalTransactions,
          'totalRevenue': totalRevenue,
          'periodStart': DateFormat('MMM d, yyyy').format(start),
          'periodEnd': DateFormat('MMM d, yyyy').format(end),
        };
      }

      return {'error': 'Failed to generate Excel file'};
    } catch (e) {
      if (kDebugMode) print('❌ exportSalesToExcel error: $e');
      return {'error': 'Export failed: $e'};
    }
  }

  /// Export purchases data to Excel file
  Future<Map<String, dynamic>> exportPurchasesToExcel({
    required String startDate,
    required String endDate,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📊 exportPurchasesToExcel: Starting ($startDate to $endDate)...',
        );
      }
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      // Get business name from main junkshop document
      final junkshopDoc = await _db
          .from('junkshops')
          .select()
          .eq('id', user.uid)
          .maybeSingle();
      final junkshopProfile =
          junkshopDoc?['junkshop_profile'] as Map<String, dynamic>?;
      final business = junkshopProfile?['business'] as Map<String, dynamic>?;
      final businessName =
          business?['business_name'] as String? ?? 'EcoKuha Junkshop';

      DateTime start, end;
      try {
        start = DateTime.parse(startDate);
        end = DateTime.parse(
          endDate,
        ).add(const Duration(hours: 23, minutes: 59, seconds: 59));
      } catch (e) {
        return {'error': 'Invalid date format. Use YYYY-MM-DD'};
      }

      // Query purchases data from Purchase collection
      final purchasesSnapshot = await _q('purchases', user.uid, from: start, to: end, orderBy: 'created_at');

      // Query household postings (collections) - dual query strategy
      final postingsSnapshot1 = await _postings(user.uid, ['completed']);

      final postingsSnapshot2 = await Future.value(const _Snap([]));

      // Combine and deduplicate postings
      final Map<String, _Doc> allPostings =
          {};
      for (var doc in postingsSnapshot1.docs) {
        allPostings[doc.id] = doc;
      }
      for (var doc in postingsSnapshot2.docs) {
        allPostings[doc.id] = doc;
      }

      // Filter postings by date range
      final List<Map<String, dynamic>> postingsInRange = [];
      for (final entry in allPostings.entries) {
        final data = entry.value.data();

        // Use reviewedAt or dateOfCollection for completed postings
        DateTime? purchasedAt;
        if (data['reviewedAt'] is Timestamp) {
          purchasedAt = (data['reviewedAt'] as Timestamp).toDate();
        } else if (data['dateOfCollection'] is Timestamp) {
          purchasedAt = (data['dateOfCollection'] as Timestamp).toDate();
        } else if (data['createdAt'] is Timestamp) {
          purchasedAt = (data['createdAt'] as Timestamp).toDate();
        }

        if (purchasedAt != null &&
            purchasedAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
            purchasedAt.isBefore(end.add(const Duration(seconds: 1)))) {
          postingsInRange.add({
            'id': entry.value.id,
            'data': data,
            'purchasedAt': purchasedAt,
          });
        }
      }

      if (purchasesSnapshot.docs.isEmpty && postingsInRange.isEmpty) {
        return {
          'error': 'No purchases found for the period $startDate to $endDate',
        };
      }

      if (kDebugMode) {
        print(
          '📊 Found ${purchasesSnapshot.docs.length} manual purchases and ${postingsInRange.length} collections',
        );
      }

      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Purchases Report'];

      // Header styling
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Left,
      );

      // Data cell styling for consistent left alignment
      final dataCellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Bottom,
      );

      // Title rows
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('K1'));
      var titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('$businessName - Purchases Report');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Left,
      );

      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('K2'));
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Period: ${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}',
      );

      sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('K3'));
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'Generated: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
      );

      // Column headers (added Collector and Unit columns)
      final headers = [
        'Date',
        'Transaction ID',
        'Type',
        'Customer Name',
        'Collector',
        'Material',
        'Quantity',
        'Unit',
        'Price/Unit',
        'Item Cost',
        'Transaction Total',
      ];
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Data rows
      int rowIndex = 5;
      double totalCost = 0;
      int totalTransactions = 0;
      Map<String, double> materialCost = {};
      Map<String, int> collectorStats = {};

      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final type = data['type'] as String? ?? 'walk-in';
        final isOnsite = type.contains('onsite') || type.contains('manual');

        final customerName =
            data['customer_name'] as String? ??
            data['householdName'] as String? ??
            'Walk-in Customer';
        final collectorName = data['collectorName'] as String?;
        final collectorDisplay = isOnsite ? 'Onsite' : (collectorName ?? 'N/A');

        final items = data['items'] as List? ?? [];

        double transactionTotal = 0;
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final subtotal = _toDouble(item['subtotal']);
            transactionTotal += subtotal;
          }
        }

        totalCost += transactionTotal;
        totalTransactions++;

        // Track collector stats (only for non-onsite)
        if (!isOnsite && collectorName != null && collectorName.isNotEmpty) {
          collectorStats[collectorName] =
              (collectorStats[collectorName] ?? 0) + 1;
        }

        if (items.isEmpty) {
          var cell0 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          );
          cell0.value = TextCellValue(
            createdAt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
                : '',
          );
          cell0.cellStyle = dataCellStyle;

          var cell1 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
          );
          cell1.value = TextCellValue(doc.id.substring(0, 8));
          cell1.cellStyle = dataCellStyle;

          var cell2 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
          );
          cell2.value = TextCellValue(isOnsite ? 'Onsite' : 'Collection');
          cell2.cellStyle = dataCellStyle;

          var cell3 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
          );
          cell3.value = TextCellValue(customerName);
          cell3.cellStyle = dataCellStyle;

          var cell4 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
          );
          cell4.value = TextCellValue(collectorDisplay);
          cell4.cellStyle = dataCellStyle;

          var cell10 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex),
          );
          cell10.value = DoubleCellValue(_roundToTwo(transactionTotal));
          cell10.cellStyle = dataCellStyle;

          rowIndex++;
        } else {
          for (var i = 0; i < items.length; i++) {
            final item = items[i] as Map<String, dynamic>;
            final material =
                item['name'] as String? ??
                item['material'] as String? ??
                'Unknown';
            final quantity = _toDouble(item['quantity']);
            final unit = item['unit'] as String? ?? 'kg';

            // Try to get price from multiple possible fields
            double pricePerUnit = 0.0;
            final subtotal = _toDouble(item['subtotal']);

            // First try junkshopPricePerUnit (from postings)
            pricePerUnit = _toDouble(item['junkshopPricePerUnit']);

            // If not found, try pricePerUnit
            if (pricePerUnit == 0.0) {
              pricePerUnit = _toDouble(item['pricePerUnit']);
            }

            // If still 0 and we have subtotal and quantity, calculate it
            if (pricePerUnit == 0.0 && quantity > 0 && subtotal > 0) {
              pricePerUnit = subtotal / quantity;
            }

            final itemCost = subtotal > 0
                ? subtotal
                : (quantity * pricePerUnit);

            // Debug: log if price is still 0
            if (pricePerUnit == 0.0 && quantity > 0) {
              if (kDebugMode) {
                print(
                  '⚠️ Price is 0 for $material after all attempts: item data = $item',
                );
              }
            }

            materialCost[material] = (materialCost[material] ?? 0) + itemCost;

            var cell0 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            );
            cell0.value = TextCellValue(
              createdAt != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
                  : '',
            );
            cell0.cellStyle = dataCellStyle;

            var cell1 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            );
            cell1.value = TextCellValue(doc.id.substring(0, 8));
            cell1.cellStyle = dataCellStyle;

            var cell2 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            );
            cell2.value = TextCellValue(isOnsite ? 'Onsite' : 'Collection');
            cell2.cellStyle = dataCellStyle;

            var cell3 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            );
            cell3.value = TextCellValue(customerName);
            cell3.cellStyle = dataCellStyle;

            var cell4 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            );
            cell4.value = TextCellValue(collectorDisplay);
            cell4.cellStyle = dataCellStyle;

            var cell5 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            );
            cell5.value = TextCellValue(material);
            cell5.cellStyle = dataCellStyle;

            var cell6 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
            );
            cell6.value = DoubleCellValue(_roundToTwo(quantity));
            cell6.cellStyle = dataCellStyle;

            var cell7 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
            );
            cell7.value = TextCellValue(unit);
            cell7.cellStyle = dataCellStyle;

            var cell8 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
            );
            cell8.value = DoubleCellValue(_roundToTwo(pricePerUnit));
            cell8.cellStyle = dataCellStyle;

            var cell9 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex),
            );
            cell9.value = DoubleCellValue(_roundToTwo(itemCost));
            cell9.cellStyle = dataCellStyle;

            if (i == 0) {
              var cell10 = sheet.cell(
                CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex),
              );
              cell10.value = DoubleCellValue(_roundToTwo(transactionTotal));
              cell10.cellStyle = dataCellStyle;
            }
            rowIndex++;
          }
        }
      }

      // Process household postings (collections)
      for (final posting in postingsInRange) {
        final data = posting['data'] as Map<String, dynamic>;
        final purchasedAt = posting['purchasedAt'] as DateTime;
        final postingId = posting['id'] as String;

        // Extract household name from household object
        final household = data['household'] as Map<String, dynamic>?;
        final householdName =
            household?['full_name'] as String? ??
            household?['name'] as String? ??
            'Unknown Household';

        // Extract collector name from collector object
        final collector = data['collector'] as Map<String, dynamic>?;
        final collectorName =
            collector?['full_name'] as String? ??
            collector?['name'] as String? ??
            'N/A';

        // Extract items from purchasedItems (what junkshop actually purchased)
        List<dynamic> items = [];
        final purchasedItemsRaw = data['purchasedItems'];

        if (purchasedItemsRaw is Map && purchasedItemsRaw['list'] is List) {
          items = purchasedItemsRaw['list'] as List<dynamic>;
        } else if (purchasedItemsRaw is Map &&
            purchasedItemsRaw['items'] is List) {
          items = purchasedItemsRaw['items'] as List<dynamic>;
        } else if (purchasedItemsRaw is List) {
          items = purchasedItemsRaw;
        } else if (data['verifiedItems'] is List) {
          items = data['verifiedItems'] as List<dynamic>;
        } else if (data['items'] is List) {
          items = data['items'] as List<dynamic>;
        }

        double transactionTotal = 0;
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            // Try multiple fields for item cost
            double itemCost = _toDouble(item['junkshopSubtotal']);

            // If junkshopSubtotal is 0, calculate from quantity * price
            if (itemCost == 0.0) {
              final quantity = _toDouble(item['quantity']);
              final pricePerUnit = _toDouble(item['junkshopPricePerUnit']);
              itemCost = quantity * pricePerUnit;
            }

            // If still 0, try estimatedValue
            if (itemCost == 0.0) {
              itemCost = _toDouble(item['estimatedValue']);
            }

            transactionTotal += itemCost;
          }
        }

        totalCost += transactionTotal;
        totalTransactions++;

        // Track collector stats
        if (collectorName.isNotEmpty && collectorName != 'N/A') {
          collectorStats[collectorName] =
              (collectorStats[collectorName] ?? 0) + 1;
        }

        if (items.isEmpty) {
          var cell0 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          );
          cell0.value = TextCellValue(
            DateFormat('yyyy-MM-dd HH:mm').format(purchasedAt),
          );
          cell0.cellStyle = dataCellStyle;

          var cell1 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
          );
          cell1.value = TextCellValue(postingId.substring(0, 8));
          cell1.cellStyle = dataCellStyle;

          var cell2 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
          );
          cell2.value = TextCellValue('Collection');
          cell2.cellStyle = dataCellStyle;

          var cell3 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
          );
          cell3.value = TextCellValue(householdName);
          cell3.cellStyle = dataCellStyle;

          var cell4 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
          );
          cell4.value = TextCellValue(collectorName);
          cell4.cellStyle = dataCellStyle;

          var cell10 = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex),
          );
          cell10.value = DoubleCellValue(_roundToTwo(transactionTotal));
          cell10.cellStyle = dataCellStyle;

          rowIndex++;
        } else {
          for (var i = 0; i < items.length; i++) {
            final item = items[i] as Map<String, dynamic>;
            final material = item['name'] as String? ?? 'Unknown';
            final quantity = _toDouble(item['quantity']);
            final unit = item['unit'] as String? ?? 'kg';
            // For purchased items, use junkshop pricing
            final pricePerUnit = _toDouble(item['junkshopPricePerUnit']) > 0
                ? _toDouble(item['junkshopPricePerUnit'])
                : _toDouble(item['pricePerUnit']);

            // Calculate item cost: try junkshopSubtotal first, then calculate, then fallback
            double itemCost = _toDouble(item['junkshopSubtotal']);
            if (itemCost == 0.0) {
              itemCost = quantity * pricePerUnit;
            }
            if (itemCost == 0.0) {
              itemCost = _toDouble(item['estimatedValue']);
            }

            materialCost[material] = (materialCost[material] ?? 0) + itemCost;

            var cell0 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            );
            cell0.value = TextCellValue(
              DateFormat('yyyy-MM-dd HH:mm').format(purchasedAt),
            );
            cell0.cellStyle = dataCellStyle;
            var cell1 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            );
            cell1.value = TextCellValue(postingId.substring(0, 8));
            cell1.cellStyle = dataCellStyle;
            var cell2 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            );
            cell2.value = TextCellValue('Collection');
            cell2.cellStyle = dataCellStyle;
            var cell3 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            );
            cell3.value = TextCellValue(householdName);
            cell3.cellStyle = dataCellStyle;
            var cell4 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            );
            cell4.value = TextCellValue(collectorName);
            cell4.cellStyle = dataCellStyle;

            var cell5 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            );
            cell5.value = TextCellValue(material);
            cell5.cellStyle = dataCellStyle;

            var cell6 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
            );
            cell6.value = DoubleCellValue(_roundToTwo(quantity));
            cell6.cellStyle = dataCellStyle;

            var cell7 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
            );
            cell7.value = TextCellValue(unit);
            cell7.cellStyle = dataCellStyle;

            var cell8 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
            );
            cell8.value = DoubleCellValue(_roundToTwo(pricePerUnit));
            cell8.cellStyle = dataCellStyle;

            var cell9 = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex),
            );
            cell9.value = DoubleCellValue(_roundToTwo(itemCost));
            cell9.cellStyle = dataCellStyle;

            if (i == 0) {
              var cell10 = sheet.cell(
                CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex),
              );
              cell10.value = DoubleCellValue(_roundToTwo(transactionTotal));
              cell10.cellStyle = dataCellStyle;
            }
            rowIndex++;
          }
        }
      }

      // Summary section
      rowIndex += 2;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex),
      );
      var summaryCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      summaryCell.value = TextCellValue('SUMMARY');
      summaryCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Left,
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Total Cost:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        totalCost,
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Total Purchases:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = IntCellValue(
        totalTransactions,
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Average Purchase:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        _roundToTwo(totalTransactions > 0 ? totalCost / totalTransactions : 0),
      );
      rowIndex += 2;

      // Top collectors (only actual collectors, not onsite)
      if (collectorStats.isNotEmpty) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          'Top Collectors:',
        );
        rowIndex++;

        final sortedCollectors = collectorStats.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        for (var i = 0; i < sortedCollectors.take(5).length; i++) {
          final entry = sortedCollectors[i];
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            '${i + 1}. ${entry.key}',
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            entry.value,
          );
          rowIndex++;
        }
      }

      // Top materials by cost
      if (materialCost.isNotEmpty) {
        rowIndex++;
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          'Top Materials by Cost:',
        );
        rowIndex++;

        final sortedMaterials = materialCost.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        for (var i = 0; i < sortedMaterials.take(5).length; i++) {
          final entry = sortedMaterials[i];
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            '${i + 1}. ${entry.key}',
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
              )
              .value = DoubleCellValue(
            _roundToTwo(entry.value),
          );
          rowIndex++;
        }
      }

      // Delete default Sheet1 and set column widths
      excel.delete('Sheet1');
      for (int i = 0; i < 11; i++) {
        sheet.setColumnWidth(i, 18);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'Purchases_Report_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}_${DateFormat('HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        if (kDebugMode) {
          print(
            '✅ exportPurchasesToExcel: Saved $totalTransactions purchases to $fileName',
          );
        }
        return {
          'success': true,
          'type': 'excel',
          'filePath': filePath,
          'fileName': fileName,
          'totalTransactions': totalTransactions,
          'totalCost': totalCost,
          'periodStart': DateFormat('MMM d, yyyy').format(start),
          'periodEnd': DateFormat('MMM d, yyyy').format(end),
        };
      }

      return {'error': 'Failed to generate Excel file'};
    } catch (e) {
      if (kDebugMode) print('❌ exportPurchasesToExcel error: $e');
      return {'error': 'Export failed: $e'};
    }
  }

  /// Export current inventory to Excel file
  Future<Map<String, dynamic>> exportInventoryToExcel() async {
    try {
      if (kDebugMode) print('📊 exportInventoryToExcel: Starting...');
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      // Get business name from main junkshop document
      final junkshopDoc = await _db
          .from('junkshops')
          .select()
          .eq('id', user.uid)
          .maybeSingle();
      final junkshopProfile =
          junkshopDoc?['junkshop_profile'] as Map<String, dynamic>?;
      final business = junkshopProfile?['business'] as Map<String, dynamic>?;
      final businessName =
          business?['business_name'] as String? ?? 'EcoKuha Junkshop';

      // Query inventory data
      final materialsSnapshot = await _q('junkshop_materials', user.uid);

      if (materialsSnapshot.docs.isEmpty) {
        return {'error': 'No inventory data found'};
      }

      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Inventory Report'];

      // Header styling
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#FF9800'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Left,
      );

      // Title rows
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));
      var titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('$businessName - Inventory Report');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Left,
      );

      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('H2'));
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Generated: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
      );

      // Column headers
      final headers = [
        'Material',
        'Category',
        'Quantity',
        'Unit',
        'Buy Price',
        'Sell Price',
        'Stock Value',
        'Status',
      ];
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Data rows
      int rowIndex = 4;
      double totalValue = 0;
      int lowStockCount = 0;
      int healthyCount = 0;
      int overstockedCount = 0;

      for (final doc in materialsSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? 'Unknown';
        final category = data['category'] as String? ?? 'Other';
        final quantity = (data['stock'] as num?)?.toDouble() ?? 0.0;
        final unit = data['unit'] as String? ?? 'kg';
        final buyPrice = (data['priceMin'] as num?)?.toDouble() ?? 0.0;
        final sellPrice = (data['priceMax'] as num?)?.toDouble() ?? 0.0;
        final stockValue = quantity * sellPrice;

        // Debug: log if prices are 0
        if (buyPrice == 0.0 || sellPrice == 0.0) {
          if (kDebugMode) {
            print(
              '⚠️ Material $name has zero price: buy=$buyPrice, sell=$sellPrice, data fields: ${data.keys.toList()}',
            );
          }
        }

        // Determine status
        String status;
        if (quantity == 0) {
          status = 'Out of Stock';
        } else if (quantity < 10) {
          status = 'Critical';
          lowStockCount++;
        } else if (quantity < 50) {
          status = 'Low Stock';
          lowStockCount++;
        } else if (quantity > 500) {
          status = 'Overstocked';
          overstockedCount++;
        } else {
          status = 'Healthy';
          healthyCount++;
        }

        totalValue += stockValue;

        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          name,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          category,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          _roundToTwo(quantity),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          unit,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          _roundToTwo(buyPrice),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          _roundToTwo(sellPrice),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          _roundToTwo(stockValue),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          status,
        );
        rowIndex++;
      }

      // Summary section
      rowIndex += 2;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
      );
      var summaryCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      summaryCell.value = TextCellValue('INVENTORY SUMMARY');
      summaryCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Left,
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Total Inventory Value:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        _roundToTwo(totalValue),
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Total Materials:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = IntCellValue(
        materialsSnapshot.docs.length,
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Healthy Stock:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = IntCellValue(
        healthyCount,
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Low/Critical Stock:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = IntCellValue(
        lowStockCount,
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Overstocked:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = IntCellValue(
        overstockedCount,
      );

      // Delete default Sheet1 and set column widths
      excel.delete('Sheet1');
      for (int i = 0; i < 7; i++) {
        sheet.setColumnWidth(i, 20);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'Inventory_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        if (kDebugMode) {
          print(
            '✅ exportInventoryToExcel: Saved ${materialsSnapshot.docs.length} materials to $fileName',
          );
        }
        return {
          'success': true,
          'type': 'excel',
          'filePath': filePath,
          'fileName': fileName,
          'totalMaterials': materialsSnapshot.docs.length,
          'totalValue': totalValue,
        };
      }

      return {'error': 'Failed to generate Excel file'};
    } catch (e) {
      if (kDebugMode) print('❌ exportInventoryToExcel error: $e');
      return {'error': 'Export failed: $e'};
    }
  }

  /// Export profit & loss statement to Excel file
  Future<Map<String, dynamic>> exportProfitLossToExcel({
    required String startDate,
    required String endDate,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📊 exportProfitLossToExcel: Starting ($startDate to $endDate)...',
        );
      }
      final user = _currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      // Get business name from main junkshop document
      final junkshopDoc = await _db
          .from('junkshops')
          .select()
          .eq('id', user.uid)
          .maybeSingle();
      final junkshopProfile =
          junkshopDoc?['junkshop_profile'] as Map<String, dynamic>?;
      final business = junkshopProfile?['business'] as Map<String, dynamic>?;
      final businessName =
          business?['business_name'] as String? ?? 'EcoKuha Junkshop';

      DateTime start, end;
      try {
        start = DateTime.parse(startDate);
        end = DateTime.parse(
          endDate,
        ).add(const Duration(hours: 23, minutes: 59, seconds: 59));
      } catch (e) {
        return {'error': 'Invalid date format. Use YYYY-MM-DD'};
      }

      // Query sales and purchases
      final salesSnapshot = await _q('sales', user.uid, from: start, to: end);

      final purchasesSnapshot = await _q('purchases', user.uid, from: start, to: end);

      // Calculate totals by material
      Map<String, Map<String, double>> materialData = {};

      // Process sales
      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List? ?? [];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final material =
                item['material'] as String? ??
                item['name'] as String? ??
                'Unknown';
            final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;

            if (!materialData.containsKey(material)) {
              materialData[material] = {'revenue': 0, 'cost': 0};
            }
            materialData[material]!['revenue'] =
                (materialData[material]!['revenue'] ?? 0) + subtotal;
          }
        }
      }

      // Process purchases
      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final items =
            data['purchasedItems'] as List? ?? data['items'] as List? ?? [];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final material =
                item['material'] as String? ??
                item['name'] as String? ??
                'Unknown';
            final subtotal =
                (item['junkshopSubtotal'] as num?)?.toDouble() ??
                (item['subtotal'] as num?)?.toDouble() ??
                0.0;

            if (!materialData.containsKey(material)) {
              materialData[material] = {'revenue': 0, 'cost': 0};
            }
            materialData[material]!['cost'] =
                (materialData[material]!['cost'] ?? 0) + subtotal;
          }
        }
      }

      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Profit & Loss'];

      // Header styling
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Left,
      );

      // Title rows
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('F1'));
      var titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue(
        '$businessName - Profit & Loss Statement',
      );
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Left,
      );

      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('F2'));
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Period: ${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}',
      );

      sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('F3'));
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'Generated: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
      );

      // Column headers
      final headers = [
        'Material',
        'Revenue',
        'Cost',
        'Gross Profit',
        'Profit Margin %',
        'ROI %',
      ];
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Data rows
      int rowIndex = 5;
      double totalRevenue = 0;
      double totalCost = 0;

      final sortedMaterials = materialData.entries.toList()
        ..sort((a, b) {
          final profitA = (a.value['revenue'] ?? 0) - (a.value['cost'] ?? 0);
          final profitB = (b.value['revenue'] ?? 0) - (b.value['cost'] ?? 0);
          return profitB.compareTo(profitA);
        });

      for (final entry in sortedMaterials) {
        final material = entry.key;
        final revenue = entry.value['revenue'] ?? 0;
        final cost = entry.value['cost'] ?? 0;
        final profit = revenue - cost;
        final margin = revenue > 0 ? (profit / revenue * 100) : 0;
        final roi = cost > 0 ? (profit / cost * 100) : 0;

        totalRevenue += revenue;
        totalCost += cost;

        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          material,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          _roundToTwo(revenue),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          _roundToTwo(cost),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          _roundToTwo(profit),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          _roundToTwo(margin.toDouble()),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          _roundToTwo(roi.toDouble()),
        );
        rowIndex++;
      }

      // Summary section
      rowIndex += 2;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
      );
      var summaryCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      summaryCell.value = TextCellValue('OVERALL SUMMARY');
      summaryCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Left,
      );
      rowIndex++;

      final totalProfit = totalRevenue - totalCost;
      final overallMargin = totalRevenue > 0
          ? (totalProfit / totalRevenue * 100)
          : 0;
      final overallROI = totalCost > 0 ? (totalProfit / totalCost * 100) : 0;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Total Revenue:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        _roundToTwo(totalRevenue),
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Total Cost:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        _roundToTwo(totalCost),
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Gross Profit:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        _roundToTwo(totalProfit),
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'Profit Margin:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        _roundToTwo(overallMargin.toDouble()),
      );
      rowIndex++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        'ROI:',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        _roundToTwo(overallROI.toDouble()),
      );

      // Delete default Sheet1 and set column widths
      excel.delete('Sheet1');
      for (int i = 0; i < 8; i++) {
        sheet.setColumnWidth(i, 18);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'ProfitLoss_Report_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}_${DateFormat('HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        if (kDebugMode) {
          print(
            '✅ exportProfitLossToExcel: Saved P&L for ${materialData.length} materials to $fileName',
          );
        }
        return {
          'success': true,
          'type': 'excel',
          'filePath': filePath,
          'fileName': fileName,
          'totalRevenue': totalRevenue,
          'totalCost': totalCost,
          'totalProfit': totalProfit,
          'profitMargin': overallMargin,
          'periodStart': DateFormat('MMM d, yyyy').format(start),
          'periodEnd': DateFormat('MMM d, yyyy').format(end),
        };
      }

      return {'error': 'Failed to generate Excel file'};
    } catch (e) {
      if (kDebugMode) print('❌ exportProfitLossToExcel error: $e');
      return {'error': 'Export failed: $e'};
    }
  }
}


/// Minimal document wrapper so report code can keep `doc.id` / `doc.data()`.
class _Doc {
  _Doc(this._data);
  final Map<String, dynamic> _data;
  String get id => _data['id'].toString();
  Map<String, dynamic> data() => _data;
}

class _Snap {
  const _Snap(this.docs);
  final List<_Doc> docs;
  bool get isEmpty => docs.isEmpty;
}
