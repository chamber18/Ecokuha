import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../models/overview_data.dart';
import 'material_analytics_service.dart';
import '../../../../core/services/cache_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class OverviewAnalyticsService {
  final SupabaseClient _db;
  final MaterialAnalyticsService _materialService;
  final CacheService? _cacheService;

  OverviewAnalyticsService({
    SupabaseClient? supabase,
    MaterialAnalyticsService? materialService,
    CacheService? cacheService,
  }) : _db = supabase ?? Supabase.instance.client,
       _materialService = materialService ?? MaterialAnalyticsService(),
       _cacheService = cacheService;

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
    return _Snap(rowsToDocs(table, rows).map(_Doc.new).toList());
  }

  /// Paid (reviewed) household collections, filtered by `reviewed_at`.
  /// These replace the old `junkshops/{id}/collections` copy.
  Future<_Snap> _collections(
    String junkshopId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _db
        .from('postings')
        .select()
        .eq('junkshop_id', junkshopId)
        .eq('status', 'completed')
        .eq('is_reviewed', true)
        .gte('reviewed_at', from.toUtc().toIso8601String())
        .lte('reviewed_at', to.toUtc().toIso8601String());
    return _Snap(
      rowsToDocs('postings', rows).map((d) {
        final purchased = d['purchasedItems'];
        d['purchasedItems'] = purchased is Map
            ? (purchased['list'] ?? [])
            : (purchased ?? []);
        final household = d['household'];
        if (household is Map) {
          d['householdName'] ??= household['full_name'] ?? household['name'];
        }
        return _Doc(d);
      }).toList(),
    );
  }

  /// Get cached overview data if available (instant load)
  Future<OverviewData?> getCachedOverviewData(String junkshopId) async {
    if (_cacheService == null) return null;

    try {
      final cachedData = await _cacheService.getOverviewData(junkshopId);
      if (cachedData != null) {
        if (kDebugMode) print('✅ Loaded overview from cache');
        return OverviewData.fromJson(cachedData);
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load cache: $e');
    }
    return null;
  }

  /// Check if cache is stale (older than 24 hours)
  Future<bool> isCacheStale(String junkshopId) async {
    if (_cacheService == null) return true;

    final lastSync = await _cacheService.getOverviewLastSync(junkshopId);
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync).inHours >= 24;
  }

  Future<OverviewData> getOverviewData({
    required DateTime startDate,
    required DateTime endDate,
    bool includePeriodComparison = true,
  }) async {
    try {
      final user = _currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (kDebugMode) {
        print(
          '📊 Fetching overview data for ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
        );
      }

      final futures = await Future.wait([
        _getSummaryTotals(user.uid, startDate, endDate),
        _getTrendData(user.uid, startDate, endDate),
        _getTopMaterials(user.uid, startDate, endDate, limit: 5),
        _getTopCustomers(user.uid, startDate, endDate, limit: 5),
        _getTopBuyers(user.uid, startDate, endDate, limit: 5),
        _generateAlerts(user.uid, startDate, endDate),
      ]);

      final summaryTotals = futures[0] as SummaryTotals;
      final trendData = futures[1] as Map<String, List<TrendDataPoint>>;
      final topMaterials = futures[2] as List<TopPerformer>;
      final topCustomers = futures[3] as List<TopPerformer>;
      final topBuyers = futures[4] as List<TopPerformer>;
      final alerts = futures[5] as List<AlertItem>;

      PeriodComparison? purchaseComparison;
      PeriodComparison? salesComparison;
      PeriodComparison? profitComparison;
      PeriodComparison? inventoryComparison;

      if (includePeriodComparison) {
        final previousPeriod = _calculatePreviousPeriod(startDate, endDate);
        final previousTotals = await _getSummaryTotals(
          user.uid,
          previousPeriod['start']!,
          previousPeriod['end']!,
        );

        purchaseComparison = PeriodComparison.calculate(
          current: summaryTotals.totalPurchases,
          previous: previousTotals.totalPurchases,
        );

        salesComparison = PeriodComparison.calculate(
          current: summaryTotals.totalSales,
          previous: previousTotals.totalSales,
        );

        profitComparison = PeriodComparison.calculate(
          current: summaryTotals.netProfit,
          previous: previousTotals.netProfit,
        );

        inventoryComparison = PeriodComparison.calculate(
          current: summaryTotals.totalInventory,
          previous: previousTotals.totalInventory,
        );
      }

      final overviewData = OverviewData(
        summaryTotals: summaryTotals,
        purchaseComparison: purchaseComparison,
        salesComparison: salesComparison,
        profitComparison: profitComparison,
        inventoryComparison: inventoryComparison,
        purchasesTrend: trendData['purchases'] ?? [],
        salesTrend: trendData['sales'] ?? [],
        profitTrend: trendData['profit'] ?? [],
        topMaterials: topMaterials,
        topCustomers: topCustomers,
        topBuyers: topBuyers,
        alerts: alerts,
        startDate: startDate,
        endDate: endDate,
      );

      // Save to cache for instant loading next time
      if (_cacheService != null) {
        try {
          await _cacheService.saveOverviewData(
            junkshopId: user.uid,
            data: overviewData.toJson(),
          );
        } catch (cacheError) {
          if (kDebugMode) print('⚠️ Failed to cache: $cacheError');
        }
      }

      return overviewData;
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching overview data: $e');
      rethrow;
    }
  }

  Future<SummaryTotals> _getSummaryTotals(
    String junkshopId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final materialsSnapshot = await _q('junkshop_materials', junkshopId);

      double totalInventory = 0;
      for (final doc in materialsSnapshot.docs) {
        final stock = (doc.data()['stock'] as num?)?.toDouble() ?? 0;
        final avgCost =
            (doc.data()['avgPurchaseCost'] as num?)?.toDouble() ?? 0;
        totalInventory += (stock * avgCost);
      }

      final purchasesSnapshot = await _q('purchases', junkshopId, from: startDate, to: endDate);

      // Use reviewedAt for collections — consistent with Customers Tab and All Sellers screen
      final collectionsSnapshot = await _collections(junkshopId, startDate, endDate);

      double totalPurchases = 0;

      // Read stored fields — consistent with Customers Tab and All Sellers screen
      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        double docTotal =
            (data['totalAmount'] as num?)?.toDouble() ??
            (data['totalCost'] as num?)?.toDouble() ??
            0.0;
        // Fallback: recalculate from items if no stored total
        if (docTotal == 0.0) {
          final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
          for (final item in items) {
            final quantity =
                double.tryParse(
                  (item['quantity'] ?? item['weight'] ?? 0).toString(),
                ) ??
                0;
            final pricePerUnit =
                double.tryParse(
                  (item['junkshopPricePerUnit'] ??
                          item['pricePerUnit'] ??
                          item['price'] ??
                          0)
                      .toString(),
                ) ??
                0;
            docTotal += quantity * pricePerUnit;
          }
        }
        totalPurchases += docTotal;
      }

      for (final doc in collectionsSnapshot.docs) {
        final data = doc.data();
        double docTotal =
            (data['totalJunkshopCost'] as num?)?.toDouble() ??
            (data['totalCost'] as num?)?.toDouble() ??
            0.0;
        // Fallback: recalculate from purchasedItems if no stored total
        if (docTotal == 0.0) {
          final items = List<Map<String, dynamic>>.from(
            data['purchasedItems'] ?? [],
          );
          for (final item in items) {
            final quantity =
                double.tryParse(
                  (item['quantity'] ?? item['weight'] ?? 0).toString(),
                ) ??
                0;
            final pricePerUnit =
                double.tryParse(
                  (item['junkshopPricePerUnit'] ??
                          item['pricePerUnit'] ??
                          item['price'] ??
                          0)
                      .toString(),
                ) ??
                0;
            docTotal += quantity * pricePerUnit;
          }
        }
        totalPurchases += docTotal;
      }

      if (kDebugMode) {
        print(
          '📊 Overview Total Purchases: ₱${totalPurchases.toStringAsFixed(2)} from ${purchasesSnapshot.docs.length} purchases + ${collectionsSnapshot.docs.length} collections',
        );
      }

      final salesSnapshot = await _q('sales', junkshopId, from: startDate, to: endDate);

      double totalSales = 0;
      for (final doc in salesSnapshot.docs) {
        totalSales += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
      }

      final netProfit = totalSales - totalPurchases;
      final profitMargin = totalSales > 0
          ? ((netProfit / totalSales) * 100).toDouble()
          : 0.0;

      return SummaryTotals(
        totalPurchases: totalPurchases,
        totalSales: totalSales,
        netProfit: netProfit,
        totalInventory: totalInventory,
        purchaseCount:
            purchasesSnapshot.docs.length + collectionsSnapshot.docs.length,
        salesCount: salesSnapshot.docs.length,
        profitMargin: profitMargin,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error calculating summary totals: $e');
      return SummaryTotals.empty();
    }
  }

  Future<Map<String, List<TrendDataPoint>>> _getTrendData(
    String junkshopId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final daysDiff = endDate.difference(startDate).inDays;

      // Fetch all purchases and sales in one query each
      final purchasesSnapshot = await _q('purchases', junkshopId, from: startDate, to: endDate);

      // Use reviewedAt for collections — consistent with Customers Tab and All Sellers screen
      final collectionsSnapshot = await _collections(junkshopId, startDate, endDate);

      final salesSnapshot = await _q('sales', junkshopId, from: startDate, to: endDate);

      // Helper: read purchase amount from a collections doc (household pickup cost)
      double collectionAmount(Map<String, dynamic> data) {
        return ((data['totalJunkshopCost'] ?? data['totalAmount']) as num?)
                ?.toDouble() ??
            0;
      }

      // Group by day, week, or month depending on range
      final purchasesData = <TrendDataPoint>[];
      final salesData = <TrendDataPoint>[];
      final profitData = <TrendDataPoint>[];

      if (daysDiff <= 7) {
        // Daily grouping (up to 7 days)
        final purchasesByDay = <DateTime, double>{};
        final salesByDay = <DateTime, double>{};

        for (final doc in purchasesSnapshot.docs) {
          final timestamp = doc.data()['createdAt'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final dayKey = DateTime(date.year, date.month, date.day);
            final amount = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
            purchasesByDay[dayKey] = (purchasesByDay[dayKey] ?? 0) + amount;
          }
        }

        for (final doc in collectionsSnapshot.docs) {
          final timestamp = doc.data()['reviewedAt'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final dayKey = DateTime(date.year, date.month, date.day);
            final amount = collectionAmount(doc.data());
            purchasesByDay[dayKey] = (purchasesByDay[dayKey] ?? 0) + amount;
          }
        }

        for (final doc in salesSnapshot.docs) {
          final timestamp = doc.data()['createdAt'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final dayKey = DateTime(date.year, date.month, date.day);
            final amount = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
            salesByDay[dayKey] = (salesByDay[dayKey] ?? 0) + amount;
          }
        }

        for (int i = 0; i <= daysDiff; i++) {
          final date = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          ).add(Duration(days: i));
          final purchases = purchasesByDay[date] ?? 0;
          final sales = salesByDay[date] ?? 0;
          purchasesData.add(
            TrendDataPoint(
              date: date,
              value: purchases,
              label: '${date.day}/${date.month}',
            ),
          );
          salesData.add(
            TrendDataPoint(
              date: date,
              value: sales,
              label: '${date.day}/${date.month}',
            ),
          );
          profitData.add(
            TrendDataPoint(
              date: date,
              value: sales - purchases,
              label: '${date.day}/${date.month}',
            ),
          );
        }
      } else if (daysDiff <= 90) {
        // Weekly grouping (8–90 days → 2–13 data points for visible curves)
        final purchasesByWeek = <int, double>{};
        final salesByWeek = <int, double>{};
        final base = DateTime(startDate.year, startDate.month, startDate.day);

        int weekIndex(DateTime d) => d.difference(base).inDays ~/ 7;

        for (final doc in purchasesSnapshot.docs) {
          final timestamp = doc.data()['createdAt'] as Timestamp?;
          if (timestamp != null) {
            final idx = weekIndex(timestamp.toDate());
            final amount = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
            purchasesByWeek[idx] = (purchasesByWeek[idx] ?? 0) + amount;
          }
        }

        for (final doc in collectionsSnapshot.docs) {
          final timestamp = doc.data()['reviewedAt'] as Timestamp?;
          if (timestamp != null) {
            final idx = weekIndex(timestamp.toDate());
            final amount = collectionAmount(doc.data());
            purchasesByWeek[idx] = (purchasesByWeek[idx] ?? 0) + amount;
          }
        }

        for (final doc in salesSnapshot.docs) {
          final timestamp = doc.data()['createdAt'] as Timestamp?;
          if (timestamp != null) {
            final idx = weekIndex(timestamp.toDate());
            final amount = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
            salesByWeek[idx] = (salesByWeek[idx] ?? 0) + amount;
          }
        }

        final totalWeeks = (daysDiff / 7).ceil();
        for (int w = 0; w <= totalWeeks; w++) {
          final weekStart = base.add(Duration(days: w * 7));
          final purchases = purchasesByWeek[w] ?? 0;
          final sales = salesByWeek[w] ?? 0;
          final label = '${weekStart.day}/${weekStart.month}';
          purchasesData.add(
            TrendDataPoint(date: weekStart, value: purchases, label: label),
          );
          salesData.add(
            TrendDataPoint(date: weekStart, value: sales, label: label),
          );
          profitData.add(
            TrendDataPoint(
              date: weekStart,
              value: sales - purchases,
              label: label,
            ),
          );
        }
      } else {
        // Monthly grouping (> 90 days)
        final purchasesByMonth = <String, double>{};
        final salesByMonth = <String, double>{};

        for (final doc in purchasesSnapshot.docs) {
          final timestamp = doc.data()['createdAt'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final monthKey = '${date.year}-${date.month}';
            final amount = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
            purchasesByMonth[monthKey] =
                (purchasesByMonth[monthKey] ?? 0) + amount;
          }
        }
        for (final doc in collectionsSnapshot.docs) {
          final timestamp = doc.data()['reviewedAt'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final monthKey = '${date.year}-${date.month}';
            final amount = collectionAmount(doc.data());
            purchasesByMonth[monthKey] =
                (purchasesByMonth[monthKey] ?? 0) + amount;
          }
        }
        for (final doc in salesSnapshot.docs) {
          final timestamp = doc.data()['createdAt'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final monthKey = '${date.year}-${date.month}';
            final amount = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
            salesByMonth[monthKey] = (salesByMonth[monthKey] ?? 0) + amount;
          }
        }

        final monthsDiff =
            ((endDate.year - startDate.year) * 12 +
                    endDate.month -
                    startDate.month)
                .clamp(0, 12);
        for (int i = 0; i <= monthsDiff; i++) {
          final monthDate = DateTime(startDate.year, startDate.month + i, 1);
          final monthKey = '${monthDate.year}-${monthDate.month}';
          final purchases = purchasesByMonth[monthKey] ?? 0;
          final sales = salesByMonth[monthKey] ?? 0;
          final profit = sales - purchases;

          purchasesData.add(
            TrendDataPoint(
              date: monthDate,
              value: purchases,
              label: '${monthDate.month}/${monthDate.year}',
            ),
          );

          salesData.add(
            TrendDataPoint(
              date: monthDate,
              value: sales,
              label: '${monthDate.month}/${monthDate.year}',
            ),
          );

          profitData.add(
            TrendDataPoint(
              date: monthDate,
              value: profit,
              label: '${monthDate.month}/${monthDate.year}',
            ),
          );
        }
      }

      return {
        'purchases': purchasesData,
        'sales': salesData,
        'profit': profitData,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error calculating trend data: $e');
      return {'purchases': [], 'sales': [], 'profit': []};
    }
  }

  Future<List<TopPerformer>> _getTopMaterials(
    String junkshopId,
    DateTime startDate,
    DateTime endDate, {
    int limit = 5,
  }) async {
    try {
      final materials = await _materialService.getMaterialAnalytics(
        junkshopId: junkshopId,
        startDate: startDate,
        endDate: endDate,
        forceRefresh: true,
      );

      materials.sort((a, b) => b.netProfit.compareTo(a.netProfit));

      return materials.take(limit).map((m) {
        return TopPerformer(
          id: m.materialName,
          name: m.materialName,
          value: m.netProfit,
          secondaryValue: m.profitMargin,
          unit: '%',
          type: 'material',
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error getting top materials: $e');
      return [];
    }
  }

  Future<List<TopPerformer>> _getTopCustomers(
    String junkshopId,
    DateTime startDate,
    DateTime endDate, {
    int limit = 5,
  }) async {
    try {
      // Query both household collections AND onsite purchases — same as Customers Tab
      final collectionsSnapshot = await _collections(junkshopId, startDate, endDate);

      final purchasesSnapshot = await _q('purchases', junkshopId, from: startDate, to: endDate, eq: {'status': 'completed'});

      final customerTotals = <String, double>{};
      final customerCounts = <String, int>{};
      final customerNames = <String, String>{};

      // Process household collections
      for (final doc in collectionsSnapshot.docs) {
        final data = doc.data();
        final householdId = data['householdId'] as String? ?? '';
        final householdName = data['householdName'] as String? ?? '';
        if (householdId.isEmpty || householdName.isEmpty) continue;

        final amount =
            (data['totalJunkshopCost'] as num?)?.toDouble() ??
            (data['totalCost'] as num?)?.toDouble() ??
            0.0;
        if (amount == 0) continue;

        customerTotals[householdId] =
            (customerTotals[householdId] ?? 0) + amount;
        customerCounts[householdId] = (customerCounts[householdId] ?? 0) + 1;
        customerNames[householdId] = householdName;
      }

      // Process onsite purchases
      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        String sellerName = data['customer_name'] as String? ?? '';
        if (sellerName.isEmpty) {
          sellerName = data['customerName'] as String? ?? '';
        }
        if (sellerName.isEmpty && data['household'] is Map) {
          final h = data['household'] as Map<String, dynamic>;
          sellerName = h['full_name'] as String? ?? h['name'] as String? ?? '';
        }
        if (sellerName.isEmpty) {
          sellerName = data['sellerName'] as String? ?? '';
        }

        final sellerId =
            data['customerId'] as String? ??
            data['customer_id'] as String? ??
            data['householdId'] as String? ??
            sellerName;

        final amount =
            (data['totalAmount'] as num?)?.toDouble() ??
            (data['totalCost'] as num?)?.toDouble() ??
            0.0;
        if (amount == 0) continue;

        final key = sellerId.isNotEmpty ? sellerId : 'walkin_${doc.id}';
        final displayName = sellerName.isNotEmpty
            ? sellerName
            : 'Walk-in Customer';

        customerTotals[key] = (customerTotals[key] ?? 0) + amount;
        customerCounts[key] = (customerCounts[key] ?? 0) + 1;
        customerNames[key] ??= displayName;
      }

      final topCustomers = customerTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return topCustomers.take(limit).map((entry) {
        return TopPerformer(
          id: entry.key,
          name: customerNames[entry.key] ?? entry.key,
          value: entry.value,
          secondaryValue: customerCounts[entry.key]?.toDouble() ?? 0,
          unit: 'transactions',
          type: 'customer',
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error getting top customers: $e');
      return [];
    }
  }

  Future<List<TopPerformer>> _getTopBuyers(
    String junkshopId,
    DateTime startDate,
    DateTime endDate, {
    int limit = 5,
  }) async {
    try {
      final snapshot = await _q('sales', junkshopId, from: startDate, to: endDate);

      final buyerTotals = <String, double>{};
      final buyerCounts = <String, int>{};

      if (snapshot.docs.isNotEmpty) {
        if (kDebugMode) {
          print(
            '📋 Sample Sales document fields: ${snapshot.docs.first.data().keys.join(", ")}',
          );
        }
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Check if buyer is a Map (object) or String
        final buyerField = data['buyer'];
        String buyerName = 'Unknown Buyer';

        if (buyerField is Map<String, dynamic>) {
          // If buyer is an object, try to get the name from it
          buyerName =
              buyerField['name'] as String? ??
              buyerField['buyerName'] as String? ??
              buyerField['customerName'] as String? ??
              'Unknown Buyer';
        } else if (buyerField is String) {
          // If buyer is a string directly
          buyerName = buyerField;
        } else {
          // Fallback to other possible field names
          buyerName =
              data['buyerName'] as String? ??
              data['buyer_name'] as String? ??
              data['customerName'] as String? ??
              data['customer_name'] as String? ??
              data['customer'] as String? ??
              'Unknown Buyer';
        }

        if (kDebugMode) {
          print(
            '  Sales ${doc.id}: buyer="$buyerName" (type: ${buyerField.runtimeType})',
          );
        }

        if (buyerName.isNotEmpty) {
          final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
          buyerTotals[buyerName] = (buyerTotals[buyerName] ?? 0) + amount;
          buyerCounts[buyerName] = (buyerCounts[buyerName] ?? 0) + 1;
        }
      }

      final topBuyers = buyerTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return topBuyers.take(limit).map((entry) {
        return TopPerformer(
          id: entry.key,
          name: entry.key,
          value: entry.value,
          secondaryValue: buyerCounts[entry.key]?.toDouble() ?? 0,
          unit: 'transactions',
          type: 'buyer',
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error getting top buyers: $e');
      return [];
    }
  }

  Future<List<AlertItem>> _generateAlerts(
    String junkshopId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final alerts = <AlertItem>[];

      final materials = await _materialService.getMaterialAnalytics(
        junkshopId: junkshopId,
        startDate: startDate,
        endDate: endDate,
        forceRefresh: true,
      );

      for (final material in materials) {
        if (material.currentStock < 10 && material.status != 'stagnant') {
          alerts.add(
            AlertItem(
              id: 'low_stock_${material.materialName}',
              title: 'Low Stock Alert',
              message:
                  '${material.materialName} stock is critically low (${material.currentStock} ${material.unit})',
              severity: AlertSeverity.critical,
              type: AlertType.lowStock,
              actionRoute: '/analytics/materials',
            ),
          );
        }

        if (material.status == 'stagnant') {
          alerts.add(
            AlertItem(
              id: 'stagnant_${material.materialName}',
              title: 'Stagnant Material',
              message: '${material.materialName} has no sales activity',
              severity: AlertSeverity.warning,
              type: AlertType.stagnantMaterial,
              actionRoute: '/analytics/materials',
            ),
          );
        }

        if (material.profitMargin < 10 &&
            material.salesData.transactionCount > 0) {
          alerts.add(
            AlertItem(
              id: 'low_margin_${material.materialName}',
              title: 'Low Profit Margin',
              message:
                  '${material.materialName} margin is only ${material.profitMargin.toStringAsFixed(1)}%',
              severity: AlertSeverity.warning,
              type: AlertType.lowMargin,
              actionRoute: '/analytics/materials',
            ),
          );
        }
      }

      alerts.sort((a, b) => a.severity.index.compareTo(b.severity.index));

      return alerts.take(5).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error generating alerts: $e');
      return [];
    }
  }

  Map<String, DateTime> _calculatePreviousPeriod(
    DateTime startDate,
    DateTime endDate,
  ) {
    final duration = endDate.difference(startDate);
    final previousEnd = startDate.subtract(const Duration(seconds: 1));
    final previousStart = previousEnd.subtract(duration);

    return {'start': previousStart, 'end': previousEnd};
  }
}


/// Minimal document wrapper so analytics code can keep `doc.id` / `doc.data()`.
class _Doc {
  _Doc(this._data);
  final Map<String, dynamic> _data;
  String get id => _data['id'].toString();
  Map<String, dynamic> data() => _data;
}

class _Snap {
  const _Snap(this.docs);
  final List<_Doc> docs;
}
