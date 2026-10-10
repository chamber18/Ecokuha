import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/cache_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class Transaction {
  final String id;
  final DateTime date;
  final double weight;
  final double price;
  final double pricePerUnit;
  final String type;

  Transaction({
    required this.id,
    required this.date,
    required this.weight,
    required this.price,
    required this.pricePerUnit,
    required this.type,
  });

  factory Transaction.fromDoc(
    Map<String, dynamic> data,
    String type,
    String materialName, {
    String? materialId,
  }) {
    final docId = data['id'].toString();

    if (type == 'purchase') {
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

      Map<String, dynamic>? materialItem;

      materialItem = items.cast<Map<String, dynamic>?>().firstWhere((item) {
        if (item == null) return false;
        final itemMaterial = item['material']?.toString().toLowerCase() ?? '';
        final itemName = item['name']?.toString().toLowerCase() ?? '';
        final itemMaterialName =
            item['materialName']?.toString().toLowerCase() ?? '';
        final itemType = item['type']?.toString().toLowerCase() ?? '';
        final itemMaterialId = item['materialId']?.toString() ?? '';
        final searchName = materialName.toLowerCase();

        // Match by name fields OR materialId
        final nameMatch =
            itemMaterial == searchName ||
            itemName == searchName ||
            itemMaterialName == searchName ||
            itemType == searchName;
        final idMatch =
            materialId != null &&
            itemMaterialId.isNotEmpty &&
            itemMaterialId == materialId;

        return nameMatch || idMatch;
      }, orElse: () => null);

      if (materialItem == null || materialItem.isEmpty) {
        return Transaction(
          id: docId,
          date:
              (data['createdAt'] as Timestamp?)?.toDate() ??
              (data['completedAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          weight: 0,
          price: 0,
          pricePerUnit: 0,
          type: type,
        );
      }

      final quantityStr =
          materialItem['quantity']?.toString() ??
          materialItem['weight']?.toString() ??
          '0';
      final weight = double.tryParse(quantityStr) ?? 0.0;
      final price =
          (materialItem['junkshopPricePerUnit'] as num?)?.toDouble() ??
          (materialItem['pricePerUnit'] as num?)?.toDouble() ??
          (materialItem['price'] as num?)?.toDouble() ??
          0;

      return Transaction(
        id: docId,
        date:
            (data['createdAt'] as Timestamp?)?.toDate() ??
            (data['completedAt'] as Timestamp?)?.toDate() ??
            DateTime.now(),
        weight: weight,
        price: weight * price,
        pricePerUnit: price,
        type: type,
      );
    } else if (type == 'collection') {
      // Handle completed household collections with purchasedItems
      final purchasedRaw = data['purchasedItems'];
      final items = List<Map<String, dynamic>>.from(
        (purchasedRaw is Map ? purchasedRaw['list'] : purchasedRaw) ?? [],
      );

      Map<String, dynamic>? materialItem;

      materialItem = items.cast<Map<String, dynamic>?>().firstWhere((item) {
        if (item == null) return false;
        final itemMaterial = item['material']?.toString().toLowerCase() ?? '';
        final itemName = item['name']?.toString().toLowerCase() ?? '';
        final itemMaterialName =
            item['materialName']?.toString().toLowerCase() ?? '';
        final itemType = item['type']?.toString().toLowerCase() ?? '';
        final itemMaterialId = item['materialId']?.toString() ?? '';
        final searchName = materialName.toLowerCase();

        // Match by name fields OR materialId
        final nameMatch =
            itemMaterial == searchName ||
            itemName == searchName ||
            itemMaterialName == searchName ||
            itemType == searchName;
        final idMatch =
            materialId != null &&
            itemMaterialId.isNotEmpty &&
            itemMaterialId == materialId;

        return nameMatch || idMatch;
      }, orElse: () => null);

      if (materialItem == null || materialItem.isEmpty) {
        return Transaction(
          id: docId,
          date:
              (data['completedAt'] as Timestamp?)?.toDate() ??
              (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          weight: 0,
          price: 0,
          pricePerUnit: 0,
          type: type,
        );
      }

      final quantityStr =
          materialItem['quantity']?.toString() ??
          materialItem['weight']?.toString() ??
          '0';
      final weight = double.tryParse(quantityStr) ?? 0.0;
      final price =
          (materialItem['junkshopPricePerUnit'] as num?)?.toDouble() ??
          (materialItem['pricePerUnit'] as num?)?.toDouble() ??
          (materialItem['price'] as num?)?.toDouble() ??
          0;

      return Transaction(
        id: docId,
        date:
            (data['completedAt'] as Timestamp?)?.toDate() ??
            (data['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.now(),
        weight: weight,
        price: weight * price,
        pricePerUnit: price,
        type: type,
      );
    } else {
      final items = List<Map<String, dynamic>>.from(
        data['items'] ?? data['soldItems'] ?? [],
      );

      Map<String, dynamic>? materialItem;

      materialItem = items.cast<Map<String, dynamic>?>().firstWhere((item) {
        if (item == null) return false;
        final itemMaterial = item['material']?.toString().toLowerCase() ?? '';
        final itemName = item['name']?.toString().toLowerCase() ?? '';
        final itemMaterialName =
            item['materialName']?.toString().toLowerCase() ?? '';
        final itemType = item['type']?.toString().toLowerCase() ?? '';
        final itemMaterialId = item['materialId']?.toString() ?? '';
        final searchName = materialName.toLowerCase();

        // Match by name fields OR materialId
        final nameMatch =
            itemMaterial == searchName ||
            itemName == searchName ||
            itemMaterialName == searchName ||
            itemType == searchName;
        final idMatch =
            materialId != null &&
            itemMaterialId.isNotEmpty &&
            itemMaterialId == materialId;

        return nameMatch || idMatch;
      }, orElse: () => null);

      if (materialItem == null || materialItem.isEmpty) {
        return Transaction(
          id: docId,
          date:
              (data['saleDate'] as Timestamp?)?.toDate() ??
              (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          weight: 0,
          price: 0,
          pricePerUnit: 0,
          type: type,
        );
      }

      final quantityStr =
          materialItem['quantity']?.toString() ??
          materialItem['weight']?.toString() ??
          '0';
      final weight =
          double.tryParse(quantityStr) ??
          (materialItem['weight'] as num?)?.toDouble() ??
          0.0;
      final price =
          (materialItem['price'] as num?)?.toDouble() ??
          (materialItem['pricePerUnit'] as num?)?.toDouble() ??
          (materialItem['salePrice'] as num?)?.toDouble() ??
          0;

      return Transaction(
        id: docId,
        date:
            (data['saleDate'] as Timestamp?)?.toDate() ??
            (data['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.now(),
        weight: weight,
        price: weight * price,
        pricePerUnit: price,
        type: type,
      );
    }
  }
}

class PurchaseData {
  final double totalWeight;
  final double totalCost;
  final double avgPricePerUnit;
  final double minPricePerUnit;
  final double maxPricePerUnit;
  final int transactionCount;

  PurchaseData({
    required this.totalWeight,
    required this.totalCost,
    required this.avgPricePerUnit,
    required this.minPricePerUnit,
    required this.maxPricePerUnit,
    required this.transactionCount,
  });

  factory PurchaseData.empty() => PurchaseData(
    totalWeight: 0,
    totalCost: 0,
    avgPricePerUnit: 0,
    minPricePerUnit: 0,
    maxPricePerUnit: 0,
    transactionCount: 0,
  );
}

class SalesData {
  final double totalWeight;
  final double totalRevenue;
  final double avgPricePerUnit;
  final double minPricePerUnit;
  final double maxPricePerUnit;
  final int transactionCount;

  SalesData({
    required this.totalWeight,
    required this.totalRevenue,
    required this.avgPricePerUnit,
    required this.minPricePerUnit,
    required this.maxPricePerUnit,
    required this.transactionCount,
  });

  factory SalesData.empty() => SalesData(
    totalWeight: 0,
    totalRevenue: 0,
    avgPricePerUnit: 0,
    minPricePerUnit: 0,
    maxPricePerUnit: 0,
    transactionCount: 0,
  );
}

class MaterialMetrics {
  final String materialName;
  final double currentStock;
  final double stockValue;
  final PurchaseData purchaseData;
  final SalesData salesData;
  final double netProfit;
  final double profitMargin;
  final DateTime? lastSaleDate;
  final String status;
  final List<double>? monthlyProfits; // Last 6 months profit data
  final List<double>? monthlyPurchaseWeights; // Last 6 months purchase weights
  final List<double>? monthlySalesWeights; // Last 6 months sales weights
  final String? unit; // Unit of measurement (kg, piece, etc.)

  MaterialMetrics({
    required this.materialName,
    required this.currentStock,
    required this.stockValue,
    required this.purchaseData,
    required this.salesData,
    required this.netProfit,
    required this.profitMargin,
    this.lastSaleDate,
    required this.status,
    this.monthlyProfits,
    this.monthlyPurchaseWeights,
    this.monthlySalesWeights,
    this.unit = 'kg', // Default to kg
  });

  factory MaterialMetrics.fromData({
    required String materialName,
    required double currentStock,
    required double stockValue,
    required List<Transaction> purchases,
    required List<Transaction> sales,
    required DateTime? lastSaleDate,
    String unit = 'kg', // Accept unit parameter
  }) {
    final purchaseData = _calculatePurchaseData(purchases);
    final salesData = _calculateSalesData(sales);
    final monthlyProfits = _calculateMonthlyProfits(purchases, sales);
    final monthlyPurchaseWeights = _calculateMonthlyWeights(purchases);
    final monthlySalesWeights = _calculateMonthlyWeights(sales);

    final netProfit = salesData.totalRevenue - purchaseData.totalCost;
    final profitMargin = purchaseData.totalCost > 0
        ? (netProfit / purchaseData.totalCost) * 100
        : 0.0;

    final status = _determineStatus(lastSaleDate);

    return MaterialMetrics(
      materialName: materialName,
      currentStock: currentStock,
      stockValue: stockValue,
      purchaseData: purchaseData,
      salesData: salesData,
      netProfit: netProfit,
      profitMargin: profitMargin.toDouble(),
      lastSaleDate: lastSaleDate,
      status: status,
      monthlyProfits: monthlyProfits,
      monthlyPurchaseWeights: monthlyPurchaseWeights,
      monthlySalesWeights: monthlySalesWeights,
      unit: unit,
    );
  }

  static PurchaseData _calculatePurchaseData(List<Transaction> purchases) {
    if (purchases.isEmpty) return PurchaseData.empty();

    final totalWeight = purchases.fold<double>(0, (acc, t) => acc + t.weight);

    final totalCost = purchases.fold<double>(0, (acc, t) => acc + t.price);

    if (totalCost > 0) {
      if (kDebugMode) {
        print(
          '  💵 Purchase calculation: ${purchases.length} transactions, total: ₱${totalCost.toStringAsFixed(2)}',
        );
      }
      for (var t in purchases.take(3)) {
        if (kDebugMode) {
          print(
            '    - ${t.date.toString().substring(0, 10)}: ${t.weight} kg × ₱${t.pricePerUnit}/kg = ₱${t.price.toStringAsFixed(2)}',
          );
        }
      }
    }

    final prices = purchases
        .where((t) => t.pricePerUnit > 0)
        .map((t) => t.pricePerUnit)
        .toList();

    final avgPricePerUnit = totalWeight > 0 ? totalCost / totalWeight : 0.0;
    final minPricePerUnit = prices.isEmpty
        ? 0.0
        : prices.reduce((a, b) => a < b ? a : b);
    final maxPricePerUnit = prices.isEmpty
        ? 0.0
        : prices.reduce((a, b) => a > b ? a : b);

    return PurchaseData(
      totalWeight: totalWeight,
      totalCost: totalCost,
      avgPricePerUnit: avgPricePerUnit.toDouble(),
      minPricePerUnit: minPricePerUnit.toDouble(),
      maxPricePerUnit: maxPricePerUnit.toDouble(),
      transactionCount: purchases.length,
    );
  }

  static SalesData _calculateSalesData(List<Transaction> sales) {
    if (sales.isEmpty) return SalesData.empty();

    final totalWeight = sales.fold<double>(0, (acc, t) => acc + t.weight);

    final totalRevenue = sales.fold<double>(0, (acc, t) => acc + t.price);

    final prices = sales
        .where((t) => t.pricePerUnit > 0)
        .map((t) => t.pricePerUnit)
        .toList();

    final avgPricePerUnit = totalWeight > 0 ? totalRevenue / totalWeight : 0.0;
    final minPricePerUnit = prices.isEmpty
        ? 0.0
        : prices.reduce((a, b) => a < b ? a : b);
    final maxPricePerUnit = prices.isEmpty
        ? 0.0
        : prices.reduce((a, b) => a > b ? a : b);

    return SalesData(
      totalWeight: totalWeight,
      totalRevenue: totalRevenue,
      avgPricePerUnit: avgPricePerUnit.toDouble(),
      minPricePerUnit: minPricePerUnit.toDouble(),
      maxPricePerUnit: maxPricePerUnit.toDouble(),
      transactionCount: sales.length,
    );
  }

  static List<double> _calculateMonthlyProfits(
    List<Transaction> purchases,
    List<Transaction> sales,
  ) {
    final now = DateTime.now();
    final monthlyData = <int, Map<String, double>>{};

    // Initialize last 6 months
    for (int i = 0; i < 6; i++) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthKey = monthDate.year * 100 + monthDate.month;
      monthlyData[monthKey] = {'purchases': 0.0, 'sales': 0.0};
    }

    // Calculate purchase costs per month
    for (final purchase in purchases) {
      final monthKey = purchase.date.year * 100 + purchase.date.month;
      if (monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey]!['purchases'] =
            (monthlyData[monthKey]!['purchases'] ?? 0.0) + purchase.price;
      }
    }

    // Calculate sales revenue per month
    for (final sale in sales) {
      final monthKey = sale.date.year * 100 + sale.date.month;
      if (monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey]!['sales'] =
            (monthlyData[monthKey]!['sales'] ?? 0.0) + sale.price;
      }
    }

    // Calculate profit for each month (oldest to newest)
    final profits = <double>[];
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthKey = monthDate.year * 100 + monthDate.month;
      final data = monthlyData[monthKey]!;
      final profit = data['sales']! - data['purchases']!;
      profits.add(profit);
    }

    return profits;
  }

  static List<double> _calculateMonthlyWeights(List<Transaction> transactions) {
    final now = DateTime.now();
    final monthlyWeights = <int, double>{};

    // Initialize last 6 months
    for (int i = 0; i < 6; i++) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthKey = monthDate.year * 100 + monthDate.month;
      monthlyWeights[monthKey] = 0.0;
    }

    // Calculate weights per month
    for (final transaction in transactions) {
      final monthKey = transaction.date.year * 100 + transaction.date.month;
      if (monthlyWeights.containsKey(monthKey)) {
        monthlyWeights[monthKey] =
            (monthlyWeights[monthKey] ?? 0.0) + transaction.weight;
      }
    }

    // Return weights for each month (oldest to newest)
    final weights = <double>[];
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthKey = monthDate.year * 100 + monthDate.month;
      weights.add(monthlyWeights[monthKey] ?? 0.0);
    }

    return weights;
  }

  static String _detectUnitFromMaterialName(String materialName) {
    final lowerName = materialName.toLowerCase();

    // Electronics and items sold by piece
    if (lowerName.contains('phone') ||
        lowerName.contains('mobile') ||
        lowerName.contains('laptop') ||
        lowerName.contains('tablet') ||
        lowerName.contains('monitor') ||
        lowerName.contains('tv') ||
        lowerName.contains('appliance') ||
        lowerName.contains('computer') && lowerName.contains('unit') ||
        lowerName.contains('device')) {
      if (kDebugMode) print('  🔍 Detected "$materialName" as PIECE unit');
      return 'piece';
    }

    // Default to kg for recyclable materials
    if (kDebugMode) print('  🔍 Detected "$materialName" as KG unit (default)');
    return 'kg';
  }

  static String _determineStatus(DateTime? lastSaleDate) {
    if (lastSaleDate == null) return 'No Sales';

    final daysSinceLastSale = DateTime.now().difference(lastSaleDate).inDays;

    if (daysSinceLastSale <= 7) {
      return 'Active';
    } else if (daysSinceLastSale <= 30) {
      return 'Slow';
    } else {
      return 'Stagnant';
    }
  }
}

class MaterialAnalyticsService {
  final SupabaseClient _db;
  final CacheService _cacheService;

  MaterialAnalyticsService({
    SupabaseClient? supabase,
    CacheService? cacheService,
  }) : _db = supabase ?? Supabase.instance.client,
       _cacheService = cacheService ?? CacheService();

  Future<List<MaterialMetrics>> getMaterialAnalytics({
    required String junkshopId,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    try {
      // Try to load from cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await _cacheService.getMaterialAnalytics(junkshopId);
        final isCacheStale = await _cacheService.isCacheStale(
          'analytics_$junkshopId',
        );

        if (cachedData != null && !isCacheStale) {
          if (kDebugMode) print('📦 Loading material analytics from cache');
          final metrics = _deserializeCachedMetrics(cachedData);

          // Start background refresh if cache is older than 1 hour
          final lastSync = await _cacheService.getMaterialAnalyticsLastSync(
            junkshopId,
          );
          if (lastSync != null &&
              DateTime.now().difference(lastSync).inHours >= 1) {
            if (kDebugMode) {
              print('🔄 Starting background refresh of analytics data');
            }
            _refreshAnalyticsInBackground(junkshopId, startDate, endDate);
          }

          return metrics;
        }
      }

      // Fetch fresh data from Supabase
      if (kDebugMode) {
        print('🔄 Fetching fresh material analytics from Supabase');
      }
      final metrics = await _fetchMaterialAnalytics(
        junkshopId: junkshopId,
        startDate: startDate,
        endDate: endDate,
      );

      // Cache the results
      await _cacheMaterialMetrics(junkshopId, metrics);

      return metrics;
    } catch (e) {
      if (kDebugMode) print('❌ Error in getMaterialAnalytics: $e');
      rethrow;
    }
  }

  Future<List<MaterialMetrics>> _fetchMaterialAnalytics({
    required String junkshopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('📊 Starting material analytics for junkshop: $junkshopId');
      }

      final now = DateTime.now();
      // Default to 12 months so all historical stock activity is included
      final effectiveStartDate =
          startDate ?? DateTime(now.year - 1, now.month, 1);
      final effectiveEndDate = endDate ?? now;

      if (kDebugMode) {
        print(
          '📅 Date range: ${effectiveStartDate.toString()} to ${effectiveEndDate.toString()}',
        );
      }

      final materialRows = await _db
          .from('junkshop_materials')
          .select()
          .eq('junkshop_id', junkshopId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              if (kDebugMode) print('⏱️ Materials query timed out');
              throw Exception('Request timed out. Please try again.');
            },
          );
      final materialDocs = rowsToDocs('junkshop_materials', materialRows);

      if (kDebugMode) {
        print('📦 Found ${materialDocs.length} materials');
      }

      if (materialDocs.isEmpty) {
        if (kDebugMode) print('ℹ️ No materials found in database');
        return [];
      }

      final startIso = effectiveStartDate.toUtc().toIso8601String();
      final endIso = effectiveEndDate.toUtc().toIso8601String();

      // Fetch manual walk-in purchases
      final purchaseRows = await _db
          .from('purchases')
          .select()
          .eq('junkshop_id', junkshopId)
          .gte('created_at', startIso)
          .lte('created_at', endIso)
          .timeout(const Duration(seconds: 10));
      final purchaseDocs = rowsToDocs('purchases', purchaseRows);

      // Fetch completed household collections (additional purchase source)
      final collectionRows = await _db
          .from('postings')
          .select()
          .eq('junkshop_id', junkshopId)
          .eq('status', 'completed')
          .gte('completed_at', startIso)
          .lte('completed_at', endIso)
          .timeout(const Duration(seconds: 10));
      final collectionDocs = rowsToDocs('postings', collectionRows);

      final saleRows = await _db
          .from('sales')
          .select()
          .eq('junkshop_id', junkshopId)
          .gte('created_at', startIso)
          .lte('created_at', endIso)
          .timeout(const Duration(seconds: 10));
      final saleDocs = rowsToDocs('sales', saleRows);

      // Debug: Show sample data structure
      if (purchaseDocs.isNotEmpty) {
        final samplePurchase = purchaseDocs.first;
        final sampleItems = List<Map<String, dynamic>>.from(
          samplePurchase['items'] ?? [],
        );
        if (sampleItems.isNotEmpty) {
          if (kDebugMode) {
            print(
              '📋 Sample purchase item fields: ${sampleItems.first.keys.join(", ")}',
            );
          }
        }
      }
      if (saleDocs.isNotEmpty) {
        final sampleSale = saleDocs.first;
        final sampleItems = List<Map<String, dynamic>>.from(
          sampleSale['items'] ?? [],
        );
        if (sampleItems.isNotEmpty) {
          if (kDebugMode) {
            print(
              '📋 Sample sale item fields: ${sampleItems.first.keys.join(", ")}',
            );
          }
        }
      }

      final List<MaterialMetrics> metrics = [];

      // Debug: Show first material document structure
      if (materialDocs.isNotEmpty) {
        final sampleMaterial = materialDocs.first;
        if (kDebugMode) {
          print(
            '📋 Sample material document fields: ${sampleMaterial.keys.join(", ")}',
          );
        }
        if (sampleMaterial.containsKey('stock')) {
          if (kDebugMode) print('✅ Has stock: ${sampleMaterial['stock']}');
        }
        if (sampleMaterial.containsKey('currentStock')) {
          if (kDebugMode) {
            print('✅ Has currentStock: ${sampleMaterial['currentStock']}');
          }
        }
      }

      for (var i = 0; i < materialDocs.length; i++) {
        final materialData = materialDocs[i];
        final materialName = materialData['name'] as String? ?? 'Unknown';

        // Try both 'stock' and 'currentStock' field names
        final currentStock =
            (materialData['currentStock'] as num?)?.toDouble() ??
            (materialData['stock'] as num?)?.toDouble() ??
            0;

        // Get average purchase cost from material data
        final avgPurchaseCost =
            (materialData['avgPurchaseCost'] as num?)?.toDouble() ??
            (materialData['averageCost'] as num?)?.toDouble() ??
            (materialData['costPerUnit'] as num?)?.toDouble() ??
            0;

        // Get unit from material data, default to 'kg'
        final unit =
            materialData['unit'] as String? ??
            MaterialMetrics._detectUnitFromMaterialName(materialName);

        // Process purchases from walk-in transactions
        final walkInPurchases = _extractTransactionsForMaterial(
          purchaseDocs,
          materialName,
          'purchase',
          materialId: materialData['id'].toString(),
        );

        // Process purchases from completed collections
        final collectionPurchases = _extractTransactionsForMaterial(
          collectionDocs,
          materialName,
          'collection',
          materialId: materialData['id'].toString(),
        );

        // Combine both sources
        final purchases = [...walkInPurchases, ...collectionPurchases];

        // Process sales for this material from already-fetched data
        final sales = _extractTransactionsForMaterial(
          saleDocs,
          materialName,
          'sale',
          materialId: materialData['id'].toString(),
        );

        // Derive last sale date from the already-filtered sales transactions
        // (more reliable than re-scanning docs, as it uses the same full
        // matching logic including materialId)
        final lastSaleDate = sales.isEmpty
            ? null
            : sales.reduce((a, b) => a.date.isAfter(b.date) ? a : b).date;

        // Calculate stock value: stock * average purchase cost
        final stockValue = currentStock * avgPurchaseCost;

        final metric = MaterialMetrics.fromData(
          materialName: materialName,
          currentStock: currentStock,
          stockValue: stockValue,
          purchases: purchases,
          sales: sales,
          lastSaleDate: lastSaleDate,
          unit: unit,
        );

        metrics.add(metric);
      }

      if (kDebugMode) {
        print('✅ Successfully loaded ${metrics.length} material metrics');
      }
      return metrics;
    } catch (e) {
      if (kDebugMode) print('❌ Error loading material analytics: $e');
      rethrow;
    }
  }

  /// Extract transactions for a specific material from already-fetched documents
  List<Transaction> _extractTransactionsForMaterial(
    List<Map<String, dynamic>> docs,
    String materialName,
    String type, {
    String? materialId,
  }) {
    final transactions = <Transaction>[];

    for (var doc in docs) {
      // Determine effective type - deeper inspection for Purchase collection
      String effectiveType = type;
      if (type == 'purchase') {
        final data = doc;
        final rawType = data['type']?.toString();
        final purchasedItems = data['purchasedItems'];
        final hasPurchasedItems =
            purchasedItems is List && purchasedItems.isNotEmpty;
        // Treat as collection if: explicit type tag says so, OR
        // has non-empty purchasedItems (even if 'items' also present)
        if (rawType == 'collection' ||
            (hasPurchasedItems && !data.containsKey('items')) ||
            (hasPurchasedItems && rawType == null)) {
          effectiveType = 'collection';
        }
      }

      final transaction = Transaction.fromDoc(
        doc,
        effectiveType,
        materialName,
        materialId: materialId,
      );
      if (transaction.weight > 0) {
        transactions.add(transaction);
      }
    }

    return transactions;
  }


  Future<Map<String, double>> getSummaryTotals({
    required String junkshopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final metrics = await getMaterialAnalytics(
        junkshopId: junkshopId,
        startDate: startDate,
        endDate: endDate,
      );

      double totalPurchases = 0;
      double totalSales = 0;
      double totalInventory = 0;
      double netProfit = 0;

      for (var metric in metrics) {
        totalPurchases += metric.purchaseData.totalCost;
        totalSales += metric.salesData.totalRevenue;
        totalInventory += metric.stockValue;
        netProfit += metric.netProfit;
      }

      if (kDebugMode) {
        print(
          '📊 Material Analytics Total Purchases: ₱${totalPurchases.toStringAsFixed(2)} from ${metrics.length} materials',
        );
      }

      return {
        'totalPurchases': totalPurchases,
        'totalSales': totalSales,
        'totalInventory': totalInventory,
        'netProfit': netProfit,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error calculating summary totals: $e');
      return {
        'totalPurchases': 0,
        'totalSales': 0,
        'totalInventory': 0,
        'netProfit': 0,
      };
    }
  }

  // ============ CACHE HELPERS ============

  Future<void> _cacheMaterialMetrics(
    String junkshopId,
    List<MaterialMetrics> metrics,
  ) async {
    try {
      final serialized = metrics.map((m) => _serializeMetrics(m)).toList();
      await _cacheService.saveMaterialAnalytics(
        junkshopId: junkshopId,
        materials: serialized,
      );
      if (kDebugMode) print('💾 Cached ${metrics.length} material metrics');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to cache material metrics: $e');
    }
  }

  Map<String, dynamic> _serializeMetrics(MaterialMetrics metrics) {
    return {
      'materialName': metrics.materialName,
      'currentStock': metrics.currentStock,
      'stockValue': metrics.stockValue,
      'purchaseData': {
        'totalWeight': metrics.purchaseData.totalWeight,
        'totalCost': metrics.purchaseData.totalCost,
        'avgPricePerUnit': metrics.purchaseData.avgPricePerUnit,
        'minPricePerUnit': metrics.purchaseData.minPricePerUnit,
        'maxPricePerUnit': metrics.purchaseData.maxPricePerUnit,
        'transactionCount': metrics.purchaseData.transactionCount,
      },
      'salesData': {
        'totalWeight': metrics.salesData.totalWeight,
        'totalRevenue': metrics.salesData.totalRevenue,
        'avgPricePerUnit': metrics.salesData.avgPricePerUnit,
        'minPricePerUnit': metrics.salesData.minPricePerUnit,
        'maxPricePerUnit': metrics.salesData.maxPricePerUnit,
        'transactionCount': metrics.salesData.transactionCount,
      },
      'netProfit': metrics.netProfit,
      'profitMargin': metrics.profitMargin,
      'lastSaleDate': metrics.lastSaleDate?.toIso8601String(),
      'status': metrics.status,
      'monthlyProfits': metrics.monthlyProfits,
      'monthlyPurchaseWeights': metrics.monthlyPurchaseWeights,
      'monthlySalesWeights': metrics.monthlySalesWeights,
      'unit': metrics.unit,
    };
  }

  List<MaterialMetrics> _deserializeCachedMetrics(
    List<Map<String, dynamic>> cached,
  ) {
    return cached.map((data) {
      return MaterialMetrics(
        materialName: data['materialName'] as String,
        currentStock: (data['currentStock'] as num).toDouble(),
        stockValue: (data['stockValue'] as num).toDouble(),
        purchaseData: PurchaseData(
          totalWeight: (data['purchaseData']['totalWeight'] as num).toDouble(),
          totalCost: (data['purchaseData']['totalCost'] as num).toDouble(),
          avgPricePerUnit: (data['purchaseData']['avgPricePerUnit'] as num)
              .toDouble(),
          minPricePerUnit: (data['purchaseData']['minPricePerUnit'] as num)
              .toDouble(),
          maxPricePerUnit: (data['purchaseData']['maxPricePerUnit'] as num)
              .toDouble(),
          transactionCount: data['purchaseData']['transactionCount'] as int,
        ),
        salesData: SalesData(
          totalWeight: (data['salesData']['totalWeight'] as num).toDouble(),
          totalRevenue: (data['salesData']['totalRevenue'] as num).toDouble(),
          avgPricePerUnit: (data['salesData']['avgPricePerUnit'] as num)
              .toDouble(),
          minPricePerUnit: (data['salesData']['minPricePerUnit'] as num)
              .toDouble(),
          maxPricePerUnit: (data['salesData']['maxPricePerUnit'] as num)
              .toDouble(),
          transactionCount: data['salesData']['transactionCount'] as int,
        ),
        netProfit: (data['netProfit'] as num).toDouble(),
        profitMargin: (data['profitMargin'] as num).toDouble(),
        lastSaleDate: data['lastSaleDate'] != null
            ? DateTime.parse(data['lastSaleDate'] as String)
            : null,
        status: data['status'] as String,
        monthlyProfits: (data['monthlyProfits'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        monthlyPurchaseWeights:
            (data['monthlyPurchaseWeights'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList(),
        monthlySalesWeights: (data['monthlySalesWeights'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        unit: data['unit'] as String?,
      );
    }).toList();
  }

  void _refreshAnalyticsInBackground(
    String junkshopId,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    Future.microtask(() async {
      try {
        final metrics = await _fetchMaterialAnalytics(
          junkshopId: junkshopId,
          startDate: startDate,
          endDate: endDate,
        );
        await _cacheMaterialMetrics(junkshopId, metrics);
        if (kDebugMode) print('✅ Background refresh completed');
      } catch (e) {
        if (kDebugMode) print('⚠️ Background refresh failed: $e');
      }
    });
  }
}
