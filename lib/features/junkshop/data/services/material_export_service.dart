import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'material_analytics_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Service for exporting material analytics data to CSV format
class MaterialExportService {
  /// Export material metrics to CSV file
  Future<void> exportMaterialsToCsv({
    required List<MaterialMetrics> materials,
    required String junkshopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (kDebugMode) print('📊 Starting CSV export for ${materials.length} materials');

      // Generate CSV data
      final csvData = _generateCsvData(materials, startDate, endDate);

      // Convert to CSV string
      final csv = const ListToCsvConverter().convert(csvData);

      // Generate filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final dateRange = startDate != null && endDate != null
          ? '_${DateFormat('yyyyMMdd').format(startDate)}_to_${DateFormat('yyyyMMdd').format(endDate)}'
          : '';
      final filename =
          'material_analytics_$junkshopId${dateRange}_$timestamp.csv';

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(csv);

      if (kDebugMode) print('✅ CSV file created: ${file.path}');

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Material Analytics Export',
        text: 'Material performance data from $startDate to $endDate',
      );

      if (kDebugMode) print('✅ CSV export completed successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Error exporting CSV: $e');
      rethrow;
    }
  }

  /// Generate CSV data rows from material metrics
  List<List<dynamic>> _generateCsvData(
    List<MaterialMetrics> materials,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final rows = <List<dynamic>>[];

    // Add header with metadata
    rows.add(['Material Analytics Export']);
    rows.add([
      'Generated:',
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    ]);
    if (startDate != null && endDate != null) {
      rows.add([
        'Date Range:',
        '${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}',
      ]);
    }
    rows.add([]); // Empty row

    // Add column headers
    rows.add([
      'Material Name',
      'Current Stock',
      'Unit',
      'Stock Value (₱)',
      'Status',
      'Days Since Last Sale',
      'Purchase Weight',
      'Purchase Cost (₱)',
      'Purchase Avg Price/Unit (₱)',
      'Purchase Transactions',
      'Sales Weight',
      'Sales Revenue (₱)',
      'Sales Avg Price/Unit (₱)',
      'Sales Transactions',
      'Net Profit (₱)',
      'Profit Margin (%)',
    ]);

    // Add data rows
    for (final material in materials) {
      final daysSinceLastSale = material.lastSaleDate != null
          ? DateTime.now().difference(material.lastSaleDate!).inDays
          : null;

      rows.add([
        material.materialName,
        material.currentStock.toStringAsFixed(2),
        material.unit ?? 'kg',
        material.stockValue.toStringAsFixed(2),
        material.status,
        daysSinceLastSale?.toString() ?? 'N/A',
        material.purchaseData.totalWeight.toStringAsFixed(2),
        material.purchaseData.totalCost.toStringAsFixed(2),
        material.purchaseData.avgPricePerUnit.toStringAsFixed(2),
        material.purchaseData.transactionCount,
        material.salesData.totalWeight.toStringAsFixed(2),
        material.salesData.totalRevenue.toStringAsFixed(2),
        material.salesData.avgPricePerUnit.toStringAsFixed(2),
        material.salesData.transactionCount,
        material.netProfit.toStringAsFixed(2),
        material.profitMargin.toStringAsFixed(2),
      ]);
    }

    // Add summary row
    rows.add([]); // Empty row
    rows.add(['Summary Statistics']);
    rows.add(['Total Materials:', materials.length]);

    final totalPurchases = materials.fold<double>(
      0,
      (sum, m) => sum + m.purchaseData.totalCost,
    );
    final totalSales = materials.fold<double>(
      0,
      (sum, m) => sum + m.salesData.totalRevenue,
    );
    final totalProfit = materials.fold<double>(
      0,
      (sum, m) => sum + m.netProfit,
    );

    rows.add(['Total Purchases (₱):', totalPurchases.toStringAsFixed(2)]);
    rows.add(['Total Sales (₱):', totalSales.toStringAsFixed(2)]);
    rows.add(['Total Net Profit (₱):', totalProfit.toStringAsFixed(2)]);

    final stagnantCount = materials.where((m) => m.status == 'Stagnant').length;
    final slowCount = materials.where((m) => m.status == 'Slow').length;
    final activeCount = materials.where((m) => m.status == 'Active').length;

    rows.add(['Active Materials:', activeCount]);
    rows.add(['Slow-Moving Materials:', slowCount]);
    rows.add(['Stagnant Materials:', stagnantCount]);

    return rows;
  }

  /// Export detailed transaction history for a specific material
  Future<void> exportMaterialTransactionHistory({
    required String materialName,
    required List<Transaction> purchases,
    required List<Transaction> sales,
  }) async {
    try {
      if (kDebugMode) print('📊 Exporting transaction history for $materialName');

      final csvData = <List<dynamic>>[];

      // Header
      csvData.add(['Transaction History - $materialName']);
      csvData.add([
        'Generated:',
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      ]);
      csvData.add([]); // Empty row

      // Purchases section
      csvData.add(['PURCHASES']);
      csvData.add(['Date', 'Weight', 'Price (₱)', 'Price per Unit (₱)']);

      for (final purchase in purchases) {
        csvData.add([
          DateFormat('yyyy-MM-dd HH:mm:ss').format(purchase.date),
          purchase.weight.toStringAsFixed(2),
          purchase.price.toStringAsFixed(2),
          purchase.pricePerUnit.toStringAsFixed(2),
        ]);
      }

      csvData.add([]); // Empty row

      // Sales section
      csvData.add(['SALES']);
      csvData.add(['Date', 'Weight', 'Revenue (₱)', 'Price per Unit (₱)']);

      for (final sale in sales) {
        csvData.add([
          DateFormat('yyyy-MM-dd HH:mm:ss').format(sale.date),
          sale.weight.toStringAsFixed(2),
          sale.price.toStringAsFixed(2),
          sale.pricePerUnit.toStringAsFixed(2),
        ]);
      }

      // Convert to CSV and save
      final csv = const ListToCsvConverter().convert(csvData);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename =
          '${materialName.replaceAll(' ', '_')}_transactions_$timestamp.csv';

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'Transaction History - $materialName');

      if (kDebugMode) print('✅ Transaction history export completed');
    } catch (e) {
      if (kDebugMode) print('❌ Error exporting transaction history: $e');
      rethrow;
    }
  }
}
