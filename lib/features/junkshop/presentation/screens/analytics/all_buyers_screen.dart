import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../data/services/junkshop_query.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_text_styles.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class AllBuyersScreen extends StatefulWidget {
  const AllBuyersScreen({super.key});

  @override
  State<AllBuyersScreen> createState() => _AllBuyersScreenState();
}

class _AllBuyersScreenState extends State<AllBuyersScreen> {
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _allBuyers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String _selectedPeriod = 'Month';
  String _sortBy = 'value'; // 'value' or 'name'
  String _sortDirection = 'desc'; // 'asc' or 'desc'
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Filter state
  String? _filterType; // null = all, 'named', 'walkin'
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
      _loadAllBuyers();
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
      _loadMoreBuyers();
    }
  }

  Future<void> _loadAllBuyers() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() {
        _isLoading = true;
        _allBuyers = [];
        _hasMoreData = true;
      });

      await _fetchBuyers();
    } catch (e) {
      if (kDebugMode) print('Error loading buyers: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreBuyers() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      await _fetchBuyers();
    } catch (e) {
      if (kDebugMode) print('Error loading more buyers: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _fetchBuyers() async {
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

      Map<String, Map<String, dynamic>> buyerStats = {};

      final salesSnapshot = await JunkshopQuery.table(
        'sales',
        user.id,
        from: startDate,
        to: _selectedPeriod == 'Custom' ? _customEndDate : null,
        orderBy: 'created_at',
        desc: true,
      );

      for (var doc in salesSnapshot.docs) {
        final data = doc.data();

        String buyerName =
            data['customerName'] as String? ??
            data['buyerName'] as String? ??
            data['buyer'] as String? ??
            '';
        String buyerContact =
            data['customerContact'] as String? ??
            data['buyerContact'] as String? ??
            data['contact'] as String? ??
            '';

        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

        if (totalAmount == 0.0) continue;

        String buyerKey;
        String displayName;
        String contact = buyerContact;

        if (buyerName.isNotEmpty &&
            !buyerName.toLowerCase().contains('walk-in')) {
          buyerKey = buyerContact.isNotEmpty
              ? '$buyerName|$buyerContact'
              : buyerName;
          displayName = buyerName;
        } else {
          buyerKey = 'walkin_${doc.id}';
          displayName = buyerContact.isNotEmpty
              ? 'Walk-in ($buyerContact)'
              : 'Walk-in Customer #${doc.id.substring(0, 6)}';
        }

        if (!buyerStats.containsKey(buyerKey)) {
          buyerStats[buyerKey] = {
            'name': displayName,
            'contact': contact,
            'totalValue': 0.0,
            'purchases': 0,
          };
        }

        buyerStats[buyerKey]!['totalValue'] =
            (buyerStats[buyerKey]!['totalValue'] as double) + totalAmount;
        buyerStats[buyerKey]!['purchases'] =
            (buyerStats[buyerKey]!['purchases'] as int) + 1;
      }

      // All data loaded — no more pages
      _hasMoreData = false;

      final buyers = buyerStats.values.toList();
      final filtered = _applyFilters(buyers);
      _sortBuyers(filtered);

      if (mounted) {
        setState(() {
          _allBuyers = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching buyers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _sortBuyers(List<Map<String, dynamic>> buyers) {
    if (_sortBy == 'value') {
      buyers.sort((a, b) {
        final comparison = (b['totalValue'] as double).compareTo(
          a['totalValue'] as double,
        );
        return _sortDirection == 'desc' ? comparison : -comparison;
      });
    } else {
      buyers.sort((a, b) {
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

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> buyers) {
    var filtered = buyers;

    // Apply type filter
    if (_filterType != null) {
      filtered = filtered.where((buyer) {
        final name = buyer['name'] as String;
        if (_filterType == 'named') {
          return !name.toLowerCase().contains('walk-in');
        } else if (_filterType == 'walkin') {
          return name.toLowerCase().contains('walk-in');
        }
        return true;
      }).toList();
    }

    // Apply value range filter
    if (_minValue != null) {
      filtered = filtered.where((buyer) {
        final value = buyer['totalValue'] as double;
        return value >= _minValue!;
      }).toList();
    }

    if (_maxValue != null) {
      filtered = filtered.where((buyer) {
        final value = buyer['totalValue'] as double;
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
                      _loadAllBuyers();
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
              const SizedBox(height: 32),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadAllBuyers();
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
          'All Buyers',
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
        onRefresh: _loadAllBuyers,
        child: Column(
          children: [
            // Stats summary
            if (!_isLoading && _allBuyers.isNotEmpty)
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
                        'Total Buyers',
                        _allBuyers.length.toString(),
                        Icons.people,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Purchases',
                        _allBuyers
                            .fold<int>(
                              0,
                              (acc, b) => acc + (b['purchases'] as int),
                            )
                            .toString(),
                        Icons.shopping_cart,
                      ),
                    ),
                  ],
                ),
              ),

            // Buyers list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allBuyers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 64,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No buyers data available',
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
                      itemCount: _allBuyers.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _allBuyers.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final buyer = _allBuyers[index];
                        return _buildBuyerCard(buyer, index + 1);
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
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[700], size: 20),
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
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerCard(Map<String, dynamic> buyer, int rank) {
    final totalValue = buyer['totalValue'] as double;
    final purchases = buyer['purchases'] as int;
    final avgValue = purchases > 0 ? totalValue / purchases : 0.0;
    final contact = buyer['contact'] as String;
    final buyerName = buyer['name'] as String;

    return InkWell(
      onTap: () => _showTransactionHistory(buyerName, 'buyer'),
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
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.blue[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Buyer info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buyer['name'] as String,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.isNotEmpty
                          ? '$contact • $purchases purchases • Avg: ${_formatCurrency(avgValue)}'
                          : '$purchases purchases • Avg: ${_formatCurrency(avgValue)}',
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
                  color: Colors.blue[700],
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

      final salesQuery = await JunkshopQuery.table('sales', junkshopId);

      for (var doc in salesQuery.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) continue;

        final date = createdAt.toDate();

        // Use the same lookup order as _fetchBuyers
        String buyerName =
            data['customerName'] as String? ??
            data['buyerName'] as String? ??
            data['buyer'] as String? ??
            '';

        // Also check nested buyer map
        if (buyerName.isEmpty) {
          final buyerData = data['buyer'];
          if (buyerData is Map<String, dynamic>) {
            buyerName =
                (buyerData['name'] ??
                        buyerData['buyerName'] ??
                        buyerData['customerName'] ??
                        '')
                    as String;
          }
        }

        if (buyerName == customerName) {
          final items = data['items'];
          final itemsList = items is List ? items : [];

          transactions.add({
            'date': date,
            'type': 'Sale',
            'amount': (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
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
                    final amount = (transaction['amount'] as num).toDouble();
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
              color: Colors.blue.shade50,
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
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 20,
                    color: Colors.blue.shade700,
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
                          color: Colors.blue.shade700,
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
                    color: Colors.blue.shade700,
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

                    final subtotalValue = double.tryParse(
                      itemMap['subtotal']?.toString() ?? '0',
                    );
                    final double subtotal;
                    final double price;

                    if (subtotalValue != null && subtotalValue > 0) {
                      subtotal = subtotalValue;
                      price = quantity > 0 ? subtotal / quantity : 0.0;
                    } else {
                      price =
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
                                color: Colors.blue.shade700,
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
}
