import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../data/services/junkshop_query.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class CustomersTab extends StatefulWidget {
  final String selectedPeriod;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const CustomersTab({
    super.key,
    required this.selectedPeriod,
    this.customStartDate,
    this.customEndDate,
  });

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;


  List<Map<String, dynamic>> _topSellers = [];
  List<Map<String, dynamic>> _topBuyers = [];
  bool _isLoadingSellers = true;
  bool _isLoadingBuyers = true;

  String _selectedFilter = 'Last 30 Days';
  DateTime? _localCustomStartDate;
  DateTime? _localCustomEndDate;

  String _getPeriodMessage() {
    if (_selectedFilter == 'Custom' &&
        _localCustomStartDate != null &&
        _localCustomEndDate != null) {
      final s = DateFormat('MMM d, y').format(_localCustomStartDate!);
      final e = DateFormat('MMM d, y').format(_localCustomEndDate!);
      return '$s – $e';
    }
    const labels = {
      'Today': 'Today',
      'Yesterday': 'Yesterday',
      'Week': 'This Week',
      'Last Week': 'Last Week',
      'This Month': 'This Month',
      'Month': 'This Month',
      'Last Month': 'Last Month',
      'Last 3 Months': 'Last 3 Months',
      'Last 6 Months': 'Last 6 Months',
      'Last 12 Months': 'Last 12 Months',
      'Year': 'This Year',
      'Last Year': 'Last Year',
    };
    return labels[_selectedFilter] ?? 'Last 30 Days';
  }

  @override
  void initState() {
    super.initState();
    _loadTopSellers();
    _loadTopBuyers();
  }

  @override
  void didUpdateWidget(CustomersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Internal filter drives data loading; parent period changes are ignored.
  }

  Future<void> _showDateFilterMenu() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: AppColors.primaryGreen,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Period',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final label in [
                'Last 30 Days',
                'This Month',
                'Last Month',
                'Last 3 Months',
                'Last 6 Months',
                'Last 12 Months',
                'Last Year',
              ])
                _buildFilterOption(ctx, label),
              const Divider(height: 1),
              _buildCustomRangeOption(ctx),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(BuildContext dialogCtx, String label) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _localCustomStartDate = null;
          _localCustomEndDate = null;
          _isLoadingSellers = true;
          _isLoadingBuyers = true;
        });
        Navigator.pop(dialogCtx);
        _loadTopSellers();
        _loadTopBuyers();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : Colors.transparent,
          border: isSelected
              ? const Border(
                  left: BorderSide(color: AppColors.primaryGreen, width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
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
              const Icon(Icons.check, size: 18, color: AppColors.primaryGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomRangeOption(BuildContext dialogCtx) {
    return InkWell(
      onTap: () async {
        Navigator.pop(dialogCtx);
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange:
              (_localCustomStartDate != null && _localCustomEndDate != null)
              ? DateTimeRange(
                  start: _localCustomStartDate!,
                  end: _localCustomEndDate!,
                )
              : null,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primaryGreen,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() {
            _selectedFilter = 'Custom';
            _localCustomStartDate = picked.start;
            _localCustomEndDate = picked.end;
            _isLoadingSellers = true;
            _isLoadingBuyers = true;
          });
          _loadTopSellers();
          _loadTopBuyers();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            const Icon(
              Icons.date_range,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Custom Range',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Converts the internal [_selectedFilter] to a [start, end] date range.
  ({DateTime start, DateTime? end}) _resolveDateRange() {
    final now = DateTime.now();
    final period = _selectedFilter;

    if (period == 'Custom' &&
        _localCustomStartDate != null &&
        _localCustomEndDate != null) {
      return (start: _localCustomStartDate!, end: _localCustomEndDate);
    } else if (period == 'Today') {
      return (start: DateTime(now.year, now.month, now.day), end: now);
    } else if (period == 'Yesterday') {
      final y = now.subtract(const Duration(days: 1));
      return (
        start: DateTime(y.year, y.month, y.day, 0, 0, 0),
        end: DateTime(y.year, y.month, y.day, 23, 59, 59),
      );
    } else if (period == 'Week') {
      return (
        start: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1)),
        end: null,
      );
    } else if (period == 'Last Week') {
      final daysToLastSunday = now.weekday == 7 ? 7 : now.weekday;
      final lastSunday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysToLastSunday));
      final lastMonday = lastSunday.subtract(const Duration(days: 6));
      return (
        start: DateTime(
          lastMonday.year,
          lastMonday.month,
          lastMonday.day,
          0,
          0,
          0,
        ),
        end: DateTime(
          lastSunday.year,
          lastSunday.month,
          lastSunday.day,
          23,
          59,
          59,
        ),
      );
    } else if (period == 'Month' || period == 'This Month') {
      return (start: DateTime(now.year, now.month, 1), end: null);
    } else if (period == 'Last Month') {
      return (
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 0, 23, 59, 59),
      );
    } else if (period == 'Last 3 Months') {
      return (start: DateTime(now.year, now.month - 3, now.day), end: null);
    } else if (period == 'Last 6 Months') {
      return (start: DateTime(now.year, now.month - 6, now.day), end: null);
    } else if (period == 'Last 12 Months' || period == 'Year') {
      return (start: DateTime(now.year - 1, now.month, now.day), end: null);
    } else if (period == 'Last Year') {
      return (
        start: DateTime(now.year - 1, 1, 1),
        end: DateTime(now.year - 1, 12, 31, 23, 59, 59),
      );
    } else {
      // Default: 'Last 30 Days' and any unrecognised period
      return (
        start: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 30)),
        end: null,
      );
    }
  }

  Future<void> _loadTopSellers() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() => _isLoadingSellers = true);

      final dateRange = _resolveDateRange();
      final startDate = dateRange.start;
      final endDate = dateRange.end;

      // Aggregate by household from multiple sources
      Map<String, Map<String, dynamic>> householdStats = {};

      // 1. Query completed collections from subcollection
      final collectionsSnapshot = await JunkshopQuery.collections(
        user.id,
        from: startDate,
        to: endDate,
      );
      collectionsSnapshot.docs.sort((a, b) {
        final ta = toDateTime(a.data()['reviewedAt']) ?? DateTime(1970);
        final tb = toDateTime(b.data()['reviewedAt']) ?? DateTime(1970);
        return tb.compareTo(ta);
      });

      if (kDebugMode) {
        print('📦 Found ${collectionsSnapshot.docs.length} collections');
      }

      for (var doc in collectionsSnapshot.docs) {
        final data = doc.data();
        final householdId = data['householdId'] as String? ?? '';
        final householdName = data['householdName'] as String? ?? 'Unknown';
        final householdImage = data['householdProfileImage'] as String? ?? '';
        final totalCost =
            (data['totalJunkshopCost'] as num?)?.toDouble() ?? 0.0;

        if (householdId.isEmpty || householdName == 'Unknown') continue;

        if (!householdStats.containsKey(householdId)) {
          householdStats[householdId] = {
            'id': householdId,
            'name': householdName,
            'image': householdImage,
            'totalValue': 0.0,
            'transactions': 0,
          };
        }

        householdStats[householdId]!['totalValue'] =
            (householdStats[householdId]!['totalValue'] as double) + totalCost;
        householdStats[householdId]!['transactions'] =
            (householdStats[householdId]!['transactions'] as int) + 1;
      }

      // 2. Query onsite purchases
      final purchasesSnapshot = await JunkshopQuery.table(
        'purchases',
        user.id,
        from: startDate,
        to: endDate,
        eq: {'status': 'completed'},
        orderBy: 'created_at',
        desc: true,
      );

      if (kDebugMode) {
        print('💰 Found ${purchasesSnapshot.docs.length} onsite purchases');
      }

      for (var doc in purchasesSnapshot.docs) {
        final data = doc.data();

        // Try to get seller name from different possible fields
        String sellerName = '';
        String? sellerId;

        // Check customer_name field first
        if (data['customer_name'] != null &&
            (data['customer_name'] as String).isNotEmpty) {
          sellerName = data['customer_name'] as String;
          sellerId = data['customer_id'] as String? ?? sellerName;
        }
        // Check customerName field
        else if (data['customerName'] != null &&
            (data['customerName'] as String).isNotEmpty) {
          sellerName = data['customerName'] as String;
          sellerId = data['customerId'] as String? ?? sellerName;
        }
        // Check if it's a household sale
        else if (data['household'] is Map) {
          final household = data['household'] as Map<String, dynamic>;
          sellerName =
              household['full_name'] as String? ??
              household['name'] as String? ??
              '';
          sellerId = household['id'] as String?;
        }
        // Check sellerName field
        else if (data['sellerName'] != null &&
            (data['sellerName'] as String).isNotEmpty) {
          sellerName = data['sellerName'] as String;
          sellerId = data['sellerId'] as String? ?? sellerName;
        }

        final totalCost =
            (data['totalCost'] as num?)?.toDouble() ??
            (data['totalAmount'] as num?)?.toDouble() ??
            0.0;

        if (totalCost == 0.0) continue;

        // Create unique key for each seller
        String sellerKey;
        String displayName;

        if (sellerName.isNotEmpty &&
            !sellerName.toLowerCase().contains('unknown')) {
          // Named customer - use ID or name as key
          sellerKey = sellerId ?? sellerName;
          displayName = sellerName;
        } else {
          // Walk-in customer - use doc ID to keep them separate
          sellerKey = 'walkin_seller_${doc.id}';
          displayName = 'Walk-in Customer #${doc.id.substring(0, 6)}';
        }

        if (!householdStats.containsKey(sellerKey)) {
          householdStats[sellerKey] = {
            'id': sellerKey,
            'name': displayName,
            'image': '',
            'totalValue': 0.0,
            'transactions': 0,
          };
        }

        householdStats[sellerKey]!['totalValue'] =
            (householdStats[sellerKey]!['totalValue'] as double) + totalCost;
        householdStats[sellerKey]!['transactions'] =
            (householdStats[sellerKey]!['transactions'] as int) + 1;
      }

      if (kDebugMode) {
        print('👥 Total unique sellers: ${householdStats.length}');
      }

      // Convert to list and sort by total value (highest first)
      final sellers = householdStats.values.toList();
      sellers.sort(
        (a, b) =>
            (b['totalValue'] as double).compareTo(a['totalValue'] as double),
      );

      if (mounted) {
        setState(() {
          _topSellers = sellers.take(5).toList();
          _isLoadingSellers = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading top sellers: $e');
      if (mounted) {
        setState(() => _isLoadingSellers = false);
      }
    }
  }

  Future<void> _loadTopBuyers() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() => _isLoadingBuyers = true);

      final dateRange = _resolveDateRange();
      final startDate = dateRange.start;
      final endDate = dateRange.end;

      // Query sales
      final salesSnapshot = await JunkshopQuery.table(
        'sales',
        user.id,
        from: startDate,
        to: endDate,
        orderBy: 'created_at',
        desc: true,
      );

      if (kDebugMode) print('💰 Found ${salesSnapshot.docs.length} sales');

      // Aggregate by buyer
      Map<String, Map<String, dynamic>> buyerStats = {};

      for (var doc in salesSnapshot.docs) {
        final data = doc.data();

        // Try to get buyer name from different possible fields
        String buyerName =
            data['customerName'] as String? ??
            data['buyerName'] as String? ??
            data['buyer'] as String? ??
            '';

        final buyerContact =
            data['customerContact'] as String? ??
            data['buyerContact'] as String? ??
            data['contact'] as String? ??
            '';

        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

        if (totalAmount == 0.0) continue;

        // Create unique key for each buyer
        String buyerKey;
        String displayName;

        if (buyerName.isNotEmpty &&
            !buyerName.toLowerCase().contains('walk-in')) {
          // Named customer - use name + contact as key
          buyerKey = buyerContact.isNotEmpty
              ? '$buyerName|$buyerContact'
              : buyerName;
          displayName = buyerName;
        } else {
          // Walk-in customer - use doc ID to keep them separate
          buyerKey = 'walkin_${doc.id}';
          displayName = buyerContact.isNotEmpty
              ? 'Walk-in ($buyerContact)'
              : 'Walk-in Customer #${doc.id.substring(0, 6)}';
        }

        if (!buyerStats.containsKey(buyerKey)) {
          buyerStats[buyerKey] = {
            'name': displayName,
            'contact': buyerContact,
            'totalValue': 0.0,
            'purchases': 0,
          };
        }

        buyerStats[buyerKey]!['totalValue'] =
            (buyerStats[buyerKey]!['totalValue'] as double) + totalAmount;
        buyerStats[buyerKey]!['purchases'] =
            (buyerStats[buyerKey]!['purchases'] as int) + 1;
      }

      if (kDebugMode) print('👥 Total unique buyers: ${buyerStats.length}');

      // Convert to list and sort by total value (highest first)
      final buyers = buyerStats.values.toList();
      buyers.sort(
        (a, b) =>
            (b['totalValue'] as double).compareTo(a['totalValue'] as double),
      );

      if (mounted) {
        setState(() {
          _topBuyers = buyers.take(5).toList();
          _isLoadingBuyers = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading top buyers: $e');
      if (mounted) {
        setState(() => _isLoadingBuyers = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadTopSellers(), _loadTopBuyers()]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        children: [
          // Period filter pill
          GestureDetector(
            onTap: _showDateFilterMenu,
            child: Container(
              margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 13,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getPeriodMessage(),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                ],
              ),
            ),
          ),

          // Top Sellers Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Sellers',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getPeriodMessage(),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/junkshop/analytics/all-sellers',
                    arguments: {'period': widget.selectedPeriod},
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: AppColors.primaryGreen,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          if (_isLoadingSellers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacing32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_topSellers.isEmpty)
            _buildEmptyState('No sellers data available')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: _topSellers.length,
              itemBuilder: (context, index) {
                final seller = _topSellers[index];
                return _buildSellerCard(seller, index + 1);
              },
            ),

          const SizedBox(height: AppDimensions.spacing32),

          // Top Buyers Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Buyers',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customers purchasing the most materials',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/junkshop/analytics/all-buyers',
                    arguments: {'period': widget.selectedPeriod},
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: AppColors.primaryGreen,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          if (_isLoadingBuyers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacing32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_topBuyers.isEmpty)
            _buildEmptyState('No buyers data available')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: _topBuyers.length,
              itemBuilder: (context, index) {
                final buyer = _topBuyers[index];
                return _buildBuyerCard(buyer, index + 1);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSellerCard(Map<String, dynamic> seller, int rank) {
    final name = seller['name'] as String;
    final totalValue = seller['totalValue'] as double;
    final transactions = seller['transactions'] as int;
    final avgValue = transactions > 0 ? totalValue / transactions : 0.0;

    return InkWell(
      onTap: () => _showTransactionHistory(name, 'seller'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                _formatCurrency(totalValue),
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Total Revenue',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 12,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$transactions • Avg ${_formatCurrency(avgValue)}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuyerCard(Map<String, dynamic> buyer, int rank) {
    final name = buyer['name'] as String;
    final totalValue = buyer['totalValue'] as double;
    final purchases = buyer['purchases'] as int;
    final avgValue = purchases > 0 ? totalValue / purchases : 0.0;

    return InkWell(
      onTap: () => _showTransactionHistory(name, 'buyer'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                _formatCurrency(totalValue),
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Total Spent',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 12,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$purchases • Avg ${_formatCurrency(avgValue)}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '₱${formatter.format(value)}';
  }

  Map<String, dynamic> _getDateRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (widget.selectedPeriod == 'Custom' &&
        widget.customStartDate != null &&
        widget.customEndDate != null) {
      start = widget.customStartDate!;
      end = DateTime(
        widget.customEndDate!.year,
        widget.customEndDate!.month,
        widget.customEndDate!.day,
        23,
        59,
        59,
      );
    } else {
      switch (widget.selectedPeriod) {
        case 'Today':
          start = DateTime(now.year, now.month, now.day);
          break;
        case 'Week':
          start = now.subtract(const Duration(days: 7));
          break;
        case 'Last 30 Days':
          start = now.subtract(const Duration(days: 30));
          break;
        case 'Month':
          start = DateTime(now.year, now.month, 1);
          break;
        case 'Year':
          start = DateTime(now.year, 1, 1);
          break;
        default:
          start = now.subtract(const Duration(days: 30));
      }
    }

    return {'start': Timestamp.fromDate(start), 'end': Timestamp.fromDate(end)};
  }

  Future<void> _showTransactionHistory(String customerName, String type) async {
    try {
      final junkshopId = currentUid;
      if (junkshopId == null) return;

      final dateRange = _getDateRange();
      List<Map<String, dynamic>> transactions = [];

      if (type == 'seller') {
        final purchasesQuery = await JunkshopQuery.table(
          'purchases',
          junkshopId,
        );

        for (var doc in purchasesQuery.docs) {
          final data = doc.data();
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt == null) continue;

          final date = createdAt.toDate();
          final startDate = (dateRange['start'] as Timestamp).toDate();
          final endDate = (dateRange['end'] as Timestamp).toDate();

          if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

          // Try multiple fields to get seller name (matching _loadTopSellers logic)
          String sellerName = '';

          if (data['customer_name'] != null &&
              (data['customer_name'] as String).isNotEmpty) {
            sellerName = data['customer_name'] as String;
          } else if (data['customerName'] != null &&
              (data['customerName'] as String).isNotEmpty) {
            sellerName = data['customerName'] as String;
          } else if (data['seller_name'] != null &&
              (data['seller_name'] as String).isNotEmpty) {
            sellerName = data['seller_name'] as String;
          } else if (data['name'] != null &&
              (data['name'] as String).isNotEmpty) {
            sellerName = data['name'] as String;
          } else {
            final sellerData = data['seller'];
            sellerName = sellerData is Map<String, dynamic>
                ? sellerData['name'] ?? 'Unknown Seller'
                : sellerData?.toString() ?? 'Unknown Seller';
          }

          if (sellerName == customerName) {
            final items = data['items'];
            final itemsList = items is List ? items : [];

            // Debug logging
            if (kDebugMode) print('📦 Purchase data for $customerName:');
            if (kDebugMode) print('  - Total fields: ${data.keys.toList()}');
            if (kDebugMode) print('  - Items type: ${items.runtimeType}');
            if (itemsList.isNotEmpty && itemsList.first is Map) {
              if (kDebugMode) {
                print(
                  '  - First item fields: ${(itemsList.first as Map).keys.toList()}',
                );
              }
            }

            transactions.add({
              'date': date,
              'type': 'Purchase',
              'amount': _calculatePurchaseTotal(data),
              'items': itemsList,
            });
          }
        }

        final collectionsQuery = await JunkshopQuery.collections(junkshopId);

        for (var doc in collectionsQuery.docs) {
          final data = doc.data();
          final completedAt = data['completedAt'] as Timestamp?;
          if (completedAt == null) continue;

          final date = completedAt.toDate();
          final startDate = (dateRange['start'] as Timestamp).toDate();
          final endDate = (dateRange['end'] as Timestamp).toDate();

          if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

          final householdName = data['householdName'] ?? 'Unknown Seller';

          if (householdName == customerName) {
            // Use purchasedItems which has junkshop prices, fallback to items
            final itemsData = data['purchasedItems'] ?? data['items'];
            List<dynamic> itemsList = [];

            // Extract actual items list from nested structure
            if (itemsData is Map) {
              // Items are nested in 'list' key
              final nestedList = itemsData['list'];
              if (nestedList is List) {
                itemsList = nestedList;
              }
            } else if (itemsData is List) {
              itemsList = itemsData;
            }

            transactions.add({
              'date': date,
              'type': 'Collection',
              'amount': _calculateCollectionTotal(data),
              'items': itemsList,
            });
          }
        }
      } else {
        final salesQuery = await JunkshopQuery.table('sales', junkshopId);

        for (var doc in salesQuery.docs) {
          final data = doc.data();
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt == null) continue;

          final date = createdAt.toDate();
          final startDate = (dateRange['start'] as Timestamp).toDate();
          final endDate = (dateRange['end'] as Timestamp).toDate();

          if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

          final buyerData = data['buyer'];
          String buyerName = 'Unknown Buyer';

          if (buyerData is Map<String, dynamic>) {
            buyerName =
                buyerData['name'] ??
                buyerData['buyerName'] ??
                buyerData['customerName'] ??
                'Unknown Buyer';
          } else if (buyerData is String) {
            buyerName = buyerData;
          }

          if (buyerName == customerName) {
            final items = data['items'];
            final itemsList = items is List ? items : [];

            transactions.add({
              'date': date,
              'type': 'Sale',
              'amount': data['totalAmount'] ?? 0.0,
              'items': itemsList,
            });
          }
        }
      }

      transactions.sort((a, b) => b['date'].compareTo(a['date']));

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${transactions.length} transaction${transactions.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '✕',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 4),
                if (transactions.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No transactions found',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        final date = transaction['date'] as DateTime;
                        final type = transaction['type'] as String;
                        final amount = transaction['amount'] as double;
                        final items = transaction['items'] as List? ?? [];

                        final isSale = type == 'Sale';
                        final accentColor = isSale
                            ? const Color(0xFF3B82F6)
                            : AppColors.primaryGreen;
                        final badgeBg = isSale
                            ? const Color(0xFFEFF6FF)
                            : AppColors.primaryGreen.withValues(alpha: 0.1);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: type badge + date + amount
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: accentColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('MMM d, yyyy').format(date),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatCurrency(amount),
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (items.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Divider(
                                    height: 1,
                                    color: Colors.grey.shade100,
                                  ),
                                  const SizedBox(height: 12),
                                  ...items.asMap().entries.map((entry) {
                                    final itemIndex = entry.key;
                                    final item = entry.value;

                                    if (item is! Map) {
                                      return const SizedBox.shrink();
                                    }
                                    final itemMap = item;

                                    final materialName =
                                        itemMap['name'] ??
                                        itemMap['material'] ??
                                        itemMap['materialName'] ??
                                        itemMap['type'] ??
                                        itemMap['materialType'] ??
                                        'Unknown Material';
                                    final quantity =
                                        double.tryParse(
                                          itemMap['quantity']?.toString() ??
                                              '0',
                                        ) ??
                                        0.0;

                                    final double subtotal;
                                    final double price;

                                    if (type == 'Purchase') {
                                      final subtotalValue = double.tryParse(
                                        itemMap['subtotal']?.toString() ?? '0',
                                      );
                                      if (subtotalValue != null &&
                                          subtotalValue > 0) {
                                        subtotal = subtotalValue;
                                        price = quantity > 0
                                            ? subtotal / quantity
                                            : 0.0;
                                      } else {
                                        price =
                                            double.tryParse(
                                              itemMap['price']?.toString() ??
                                                  '0',
                                            ) ??
                                            double.tryParse(
                                              itemMap['pricePerUnit']
                                                      ?.toString() ??
                                                  '0',
                                            ) ??
                                            0.0;
                                        subtotal = quantity * price;
                                      }
                                    } else if (type == 'Collection') {
                                      price =
                                          double.tryParse(
                                            itemMap['junkshopPricePerUnit']
                                                    ?.toString() ??
                                                '0',
                                          ) ??
                                          double.tryParse(
                                            itemMap['pricePerUnit']
                                                    ?.toString() ??
                                                '0',
                                          ) ??
                                          double.tryParse(
                                            itemMap['price']?.toString() ?? '0',
                                          ) ??
                                          0.0;
                                      subtotal = quantity * price;
                                    } else {
                                      final subtotalValue = double.tryParse(
                                        itemMap['subtotal']?.toString() ?? '0',
                                      );
                                      if (subtotalValue != null &&
                                          subtotalValue > 0) {
                                        subtotal = subtotalValue;
                                        price = quantity > 0
                                            ? subtotal / quantity
                                            : 0.0;
                                      } else {
                                        price =
                                            double.tryParse(
                                              itemMap['pricePerUnit']
                                                      ?.toString() ??
                                                  '0',
                                            ) ??
                                            double.tryParse(
                                              itemMap['price']?.toString() ??
                                                  '0',
                                            ) ??
                                            double.tryParse(
                                              itemMap['unitPrice']
                                                      ?.toString() ??
                                                  '0',
                                            ) ??
                                            0.0;
                                        subtotal = quantity * price;
                                      }
                                    }

                                    return Padding(
                                      padding: EdgeInsets.only(
                                        bottom: itemIndex < items.length - 1
                                            ? 10
                                            : 0,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  materialName.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF111827),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${quantity.toStringAsFixed(1)} kg  ×  ${_formatCurrency(price)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF9CA3AF),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _formatCurrency(subtotal),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF374151),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading transactions: $e')));
    }
  }

  double _calculatePurchaseTotal(Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      return double.tryParse(data['totalAmount']?.toString() ?? '0') ??
          double.tryParse(data['total']?.toString() ?? '0') ??
          double.tryParse(data['totalCost']?.toString() ?? '0') ??
          0.0;
    }

    double total = 0.0;
    for (var item in items) {
      if (item is Map<String, dynamic>) {
        // Use subtotal if available (already calculated)
        final subtotal = double.tryParse(item['subtotal']?.toString() ?? '0');
        if (subtotal != null && subtotal > 0) {
          total += subtotal;
        } else {
          // Fallback: calculate from quantity * price
          final quantity =
              double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
          final price =
              double.tryParse(item['price']?.toString() ?? '0') ??
              double.tryParse(item['pricePerUnit']?.toString() ?? '0') ??
              double.tryParse(item['unitPrice']?.toString() ?? '0') ??
              0.0;
          total += quantity * price;
        }
      }
    }
    return total;
  }

  double _calculateCollectionTotal(Map<String, dynamic> data) {
    // Use totalJunkshopCost as primary source (already calculated)
    final totalJunkshopCost = double.tryParse(
      data['totalJunkshopCost']?.toString() ?? '0',
    );
    if (totalJunkshopCost != null && totalJunkshopCost > 0) {
      return totalJunkshopCost;
    }

    // Fallback: calculate from purchasedItems
    final itemsData = data['purchasedItems'] ?? data['items'];
    if (itemsData == null) return 0.0;

    double total = 0.0;

    try {
      List<dynamic> itemsList = [];

      // Extract items list from nested structure
      if (itemsData is Map && itemsData['list'] is List) {
        itemsList = itemsData['list'];
      } else if (itemsData is List) {
        itemsList = itemsData;
      }

      // Calculate total from items
      for (var item in itemsList) {
        if (item is! Map) continue;

        final itemMap = item;
        final quantity =
            double.tryParse(itemMap['quantity']?.toString() ?? '0') ?? 0.0;
        final price =
            double.tryParse(
              itemMap['junkshopPricePerUnit']?.toString() ?? '0',
            ) ??
            double.tryParse(itemMap['pricePerUnit']?.toString() ?? '0') ??
            double.tryParse(itemMap['price']?.toString() ?? '0') ??
            0.0;
        total += quantity * price;
      }
    } catch (e) {
      if (kDebugMode) print('Error calculating collection total: $e');
    }

    return total;
  }
}
