import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../bloc/material_analytics/material_analytics_bloc.dart';
import '../../bloc/material_analytics/material_analytics_state.dart';
import '../../../data/services/material_analytics_service.dart';
import '../../utils/formatters.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class MaterialDetailScreen extends StatelessWidget {
  final String materialName;

  const MaterialDetailScreen({super.key, required this.materialName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(materialName.replaceAll('_', ' ')),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<MaterialAnalyticsBloc, MaterialAnalyticsState>(
        builder: (context, state) {
          if (state is! MaterialAnalyticsLoaded) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen,
                ),
              ),
            );
          }

          final material = state.materials.firstWhere(
            (m) => m.materialName == materialName,
            orElse: () => throw Exception('Material not found'),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(material),
                const SizedBox(height: AppDimensions.spacing16),
                _buildPurchaseVsSalesChart(material),
                const SizedBox(height: AppDimensions.spacing16),
                _buildProfitTrendChart(material),
                const SizedBox(height: AppDimensions.spacing16),
                _buildStockLevelChart(material),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(MaterialMetrics material) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: AppTextStyles.h4.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
              'Purchases',
              '${Formatters.formatWeight(material.purchaseData.totalWeight, unit: material.unit ?? 'kg')} • ${Formatters.formatCurrency(material.purchaseData.totalCost)}',
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Sales',
              '${Formatters.formatWeight(material.salesData.totalWeight, unit: material.unit ?? 'kg')} • ${Formatters.formatCurrency(material.salesData.totalRevenue)}',
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Profit Margin',
              '${material.profitMargin.toStringAsFixed(1)}%',
              valueColor: material.profitMargin >= 0
                  ? AppColors.primaryGreen
                  : Colors.red,
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Stock Value',
              Formatters.formatCurrency(material.stockValue),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Last Sale',
              material.lastSaleDate != null
                  ? Formatters.formatDate(material.lastSaleDate!)
                  : 'Never',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetricBox(
                    'Avg Purchase',
                    Formatters.formatCurrency(
                      material.purchaseData.avgPricePerUnit,
                    ),
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricBox(
                    'Avg Sales',
                    Formatters.formatCurrency(
                      material.salesData.avgPricePerUnit,
                    ),
                    Icons.point_of_sale,
                    AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseVsSalesChart(MaterialMetrics material) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchase vs Sales Weight',
              style: AppTextStyles.h5.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last 6 months trend',
              style: AppTextStyles.caption.copyWith(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 20,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final now = DateTime.now();
                          final idx = value.toInt();
                          if (idx >= 0 && idx < 6) {
                            final month = DateTime(
                              now.year,
                              now.month - 5 + idx,
                            );
                            const abbr = [
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'May',
                              'Jun',
                              'Jul',
                              'Aug',
                              'Sep',
                              'Oct',
                              'Nov',
                              'Dec',
                            ];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                abbr[month.month - 1],
                                style: AppTextStyles.caption,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final unit = material.unit ?? 'kg';
                          return Text(
                            '${value.toInt()}${unit == 'piece' ? '' : unit}',
                            style: AppTextStyles.caption,
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  minX: 0,
                  maxX: 5,
                  minY: 0,
                  maxY: _calculateMaxWeight(material),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generatePurchaseSpots(material),
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: AppColors.primaryGreen,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.primaryGreen,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      ),
                    ),
                    LineChartBarData(
                      spots: _generateSalesSpots(material),
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: Colors.blue[600]!,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.blue[600]!,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Purchases', AppColors.primaryGreen),
                const SizedBox(width: AppDimensions.spacing24),
                _buildLegendItem('Sales', Colors.blue[600]!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitTrendChart(MaterialMetrics material) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profit Trend',
              style: AppTextStyles.h5.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Monthly profit over last 6 months',
              style: AppTextStyles.caption.copyWith(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: _calculateMinProfit(material),
                  maxY: _calculateMaxProfit(material),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '₱${rod.toY.toStringAsFixed(0)}',
                          AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval:
                        ((_calculateMaxProfit(material) -
                                    _calculateMinProfit(material)) /
                                5)
                            .clamp(1.0, double.infinity),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final now = DateTime.now();
                          final idx = value.toInt();
                          if (idx >= 0 && idx < 6) {
                            final month = DateTime(
                              now.year,
                              now.month - 5 + idx,
                            );
                            const abbr = [
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'May',
                              'Jun',
                              'Jul',
                              'Aug',
                              'Sep',
                              'Oct',
                              'Nov',
                              'Dec',
                            ];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                abbr[month.month - 1],
                                style: AppTextStyles.caption,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval:
                            ((_calculateMaxProfit(material) -
                                        _calculateMinProfit(material)) /
                                    5)
                                .clamp(1.0, double.infinity),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '₱${value.toInt()}',
                            style: AppTextStyles.caption,
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  barGroups: _generateProfitBars(material),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockLevelChart(MaterialMetrics material) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Stock Level',
              style: AppTextStyles.h5.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Real-time inventory status',
              style: AppTextStyles.caption.copyWith(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Stock',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey[600],
                          fontSize: 12,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          material.currentStock.toStringAsFixed(1),
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final displayUnit = material.unit ?? 'kg';
                          final displayText = displayUnit == 'kg'
                              ? 'kilograms'
                              : displayUnit == 'piece'
                              ? 'pieces'
                              : '${displayUnit}s';
                          if (kDebugMode) {
                            print(
                              '🖥️ UI Display - Material: ${material.materialName}, Unit: ${material.unit}, Display: $displayText',
                            );
                          }
                          return Text(
                            displayText,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Stock Value',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          Formatters.formatCurrency(material.stockValue),
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 36,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildStockIndicator(material),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockIndicator(MaterialMetrics material) {
    final stockLevel = material.currentStock;
    String stockStatus;
    Color stockColor;
    IconData icon;

    if (stockLevel > 100) {
      stockStatus = 'Overstocked';
      stockColor = Colors.blue;
      icon = Icons.inventory;
    } else if (stockLevel > 50) {
      stockStatus = 'Healthy';
      stockColor = Colors.green;
      icon = Icons.check_circle;
    } else if (stockLevel > 20) {
      stockStatus = 'Low Stock';
      stockColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
    } else {
      stockStatus = 'Critical';
      stockColor = Colors.red;
      icon = Icons.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: stockColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: stockColor, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              stockStatus,
              style: AppTextStyles.bodyMedium.copyWith(
                color: stockColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: AppDimensions.spacing8),
        Text(label, style: AppTextStyles.bodyMedium),
      ],
    );
  }

  List<FlSpot> _generatePurchaseSpots(MaterialMetrics material) {
    if (material.monthlyPurchaseWeights == null ||
        material.monthlyPurchaseWeights!.isEmpty) {
      return [];
    }

    return List.generate(material.monthlyPurchaseWeights!.length, (i) {
      return FlSpot(i.toDouble(), material.monthlyPurchaseWeights![i]);
    });
  }

  List<FlSpot> _generateSalesSpots(MaterialMetrics material) {
    if (material.monthlySalesWeights == null ||
        material.monthlySalesWeights!.isEmpty) {
      return [];
    }

    return List.generate(material.monthlySalesWeights!.length, (i) {
      return FlSpot(i.toDouble(), material.monthlySalesWeights![i]);
    });
  }

  double _calculateMinProfit(MaterialMetrics material) {
    if (material.monthlyProfits == null || material.monthlyProfits!.isEmpty) {
      return 0;
    }
    final minProfit = material.monthlyProfits!.reduce((a, b) => a < b ? a : b);
    if (minProfit >= 0) return 0;
    return (minProfit / 100).floor() * 100;
  }

  double _calculateMaxProfit(MaterialMetrics material) {
    if (material.monthlyProfits == null || material.monthlyProfits!.isEmpty) {
      return 100;
    }
    final maxProfit = material.monthlyProfits!.reduce((a, b) => a > b ? a : b);
    if (maxProfit <= 0) return 0;
    return (maxProfit / 100).ceil() * 100;
  }

  double _calculateMaxWeight(MaterialMetrics material) {
    final purchaseWeights = material.monthlyPurchaseWeights ?? [];
    final salesWeights = material.monthlySalesWeights ?? [];

    if (purchaseWeights.isEmpty && salesWeights.isEmpty) return 100;

    final maxPurchase = purchaseWeights.isEmpty
        ? 0.0
        : purchaseWeights.reduce((a, b) => a > b ? a : b);
    final maxSales = salesWeights.isEmpty
        ? 0.0
        : salesWeights.reduce((a, b) => a > b ? a : b);
    final maxWeight = maxPurchase > maxSales ? maxPurchase : maxSales;

    if (maxWeight <= 0) return 100;

    // Round up to nearest 20 for cleaner grid lines
    return (maxWeight / 20).ceil() * 20;
  }

  List<BarChartGroupData> _generateProfitBars(MaterialMetrics material) {
    // Use actual monthly data if available, otherwise generate synthetic data
    final monthlyData = material.monthlyProfits ?? List.filled(6, 0.0);

    return List.generate(6, (i) {
      final profit = i < monthlyData.length ? monthlyData[i] : 0.0;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: profit,
            color: profit >= 0 ? AppColors.primaryGreen : Colors.red,
            width: 20,
            borderRadius: profit >= 0
                ? const BorderRadius.vertical(top: Radius.circular(4))
                : const BorderRadius.vertical(bottom: Radius.circular(4)),
          ),
        ],
      );
    });
  }
}
