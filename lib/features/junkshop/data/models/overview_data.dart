class OverviewData {
  final SummaryTotals summaryTotals;
  final PeriodComparison? purchaseComparison;
  final PeriodComparison? salesComparison;
  final PeriodComparison? profitComparison;
  final PeriodComparison? inventoryComparison;
  final List<TrendDataPoint> purchasesTrend;
  final List<TrendDataPoint> salesTrend;
  final List<TrendDataPoint> profitTrend;
  final List<TopPerformer> topMaterials;
  final List<TopPerformer> topCustomers;
  final List<TopPerformer> topBuyers;
  final List<AlertItem> alerts;
  final DateTime startDate;
  final DateTime endDate;

  OverviewData({
    required this.summaryTotals,
    this.purchaseComparison,
    this.salesComparison,
    this.profitComparison,
    this.inventoryComparison,
    required this.purchasesTrend,
    required this.salesTrend,
    required this.profitTrend,
    required this.topMaterials,
    required this.topCustomers,
    required this.topBuyers,
    required this.alerts,
    required this.startDate,
    required this.endDate,
  });

  factory OverviewData.empty() {
    final now = DateTime.now();
    return OverviewData(
      summaryTotals: SummaryTotals.empty(),
      purchasesTrend: [],
      salesTrend: [],
      profitTrend: [],
      topMaterials: [],
      topCustomers: [],
      topBuyers: [],
      alerts: [],
      startDate: now,
      endDate: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summaryTotals': summaryTotals.toJson(),
      'purchaseComparison': purchaseComparison?.toJson(),
      'salesComparison': salesComparison?.toJson(),
      'profitComparison': profitComparison?.toJson(),
      'inventoryComparison': inventoryComparison?.toJson(),
      'purchasesTrend': purchasesTrend.map((e) => e.toJson()).toList(),
      'salesTrend': salesTrend.map((e) => e.toJson()).toList(),
      'profitTrend': profitTrend.map((e) => e.toJson()).toList(),
      'topMaterials': topMaterials.map((e) => e.toJson()).toList(),
      'topCustomers': topCustomers.map((e) => e.toJson()).toList(),
      'topBuyers': topBuyers.map((e) => e.toJson()).toList(),
      'alerts': alerts.map((e) => e.toJson()).toList(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  factory OverviewData.fromJson(Map<String, dynamic> json) {
    return OverviewData(
      summaryTotals: SummaryTotals.fromJson(json['summaryTotals']),
      purchaseComparison: json['purchaseComparison'] != null
          ? PeriodComparison.fromJson(json['purchaseComparison'])
          : null,
      salesComparison: json['salesComparison'] != null
          ? PeriodComparison.fromJson(json['salesComparison'])
          : null,
      profitComparison: json['profitComparison'] != null
          ? PeriodComparison.fromJson(json['profitComparison'])
          : null,
      inventoryComparison: json['inventoryComparison'] != null
          ? PeriodComparison.fromJson(json['inventoryComparison'])
          : null,
      purchasesTrend:
          (json['purchasesTrend'] as List<dynamic>?)
              ?.map((e) => TrendDataPoint.fromJson(e))
              .toList() ??
          [],
      salesTrend:
          (json['salesTrend'] as List<dynamic>?)
              ?.map((e) => TrendDataPoint.fromJson(e))
              .toList() ??
          [],
      profitTrend:
          (json['profitTrend'] as List<dynamic>?)
              ?.map((e) => TrendDataPoint.fromJson(e))
              .toList() ??
          [],
      topMaterials:
          (json['topMaterials'] as List<dynamic>?)
              ?.map((e) => TopPerformer.fromJson(e))
              .toList() ??
          [],
      topCustomers:
          (json['topCustomers'] as List<dynamic>?)
              ?.map((e) => TopPerformer.fromJson(e))
              .toList() ??
          [],
      topBuyers:
          (json['topBuyers'] as List<dynamic>?)
              ?.map((e) => TopPerformer.fromJson(e))
              .toList() ??
          [],
      alerts:
          (json['alerts'] as List<dynamic>?)
              ?.map((e) => AlertItem.fromJson(e))
              .toList() ??
          [],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
    );
  }
}

class SummaryTotals {
  final double totalPurchases;
  final double totalSales;
  final double netProfit;
  final double totalInventory;
  final int purchaseCount;
  final int salesCount;
  final double profitMargin;

  SummaryTotals({
    required this.totalPurchases,
    required this.totalSales,
    required this.netProfit,
    required this.totalInventory,
    required this.purchaseCount,
    required this.salesCount,
    required this.profitMargin,
  });

  factory SummaryTotals.empty() {
    return SummaryTotals(
      totalPurchases: 0,
      totalSales: 0,
      netProfit: 0,
      totalInventory: 0,
      purchaseCount: 0,
      salesCount: 0,
      profitMargin: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalPurchases': totalPurchases,
      'totalSales': totalSales,
      'netProfit': netProfit,
      'totalInventory': totalInventory,
      'purchaseCount': purchaseCount,
      'salesCount': salesCount,
      'profitMargin': profitMargin,
    };
  }

  factory SummaryTotals.fromJson(Map<String, dynamic> json) {
    return SummaryTotals(
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0,
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0,
      netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0,
      totalInventory: (json['totalInventory'] as num?)?.toDouble() ?? 0,
      purchaseCount: (json['purchaseCount'] as num?)?.toInt() ?? 0,
      salesCount: (json['salesCount'] as num?)?.toInt() ?? 0,
      profitMargin: (json['profitMargin'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PeriodComparison {
  final double currentValue;
  final double previousValue;
  final double percentageChange;
  final bool isIncrease;
  final String label;

  PeriodComparison({
    required this.currentValue,
    required this.previousValue,
    required this.percentageChange,
    required this.isIncrease,
    required this.label,
  });

  factory PeriodComparison.calculate({
    required double current,
    required double previous,
  }) {
    if (previous == 0) {
      if (current == 0) {
        return PeriodComparison(
          currentValue: current,
          previousValue: previous,
          percentageChange: 0,
          isIncrease: false,
          label: 'No change',
        );
      }
      return PeriodComparison(
        currentValue: current,
        previousValue: previous,
        percentageChange: 100,
        isIncrease: current > 0,
        label: current > 0 ? '+100% ↑' : '-100% ↓',
      );
    }

    final change = ((current - previous) / previous) * 100;
    final isIncrease = change > 0;
    final arrow = isIncrease ? '↑' : '↓';
    final sign = isIncrease ? '+' : '';
    final label = '$sign${change.abs().toStringAsFixed(1)}% $arrow';

    return PeriodComparison(
      currentValue: current,
      previousValue: previous,
      percentageChange: change,
      isIncrease: isIncrease,
      label: label,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentValue': currentValue,
      'previousValue': previousValue,
      'percentageChange': percentageChange,
      'isIncrease': isIncrease,
      'label': label,
    };
  }

  factory PeriodComparison.fromJson(Map<String, dynamic> json) {
    return PeriodComparison(
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
      previousValue: (json['previousValue'] as num?)?.toDouble() ?? 0,
      percentageChange: (json['percentageChange'] as num?)?.toDouble() ?? 0,
      isIncrease: json['isIncrease'] as bool? ?? false,
      label: json['label'] as String? ?? '',
    );
  }
}

class TrendDataPoint {
  final DateTime date;
  final double value;
  final String label;

  TrendDataPoint({
    required this.date,
    required this.value,
    required this.label,
  });

  Map<String, dynamic> toJson() {
    return {'date': date.toIso8601String(), 'value': value, 'label': label};
  }

  factory TrendDataPoint.fromJson(Map<String, dynamic> json) {
    return TrendDataPoint(
      date: DateTime.parse(json['date'] as String),
      value: (json['value'] as num?)?.toDouble() ?? 0,
      label: json['label'] as String? ?? '',
    );
  }
}

class TopPerformer {
  final String id;
  final String name;
  final double value;
  final double secondaryValue;
  final String unit;
  final String type;

  TopPerformer({
    required this.id,
    required this.name,
    required this.value,
    this.secondaryValue = 0,
    this.unit = '',
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'secondaryValue': secondaryValue,
      'unit': unit,
      'type': type,
    };
  }

  factory TopPerformer.fromJson(Map<String, dynamic> json) {
    return TopPerformer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      secondaryValue: (json['secondaryValue'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }
}

class AlertItem {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final AlertType type;
  final String? actionRoute;
  final Map<String, dynamic>? actionParams;

  AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.type,
    this.actionRoute,
    this.actionParams,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'severity': severity.name,
      'type': type.name,
      'actionRoute': actionRoute,
      'actionParams': actionParams,
    };
  }

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: AlertSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AlertSeverity.info,
      ),
      type: AlertType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AlertType.info,
      ),
      actionRoute: json['actionRoute'] as String?,
      actionParams: json['actionParams'] as Map<String, dynamic>?,
    );
  }
}

enum AlertSeverity { critical, warning, info }

enum AlertType {
  lowStock,
  stagnantMaterial,
  lowMargin,
  salesSpike,
  noSales,
  info,
}
