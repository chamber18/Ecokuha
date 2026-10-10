import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../data/services/junkshop_query.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_text_styles.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class AllSellersScreen extends StatefulWidget {
  const AllSellersScreen({super.key});

  @override
  State<AllSellersScreen> createState() => _AllSellersScreenState();
}

class _AllSellersScreenState extends State<AllSellersScreen> {
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _allSellers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String _selectedPeriod = 'Month';
  String _sortBy = 'value'; // 'value' or 'name'
  String _sortDirection = 'desc'; // 'asc' or 'desc'
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Filter state
  String? _filterType; // null = all, 'collector', 'onsite'
  double? _minValue;
  double? _maxValue;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['period'] != null) {
        setState(() {
          _selectedPeriod = args['period'];
        });
      }
      _loadAllSellers();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreSellers();
    }
  }

  Future<void> _loadAllSellers() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() {
        _isLoading = true;
        _allSellers = [];
        _hasMoreData = true;
      });

      await _fetchSellers();
    } catch (e) {
      if (kDebugMode) print('Error loading sellers: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreSellers() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      await _fetchSellers();
    } catch (e) {
      if (kDebugMode) print('Error loading more sellers: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _fetchSellers() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final DateTime startDate;

      if (_selectedPeriod == 'Custom' && _customStartDate != null) {
        startDate = _customStartDate!;
      } else {
        startDate = _selectedPeriod == 'Week'
            ? now.subtract(const Duration(days: 7))
            : _selectedPeriod == 'Month'
            ? now.subtract(const Duration(days: 30))
            : now.subtract(const Duration(days: 365));
      }

      Map<String, Map<String, dynamic>> householdStats = {};

      // 1. Query completed collections from subcollection
      final customEnd = (_selectedPeriod == 'Custom') ? _customEndDate : null;
      final collectionsSnapshot = await JunkshopQuery.collections(
        user.id,
        from: startDate,
        to: customEnd,
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
        final householdName =
            data['householdName'] as String? ??
            data['household']?['full_name'] as String? ??
            data['household']?['name'] as String? ??
            'Unknown';

        if (householdId.isEmpty || householdName == 'Unknown') continue;

        final totalCost =
            (data['totalJunkshopCost'] as num?)?.toDouble() ??
            (data['totalCost'] as num?)?.toDouble() ??
            0.0;

        if (totalCost == 0.0) continue;

        if (!householdStats.containsKey(householdId)) {
          householdStats[householdId] = {
            'id': householdId,
            'name': householdName,
            'image': '',
            'totalValue': 0.0,
            'transactions': 0,
            'source': 'collector', // Mark as collector pickup
          };
        }

        householdStats[householdId]!['totalValue'] =
            (householdStats[householdId]!['totalValue'] as double) + totalCost;
        householdStats[householdId]!['transactions'] =
            (householdStats[householdId]!['transactions'] as int) + 1;
      }

      // 2. Query completed purchases from Purchase collection (onsite)
      final purchasesSnapshot = await JunkshopQuery.table(
        'purchases',
        user.id,
        from: startDate,
        to: customEnd,
        eq: {'status': 'completed'},
        orderBy: 'created_at',
        desc: true,
      );

      if (kDebugMode) {
        print('🏪 Found ${purchasesSnapshot.docs.length} purchases');
      }

      for (var doc in purchasesSnapshot.docs) {
        final data = doc.data();

        String sellerName =
            data['customer_name'] as String? ??
            data['customerName'] as String? ??
            data['household']?['full_name'] as String? ??
            data['household']?['name'] as String? ??
            data['sellerName'] as String? ??
            '';

        String? sellerId =
            data['customerId'] as String? ?? data['householdId'] as String?;

        final totalCost =
            (data['totalCost'] as num?)?.toDouble() ??
            (data['totalAmount'] as num?)?.toDouble() ??
            0.0;

        if (totalCost == 0.0) continue;

        String sellerKey;
        String displayName;

        if (sellerName.isNotEmpty &&
            !sellerName.toLowerCase().contains('unknown')) {
          sellerKey = sellerId ?? sellerName;
          displayName = sellerName;
        } else {
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
            'source': 'onsite', // Mark as onsite purchase
          };
        }

        householdStats[sellerKey]!['totalValue'] =
            (householdStats[sellerKey]!['totalValue'] as double) + totalCost;
        householdStats[sellerKey]!['transactions'] =
            (householdStats[sellerKey]!['transactions'] as int) + 1;
      }

      // All data loaded — no more pages
      _hasMoreData = false;

      final sellers = householdStats.values.toList();
      final filtered = _applyFilters(sellers);
      _sortSellers(filtered);

      if (mounted) {
        setState(() {
          _allSellers = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching sellers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _sortSellers(List<Map<String, dynamic>> sellers) {
    if (_sortBy == 'value') {
      sellers.sort((a, b) {
        final comparison = (b['totalValue'] as double).compareTo(
          a['totalValue'] as double,
        );
        return _sortDirection == 'desc' ? comparison : -comparison;
      });
    } else {
      sellers.sort((a, b) {
        final comparison = (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        );
        return _sortDirection == 'asc' ? comparison : -comparison;
      });
    }
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filterType != null) count++;
    if (_minValue != null) count++;
    if (_maxValue != null) count++;
    return count;
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> sellers) {
    var filtered = sellers;

    // Apply type filter (based on data source)
    if (_filterType != null) {
      filtered = filtered.where((seller) {
        final source = seller['source'] as String?;
        if (_filterType == 'collector') {
          return source == 'collector';
        } else if (_filterType == 'onsite') {
          return source == 'onsite';
        }
        return true;
      }).toList();
    }

    // Apply value range filter
    if (_minValue != null) {
      filtered = filtered.where((seller) {
        final value = seller['totalValue'] as double;
        return value >= _minValue!;
      }).toList();
    }

    if (_maxValue != null) {
      filtered = filtered.where((seller) {
        final value = seller['totalValue'] as double;
        return value <= _maxValue!;
      }).toList();
    }

    return filtered;
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter',
                    style: AppTextStyles.h5.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedPeriod = 'Month';
                        _customStartDate = null;
                        _customEndDate = null;
                        _sortBy = 'value';
                        _sortDirection = 'desc';
                        _filterType = null;
                        _minValue = null;
                        _maxValue = null;
                      });
                      Navigator.pop(context);
                      _loadAllSellers();
                    },
                    child: Text(
                      'Clear All',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Period Selector
              Text(
                'Period',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Week',
                      isSelected: _selectedPeriod == 'Week',
                      onTap: () {
                        setModalState(() => _selectedPeriod = 'Week');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Month',
                      isSelected: _selectedPeriod == 'Month',
                      onTap: () {
                        setModalState(() => _selectedPeriod = 'Month');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Year',
                      isSelected: _selectedPeriod == 'Year',
                      onTap: () {
                        setModalState(() => _selectedPeriod = 'Year');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange:
                        _customStartDate != null && _customEndDate != null
                        ? DateTimeRange(
                            start: _customStartDate!,
                            end: _customEndDate!,
                          )
                        : null,
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedPeriod = 'Custom';
                      _customStartDate = picked.start;
                      _customEndDate = picked.end;
                    });
                    setModalState(() {
                      _selectedPeriod = 'Custom';
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedPeriod == 'Custom'
                        ? AppColors.primaryGreen
                        : Colors.transparent,
                    border: Border.all(
                      color: _selectedPeriod == 'Custom'
                          ? AppColors.primaryGreen
                          : AppColors.borderLight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 18,
                        color: _selectedPeriod == 'Custom'
                            ? AppColors.textWhite
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedPeriod == 'Custom' && _customStartDate != null
                            ? '${_customStartDate!.month}/${_customStartDate!.day}/${_customStartDate!.year} - ${_customEndDate!.month}/${_customEndDate!.day}/${_customEndDate!.year}'
                            : 'Custom Range',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _selectedPeriod == 'Custom'
                              ? AppColors.textWhite
                              : AppColors.textSecondary,
                          fontWeight: _selectedPeriod == 'Custom'
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sort By
              Text(
                'Sort By',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Total Value',
                      isSelected: _sortBy == 'value',
                      onTap: () {
                        setModalState(() => _sortBy = 'value');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Name',
                      isSelected: _sortBy == 'name',
                      onTap: () {
                        setModalState(() => _sortBy = 'name');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Sort Direction',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Descending',
                      isSelected: _sortDirection == 'desc',
                      onTap: () {
                        setModalState(() => _sortDirection = 'desc');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Ascending',
                      isSelected: _sortDirection == 'asc',
                      onTap: () {
                        setModalState(() => _sortDirection = 'asc');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Seller Type Filter
              Text(
                'Seller Type',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      label: 'All',
                      isSelected: _filterType == null,
                      onTap: () {
                        setModalState(() => _filterType = null);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Collector',
                      isSelected: _filterType == 'collector',
                      onTap: () {
                        setModalState(() => _filterType = 'collector');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Onsite',
                      isSelected: _filterType == 'onsite',
                      onTap: () {
                        setModalState(() => _filterType = 'onsite');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadAllSellers();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply Filters',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: AppColors.textWhite,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderLight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? AppColors.textWhite : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '₱${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '₱${value.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Sellers',
          style: AppTextStyles.h4.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.filter_list,
                  color: AppColors.textPrimary,
                ),
                onPressed: _showFilterModal,
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.errorColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        _activeFilterCount.toString(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textWhite,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllSellers,
        child: Column(
          children: [
            // Stats summary
            if (!_isLoading && _allSellers.isNotEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacing16,
                  0,
                  AppDimensions.spacing16,
                  AppDimensions.spacing16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Sellers',
                        _allSellers.length.toString(),
                        Icons.people,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Transactions',
                        _allSellers
                            .fold<int>(
                              0,
                              (acc, s) => acc + (s['transactions'] as int),
                            )
                            .toString(),
                        Icons.receipt_long,
                      ),
                    ),
                  ],
                ),
              ),

            // Sellers list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allSellers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sellers data available',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppDimensions.spacing16),
                      itemCount: _allSellers.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _allSellers.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final seller = _allSellers[index];
                        return _buildSellerCard(seller, index + 1);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.h5.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard(Map<String, dynamic> seller, int rank) {
    final totalValue = seller['totalValue'] as double;
    final transactions = seller['transactions'] as int;
    final avgValue = transactions > 0 ? totalValue / transactions : 0.0;
    final sellerName = seller['name'] as String;

    return InkWell(
      onTap: () => _showTransactionHistory(sellerName, 'seller'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: AppColors.primaryGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Seller info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller['name'] as String,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$transactions transactions • Avg: ${_formatCurrency(avgValue)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Total value
              Text(
                _formatCurrency(totalValue),
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTransactionHistory(String customerName, String type) async {
    try {
      final junkshopId = currentUid;
      if (junkshopId == null) return;

      List<Map<String, dynamic>> transactions = [];

      // Query purchases
      final purchasesQuery = await JunkshopQuery.table(
        'purchases',
        junkshopId,
      );

      for (var doc in purchasesQuery.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) continue;

        final date = createdAt.toDate();

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

          transactions.add({
            'date': date,
            'type': 'Purchase',
            'amount': _calculatePurchaseTotal(data),
            'items': itemsList,
          });
        }
      }

      // Query collections
      final collectionsQuery = await JunkshopQuery.collections(junkshopId);

      for (var doc in collectionsQuery.docs) {
        final data = doc.data();
        final completedAt = data['completedAt'] as Timestamp?;
        if (completedAt == null) continue;

        final date = completedAt.toDate();

        final householdName = data['householdName'] ?? 'Unknown Seller';

        if (householdName == customerName) {
          final itemsData = data['purchasedItems'] ?? data['items'];
          List<dynamic> itemsList = [];

          if (itemsData is Map) {
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

      transactions.sort((a, b) => b['date'].compareTo(a['date']));

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            _buildTransactionSheet(customerName, transactions),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading transactions: $e')));
    }
  }

  Widget _buildTransactionSheet(
    String customerName,
    List<Map<String, dynamic>> transactions,
  ) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transaction History',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final date = transaction['date'] as DateTime;
                    final type = transaction['type'] as String;
                    final amount = transaction['amount'] as double;
                    final items = transaction['items'] as List? ?? [];

                    return _buildTransactionCard(date, type, amount, items);
                  },
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    DateTime date,
    String type,
    double amount,
    List items,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: type == 'Sale'
                  ? Colors.blue.shade50
                  : AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: type == 'Sale'
                        ? Colors.blue.shade100
                        : AppColors.primaryGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    type == 'Sale'
                        ? Icons.shopping_bag_outlined
                        : Icons.recycling_rounded,
                    size: 20,
                    color: type == 'Sale'
                        ? Colors.blue.shade700
                        : AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: type == 'Sale'
                              ? Colors.blue.shade700
                              : AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMMM d, yyyy').format(date),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatCurrency(amount),
                  style: AppTextStyles.h5.copyWith(
                    fontWeight: FontWeight.bold,
                    color: type == 'Sale'
                        ? Colors.blue.shade700
                        : AppColors.primaryGreen,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    if (item is! Map) return const SizedBox.shrink();

                    final itemMap = item;
                    final materialName =
                        itemMap['name'] ??
                        itemMap['material'] ??
                        itemMap['materialName'] ??
                        'Unknown';
                    final quantity =
                        double.tryParse(
                          itemMap['quantity']?.toString() ?? '0',
                        ) ??
                        0.0;

                    final double subtotal;
                    final double price;

                    if (type == 'Purchase') {
                      final subtotalValue = double.tryParse(
                        itemMap['subtotal']?.toString() ?? '0',
                      );
                      if (subtotalValue != null && subtotalValue > 0) {
                        subtotal = subtotalValue;
                        price = quantity > 0 ? subtotal / quantity : 0.0;
                      } else {
                        price =
                            double.tryParse(
                              itemMap['price']?.toString() ?? '0',
                            ) ??
                            double.tryParse(
                              itemMap['pricePerUnit']?.toString() ?? '0',
                            ) ??
                            0.0;
                        subtotal = quantity * price;
                      }
                    } else {
                      price =
                          double.tryParse(
                            itemMap['junkshopPricePerUnit']?.toString() ?? '0',
                          ) ??
                          double.tryParse(
                            itemMap['pricePerUnit']?.toString() ?? '0',
                          ) ??
                          double.tryParse(
                            itemMap['price']?.toString() ?? '0',
                          ) ??
                          0.0;
                      subtotal = quantity * price;
                    }

                    return Column(
                      children: [
                        if (index > 0) ...[
                          const SizedBox(height: 8),
                          Divider(color: Colors.grey.shade200, height: 1),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    materialName.toString(),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '${quantity.toStringAsFixed(1)} kg',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '× ${_formatCurrency(price)}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatCurrency(subtotal),
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: type == 'Sale'
                                    ? Colors.blue.shade700
                                    : AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
        final subtotal = double.tryParse(item['subtotal']?.toString() ?? '0');
        if (subtotal != null && subtotal > 0) {
          total += subtotal;
        } else {
          final quantity =
              double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
          final price =
              double.tryParse(item['price']?.toString() ?? '0') ??
              double.tryParse(item['pricePerUnit']?.toString() ?? '0') ??
              0.0;
          total += quantity * price;
        }
      }
    }
    return total;
  }

  double _calculateCollectionTotal(Map<String, dynamic> data) {
    final totalJunkshopCost = double.tryParse(
      data['totalJunkshopCost']?.toString() ?? '0',
    );
    if (totalJunkshopCost != null && totalJunkshopCost > 0) {
      return totalJunkshopCost;
    }

    final itemsData = data['purchasedItems'] ?? data['items'];
    if (itemsData == null) return 0.0;

    double total = 0.0;
    try {
      List<dynamic> itemsList = [];
      if (itemsData is Map && itemsData['list'] is List) {
        itemsList = itemsData['list'];
      } else if (itemsData is List) {
        itemsList = itemsData;
      }

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
            0.0;
        total += quantity * price;
      }
    } catch (e) {
      if (kDebugMode) print('Error calculating collection total: $e');
    }

    return total;
  }
}
