import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../../data/services/overview_analytics_service.dart';
import '../../../../data/models/overview_data.dart';
import '../../../bloc/material_analytics/material_analytics_bloc.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class OverviewTab extends StatefulWidget {
  final String selectedPeriod;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final Function(int)? onTabSwitch;

  const OverviewTab({
    super.key,
    required this.selectedPeriod,
    this.customStartDate,
    this.customEndDate,
    this.onTabSwitch,
  });

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final OverviewAnalyticsService _analyticsService =
      getIt<OverviewAnalyticsService>();

  OverviewData? _overviewData;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'Last 30 Days';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadOverviewData();
  }

  @override
  void didUpdateWidget(OverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPeriod != widget.selectedPeriod ||
        oldWidget.customStartDate != widget.customStartDate ||
        oldWidget.customEndDate != widget.customEndDate) {
      _loadOverviewData();
    }
  }

  Future<void> _loadOverviewData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Step 1: Try to load from cache first for instant display
    try {
      final cachedData = await _analyticsService.getCachedOverviewData(
        user.id,
      );
      if (cachedData != null && mounted) {
        setState(() {
          _overviewData = cachedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('?? Cache load failed: $e');
    }

    // Step 2: Fetch fresh data in background
    setState(() {
      _errorMessage = null;
      // Only show loading if no cache data
      if (_overviewData == null) {
        _isLoading = true;
      } else {
        _isRefreshing = true; // Show subtle refresh indicator
      }
    });

    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      // Use custom dates if set, otherwise calculate from filter
      if (_customStartDate != null && _customEndDate != null) {
        startDate = _customStartDate!;
        endDate = _customEndDate!;
      } else if (_selectedFilter == 'Last 30 Days') {
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 30));
      } else if (_selectedFilter == 'This Month') {
        startDate = DateTime(now.year, now.month, 1);
      } else if (_selectedFilter == 'Last Month') {
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = lastMonth;
        endDate = DateTime(
          now.year,
          now.month,
          1,
        ).subtract(const Duration(days: 1));
      } else if (_selectedFilter == 'Last 3 Months') {
        startDate = DateTime(now.year, now.month - 3, now.day);
      } else if (_selectedFilter == 'Last 6 Months') {
        startDate = DateTime(now.year, now.month - 6, now.day);
      } else if (_selectedFilter == 'Last 12 Months') {
        startDate = DateTime(now.year - 1, now.month, now.day);
      } else if (widget.selectedPeriod == 'Custom' &&
          widget.customStartDate != null &&
          widget.customEndDate != null) {
        startDate = widget.customStartDate!;
        endDate = widget.customEndDate!;
      } else if (widget.selectedPeriod == 'Today') {
        startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        endDate = now;
      } else if (widget.selectedPeriod == 'Yesterday') {
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          0,
          0,
          0,
        );
        endDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );
      } else if (widget.selectedPeriod == 'Week') {
        int currentWeekday = now.weekday;
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: currentWeekday - 1));
      } else if (widget.selectedPeriod == 'Last Week') {
        int currentWeekday = now.weekday;
        final daysToLastSunday = currentWeekday == 7 ? 7 : currentWeekday;
        final lastSunday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysToLastSunday));
        final lastMonday = lastSunday.subtract(const Duration(days: 6));
        startDate = DateTime(
          lastMonday.year,
          lastMonday.month,
          lastMonday.day,
          0,
          0,
          0,
        );
        endDate = DateTime(
          lastSunday.year,
          lastSunday.month,
          lastSunday.day,
          23,
          59,
          59,
        );
      } else if (widget.selectedPeriod == 'Month') {
        startDate = DateTime(now.year, now.month, 1);
      } else if (widget.selectedPeriod == 'Last Month') {
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
      } else if (widget.selectedPeriod == 'Year') {
        startDate = DateTime(now.year, 1, 1);
      } else if (widget.selectedPeriod == 'Last Year') {
        startDate = DateTime(now.year - 1, 1, 1);
        endDate = DateTime(now.year - 1, 12, 31, 23, 59, 59);
      } else {
        startDate = DateTime(now.year, 1, 1);
      }

      final data = await _analyticsService.getOverviewData(
        startDate: startDate,
        endDate: endDate,
        includePeriodComparison: true,
      );

      if (mounted) {
        setState(() {
          _overviewData = data;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load overview data: $e';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  String _getPeriodMessage() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    // Use custom dates if set, otherwise calculate from filter
    if (_customStartDate != null && _customEndDate != null) {
      startDate = _customStartDate!;
      endDate = _customEndDate!;
    } else if (_selectedFilter == 'Last 30 Days') {
      startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 30));
    } else if (_selectedFilter == 'This Month') {
      startDate = DateTime(now.year, now.month, 1);
    } else if (_selectedFilter == 'Last Month') {
      startDate = DateTime(now.year, now.month - 1, 1);
      endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
    } else if (_selectedFilter == 'Last 3 Months') {
      startDate = DateTime(now.year, now.month - 3, now.day);
    } else if (_selectedFilter == 'Last 6 Months') {
      startDate = DateTime(now.year, now.month - 6, now.day);
    } else if (_selectedFilter == 'Last 12 Months') {
      startDate = DateTime(now.year - 1, now.month, now.day);
    } else if (_selectedFilter == 'Today') {
      startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedFilter == 'Yesterday') {
      final yesterday = now.subtract(const Duration(days: 1));
      startDate = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        0,
        0,
        0,
      );
      endDate = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        23,
        59,
        59,
      );
    } else if (_selectedFilter == 'Week') {
      int currentWeekday = now.weekday;
      startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: currentWeekday - 1));
    } else if (_selectedFilter == 'Last Week') {
      int currentWeekday = now.weekday;
      final daysToLastSunday = currentWeekday == 7 ? 7 : currentWeekday;
      final lastSunday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysToLastSunday));
      final lastMonday = lastSunday.subtract(const Duration(days: 6));
      startDate = DateTime(
        lastMonday.year,
        lastMonday.month,
        lastMonday.day,
        0,
        0,
        0,
      );
      endDate = DateTime(
        lastSunday.year,
        lastSunday.month,
        lastSunday.day,
        23,
        59,
        59,
      );
    } else {
      startDate = DateTime(now.year, 1, 1);
    }

    return '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';
  }

  Widget _buildPeriodIndicator() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics Overview',
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _showDateFilterMenu,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FluentIcons.calendar_ltr_24_regular,
                        size: 12,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _getPeriodMessage(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        FluentIcons.chevron_down_24_regular,
                        size: 14,
                        color: AppColors.primaryGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isRefreshing)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            ),
          )
        else
          GestureDetector(
            onTap: _loadOverviewData,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                FluentIcons.arrow_clockwise_24_regular,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FluentIcons.error_circle_24_regular,
                  size: 40,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load data',
                style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadOverviewData,
                icon: const Icon(
                  FluentIcons.arrow_clockwise_24_regular,
                  size: 18,
                ),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_overviewData == null) {
      return const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _loadOverviewData,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildPeriodIndicator(),
          const SizedBox(height: 20),
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildProfitTrendsChart(),
          const SizedBox(height: 16),
          _buildTopPerformers(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _overviewData!.summaryTotals;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildSummaryCard(
          label: 'Purchases',
          value: '₱${NumberFormat('#,##0.00').format(summary.totalPurchases)}',
          subLabel: '${summary.purchaseCount} transactions',
          icon: FluentIcons.cart_24_regular,
          color: AppColors.primaryGreen,
          comparison: _overviewData!.purchaseComparison,
        ),
        _buildSummaryCard(
          label: 'Sales',
          value: '₱${NumberFormat('#,##0.00').format(summary.totalSales)}',
          subLabel: '${summary.salesCount} transactions',
          icon: FluentIcons.receipt_24_regular,
          color: AppColors.primaryGreen,
          comparison: _overviewData!.salesComparison,
        ),
        _buildSummaryCard(
          label: 'Net Profit',
          value: '₱${NumberFormat('#,##0.00').format(summary.netProfit)}',
          subLabel: '${summary.profitMargin.toStringAsFixed(1)}% margin',
          icon: FluentIcons.arrow_up_24_regular,
          color: AppColors.primaryGreen,
          comparison: _overviewData!.profitComparison,
        ),
        _buildSummaryCard(
          label: 'Inventory',
          value: '₱${NumberFormat('#,##0.00').format(summary.totalInventory)}',
          subLabel: 'current stock value',
          icon: FluentIcons.box_24_regular,
          color: AppColors.primaryGreen,
          comparison: _overviewData!.inventoryComparison,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required String subLabel,
    required IconData icon,
    required Color color,
    PeriodComparison? comparison,
  }) {
    final isPositive = comparison?.isIncrease ?? true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (comparison != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? FluentIcons.arrow_up_24_regular
                            : FluentIcons.arrow_down_24_regular,
                        size: 10,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        comparison.label,
                        style: AppTextStyles.caption.copyWith(
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subLabel,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProfitTrendsChart() {
    final hasData =
        _overviewData!.purchasesTrend.isNotEmpty ||
        _overviewData!.salesTrend.isNotEmpty ||
        _overviewData!.profitTrend.isNotEmpty;

    // Calculate which indices should show dots (same as date labels)
    bool shouldShowDot(int index, int totalPoints) {
      if (totalPoints <= 6) return true;
      final showEvery = (totalPoints / 6).ceil();
      return index == 0 || index == totalPoints - 1 || index % showEvery == 0;
    }

    const purchaseColor = AppColors.primaryGreen;
    const salesColor = Color(0xFF3B82F6);
    const profitColor = Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Trends',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Purchases, sales & profit over time',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Legend row
          Row(
            children: [
              _buildLegendItem('Purchases', purchaseColor),
              const SizedBox(width: 16),
              _buildLegendItem('Sales', salesColor),
              const SizedBox(width: 16),
              _buildLegendItem('Profit', profitColor),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: hasData
                ? LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: null,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[100]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 ||
                                  index >=
                                      _overviewData!.purchasesTrend.length) {
                                return const SizedBox.shrink();
                              }

                              final totalPoints =
                                  _overviewData!.purchasesTrend.length;
                              final showEvery = totalPoints <= 6
                                  ? 1
                                  : (totalPoints / 6).ceil();

                              if (index == 0 ||
                                  index == totalPoints - 1 ||
                                  index % showEvery == 0) {
                                final label =
                                    _overviewData!.purchasesTrend[index].label;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    label,
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) {
                                return Text(
                                  '?0',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              }
                              if (value >= 1000000) {
                                return Text(
                                  '₱${(value / 1000000).toStringAsFixed(1)}M',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              } else if (value >= 1000) {
                                return Text(
                                  '₱${(value / 1000).toStringAsFixed(1)}k',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              } else {
                                return Text(
                                  '₱${value.toStringAsFixed(0)}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        if (_overviewData!.purchasesTrend.isNotEmpty)
                          LineChartBarData(
                            spots: _overviewData!.purchasesTrend
                                .asMap()
                                .entries
                                .map(
                                  (e) =>
                                      FlSpot(e.key.toDouble(), e.value.value),
                                )
                                .toList(),
                            isCurved: true,
                            color: purchaseColor,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              checkToShowDot: (spot, barData) {
                                final index = spot.x.toInt();
                                return shouldShowDot(
                                  index,
                                  _overviewData!.purchasesTrend.length,
                                );
                              },
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 3.5,
                                  color: purchaseColor,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  purchaseColor.withValues(alpha: 0.15),
                                  purchaseColor.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                            preventCurveOverShooting: true,
                          ),
                        if (_overviewData!.salesTrend.isNotEmpty)
                          LineChartBarData(
                            spots: _overviewData!.salesTrend
                                .asMap()
                                .entries
                                .map(
                                  (e) =>
                                      FlSpot(e.key.toDouble(), e.value.value),
                                )
                                .toList(),
                            isCurved: true,
                            color: salesColor,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              checkToShowDot: (spot, barData) {
                                final index = spot.x.toInt();
                                return shouldShowDot(
                                  index,
                                  _overviewData!.salesTrend.length,
                                );
                              },
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 3.5,
                                  color: salesColor,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  salesColor.withValues(alpha: 0.15),
                                  salesColor.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                            preventCurveOverShooting: true,
                          ),
                        if (_overviewData!.profitTrend.isNotEmpty)
                          LineChartBarData(
                            spots: _overviewData!.profitTrend
                                .asMap()
                                .entries
                                .map(
                                  (e) =>
                                      FlSpot(e.key.toDouble(), e.value.value),
                                )
                                .toList(),
                            isCurved: true,
                            color: profitColor,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              checkToShowDot: (spot, barData) {
                                final index = spot.x.toInt();
                                return shouldShowDot(
                                  index,
                                  _overviewData!.profitTrend.length,
                                );
                              },
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 3.5,
                                  color: profitColor,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  profitColor.withValues(alpha: 0.15),
                                  profitColor.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                            preventCurveOverShooting: true,
                          ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Colors.white,
                          tooltipRoundedRadius: 10,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          tooltipBorder: BorderSide(
                            color: Colors.grey.shade200,
                          ),
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItems: (touchedSpots) {
                            if (touchedSpots.isEmpty) return [];
                            final index = touchedSpots.first.x.toInt();
                            String date = '';
                            if (index >= 0 &&
                                index < _overviewData!.purchasesTrend.length) {
                              date = _overviewData!.purchasesTrend[index].label;
                            }

                            return touchedSpots.asMap().entries.map((entry) {
                              final spot = entry.value;
                              final Color spotColor;
                              final String spotLabel;
                              if (spot.barIndex == 0) {
                                spotColor = purchaseColor;
                                spotLabel = 'Buy';
                              } else if (spot.barIndex == 1) {
                                spotColor = salesColor;
                                spotLabel = 'Sell';
                              } else {
                                spotColor = profitColor;
                                spotLabel = 'Profit';
                              }

                              final text = entry.key == 0
                                  ? '$date\n$spotLabel: ₱${NumberFormat('#,##0.00').format(spot.y)}'
                                  : '$spotLabel: ₱${NumberFormat('#,##0.00').format(spot.y)}';

                              return LineTooltipItem(
                                text,
                                AppTextStyles.caption.copyWith(
                                  color: spotColor,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            FluentIcons.data_bar_vertical_24_regular,
                            size: 32,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No trend data for this period',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTopPerformers() {
    final hasTopMaterials = _overviewData!.topMaterials.isNotEmpty;
    final hasTopCustomers = _overviewData!.topCustomers.isNotEmpty;
    final hasTopBuyers = _overviewData!.topBuyers.isNotEmpty;

    if (!hasTopMaterials && !hasTopCustomers && !hasTopBuyers) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                FluentIcons.trophy_24_regular,
                size: 28,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No performer data yet',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Performers',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (hasTopMaterials) ...[
            const SizedBox(height: 16),
            _buildPerformerSectionHeader(
              'Materials by Profit',
              FluentIcons.box_24_regular,
              AppColors.primaryGreen,
            ),
            const SizedBox(height: 8),
            ..._overviewData!.topMaterials
                .take(4)
                .toList()
                .asMap()
                .entries
                .map(
                  (entry) => _buildPerformerCard(
                    name: entry.value.name,
                    value:
                        '₱${NumberFormat('#,##0.00').format(entry.value.value)}',
                    subtitle:
                        '${entry.value.secondaryValue.toStringAsFixed(1)}% margin',
                    color: AppColors.primaryGreen,
                    rank: entry.key + 1,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/junkshop/analytics/material-detail',
                        arguments: {
                          'bloc': context.read<MaterialAnalyticsBloc>(),
                          'materialName': entry.value.name,
                        },
                      );
                    },
                  ),
                ),
          ],
          if (hasTopCustomers) ...[
            const SizedBox(height: 16),
            _buildPerformerSectionHeader(
              'Top Suppliers',
              FluentIcons.people_24_regular,
              AppColors.primaryGreen,
            ),
            const SizedBox(height: 8),
            ..._overviewData!.topCustomers
                .take(4)
                .toList()
                .asMap()
                .entries
                .map(
                  (entry) => _buildPerformerCard(
                    name: entry.value.name,
                    value:
                        '₱${NumberFormat('#,##0.00').format(entry.value.value)}',
                    subtitle: '${entry.value.secondaryValue.toInt()} purchases',
                    color: AppColors.primaryGreen,
                    rank: entry.key + 1,
                    onTap: () => widget.onTabSwitch?.call(2),
                  ),
                ),
          ],
          if (hasTopBuyers) ...[
            const SizedBox(height: 16),
            _buildPerformerSectionHeader(
              'Top Buyers',
              FluentIcons.building_shop_24_regular,
              AppColors.primaryGreen,
            ),
            const SizedBox(height: 8),
            ..._overviewData!.topBuyers
                .take(4)
                .toList()
                .asMap()
                .entries
                .map(
                  (entry) => _buildPerformerCard(
                    name: entry.value.name,
                    value:
                        '₱${NumberFormat('#,##0.00').format(entry.value.value)}',
                    subtitle: '${entry.value.secondaryValue.toInt()} sales',
                    color: AppColors.primaryGreen,
                    rank: entry.key + 1,
                    onTap: () => widget.onTabSwitch?.call(2),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformerSectionHeader(
    String label,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformerCard({
    required String name,
    required String value,
    required String subtitle,
    required Color color,
    required int rank,
    VoidCallback? onTap,
  }) {
    final rankColors = [
      const Color(0xFFFFB800), // gold
      Colors.grey.shade400, // silver
      const Color(0xFFCD7F32), // bronze
    ];
    final rankColor = rank <= 3
        ? rankColors[rank - 1]
        : color.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                FluentIcons.chevron_right_24_regular,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showDateFilterMenu() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        FluentIcons.calendar_ltr_24_regular,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Date Range',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing12,
                  vertical: AppDimensions.spacing8,
                ),
                child: Text(
                  'QUICK FILTERS',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _buildFilterMenuItem(
                'Last 30 Days',
                FluentIcons.clock_24_regular,
              ),
              _buildFilterMenuItem(
                'This Month',
                FluentIcons.calendar_ltr_24_regular,
              ),
              _buildFilterMenuItem(
                'Last Month',
                FluentIcons.calendar_ltr_24_regular,
              ),
              _buildFilterMenuItem(
                'Last 3 Months',
                FluentIcons.calendar_ltr_24_regular,
              ),
              _buildFilterMenuItem(
                'Last 6 Months',
                FluentIcons.calendar_ltr_24_regular,
              ),
              _buildFilterMenuItem(
                'Last 12 Months',
                FluentIcons.calendar_ltr_24_regular,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing16,
                ),
                child: Divider(height: 24),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing12,
                  vertical: AppDimensions.spacing8,
                ),
                child: Text(
                  'CUSTOM',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _buildCustomFilterItem(
                'Select Month',
                FluentIcons.calendar_ltr_24_regular,
                _showMonthPicker,
              ),
              _buildCustomFilterItem(
                'Select Year',
                FluentIcons.note_24_regular,
                _showYearPicker,
              ),
              _buildCustomFilterItem(
                'Custom Range',
                FluentIcons.calendar_ltr_24_regular,
                _showDateRangePicker,
              ),
              const SizedBox(height: AppDimensions.spacing8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterMenuItem(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _customStartDate = null;
          _customEndDate = null;
        });
        Navigator.pop(context);
        _loadOverviewData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : Colors.transparent,
          border: isSelected
              ? Border(
                  left: BorderSide(color: AppColors.primaryGreen, width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                FluentIcons.checkmark_circle_24_filled,
                color: AppColors.primaryGreen,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFilterItem(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Future.delayed(const Duration(milliseconds: 100), onTap);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            Icon(
              FluentIcons.chevron_right_24_regular,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMonthPicker() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.day,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _selectedFilter = DateFormat('MMMM yyyy').format(selectedDate);
        _customStartDate = DateTime(selectedDate.year, selectedDate.month, 1);
        _customEndDate = DateTime(selectedDate.year, selectedDate.month + 1, 0);
      });
      _loadOverviewData();
    }
  }

  Future<void> _showYearPicker() async {
    final now = DateTime.now();
    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Year'),
        content: SizedBox(
          height: 300,
          width: 300,
          child: YearPicker(
            firstDate: DateTime(2020),
            lastDate: now,
            selectedDate: now,
            onChanged: (date) => Navigator.pop(context, date),
          ),
        ),
      ),
    );

    if (selectedDate != null) {
      setState(() {
        _selectedFilter = selectedDate.year.toString();
        _customStartDate = DateTime(selectedDate.year, 1, 1);
        _customEndDate = DateTime(selectedDate.year, 12, 31);
      });
      _loadOverviewData();
    }
  }

  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (dateRange != null) {
      final startStr = DateFormat('MMM d').format(dateRange.start);
      final endStr = DateFormat('MMM d, yyyy').format(dateRange.end);
      setState(() {
        _selectedFilter = '$startStr - $endStr';
        _customStartDate = dateRange.start;
        _customEndDate = dateRange.end;
      });
      _loadOverviewData();
    }
  }
}
