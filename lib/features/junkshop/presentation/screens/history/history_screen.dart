import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../data/repositories/pickups_repository.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/cache_service.dart';
import 'package:intl/intl.dart';
import '../../widgets/purchase_details_modal.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class HistoryScreen extends StatefulWidget {
  final NewPickupItem? initialPurchaseToShow;

  const HistoryScreen({super.key, this.initialPurchaseToShow});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final IJunkshopPickupsRepository _pickupsRepo =
      getIt<IJunkshopPickupsRepository>();
  final CacheService _cacheService = CacheService();

  final List<String> _tabs = ['Purchases', 'Sales'];

  List<NewPickupItem> _reviewedPurchases = [];
  List<NewPickupItem> _manualPayouts = [];
  List<NewPickupItem> _sales = [];
  bool _isLoading = false;
  bool _hasShownInitialPurchase = false;
  bool _hasLoadedData = false;

  // Pagination state
  final ScrollController _purchasesScrollController = ScrollController();
  final ScrollController _salesScrollController = ScrollController();
  bool _isLoadingMorePurchases = false;
  bool _isLoadingMoreSales = false;
  bool _hasMorePurchases = true;
  bool _hasMoreSales = true;
  Object? _lastPurchaseDoc; // paging cursor (row offset)
  Object? _lastSaleDoc; // paging cursor (row offset)
  static const int _pageSize = 20;

  // Filter state
  String _sortBy = 'date'; // date, name, price, items
  bool _sortAscending = false; // false = descending (newest first)
  String? _filterType; // null = all, 'onsite', 'pickup'
  DateTimeRange? _dateRange;

  // Search state
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _purchasesScrollController.addListener(_onPurchasesScroll);
    _salesScrollController.addListener(_onSalesScroll);
    _fetchReviewedPurchases();
  }

  @override
  void dispose() {
    _purchasesScrollController.dispose();
    _salesScrollController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onPurchasesScroll() {
    if (_isLoadingMorePurchases || !_hasMorePurchases) return;

    final maxScroll = _purchasesScrollController.position.maxScrollExtent;
    final currentScroll = _purchasesScrollController.position.pixels;

    if (currentScroll >= maxScroll * 0.9) {
      _loadMorePurchases();
    }
  }

  void _onSalesScroll() {
    if (_isLoadingMoreSales || !_hasMoreSales) return;

    final maxScroll = _salesScrollController.position.maxScrollExtent;
    final currentScroll = _salesScrollController.position.pixels;

    if (currentScroll >= maxScroll * 0.9) {
      _loadMoreSales();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reload data on first load or if explicitly needed
    // Don't reload when returning from modal dialogs
    if (!_hasLoadedData && ModalRoute.of(context)?.isCurrent == true) {
      if (kDebugMode) print('📜 HistoryScreen: First load, fetching data...');
      _fetchReviewedPurchases();

      // Show purchase details if provided (only once)
      if (widget.initialPurchaseToShow != null && !_hasShownInitialPurchase) {
        _hasShownInitialPurchase = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showPurchaseDetailsModal(context, widget.initialPurchaseToShow!);
        });
      }
    }
  }

  Future<void> _fetchReviewedPurchases() async {
    final uid = currentUid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadedData = true;
      });
      return;
    }

    if (kDebugMode) print('📜 HistoryScreen: Loading data with caching...');

    // Step 1: Load from cache immediately for instant UI
    final cachedData = await _cacheService.getHistory(uid);
    if (cachedData != null) {
      if (kDebugMode) print('📜 HistoryScreen: ✅ Loaded from cache (instant)');
      if (!mounted) return;
      setState(() {
        // Display cached data immediately
      });
    }

    // Step 2: Fetch fresh data from Supabase (first page)
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _lastPurchaseDoc = null;
      _lastSaleDoc = null;
      _hasMorePurchases = true;
      _hasMoreSales = true;
    });
    try {
      final result = await _pickupsRepo.fetchReviewedPurchasesPaginated(
        limit: _pageSize,
      );
      final purchases = result['items'] as List<NewPickupItem>;
      _lastPurchaseDoc = result['lastDoc'] as Object?;
      _hasMorePurchases = purchases.length >= _pageSize;

      final manualPayouts = await _pickupsRepo.fetchManualPayouts();

      final salesResult = await _pickupsRepo.fetchSalesPaginated(
        limit: _pageSize,
      );
      final sales = salesResult['items'] as List<NewPickupItem>;
      _lastSaleDoc = salesResult['lastDoc'] as Object?;
      _hasMoreSales = sales.length >= _pageSize;

      if (kDebugMode) {
        print(
          '📜 HistoryScreen: ✅ Fetched ${purchases.length} purchases, ${manualPayouts.length} payouts, ${sales.length} sales from Supabase',
        );
      }

      // Step 3: Update cache for next time (non-blocking)
      _cacheService.saveHistory(
        junkshopId: uid,
        purchases: [...purchases, ...manualPayouts]
            .map(
              (p) => {
                'id': p.id,
                'householdId': p.householdId,
                'totalValue': p.totalValue,
                'householdName': p.householdName,
                'items': p.items,
                'createdAt': p.createdAt?.toIso8601String(),
                'reviewedAt': p.reviewedAt?.toIso8601String(),
              },
            )
            .toList(),
        sales: sales
            .map(
              (s) => {
                'id': s.id,
                'householdId': s.householdId,
                'totalValue': s.totalValue,
                'householdName': s.householdName,
                'items': s.items,
                'createdAt': s.createdAt?.toIso8601String(),
              },
            )
            .toList(),
      );

      if (!mounted) return;
      setState(() {
        _reviewedPurchases = purchases;
        _manualPayouts = manualPayouts;
        _sales = sales;
        if (kDebugMode) {
          print(
            '📜 Loaded ${purchases.length} purchases, ${sales.length} sales (first page)',
          );
        }
        _isLoading = false;
        _hasLoadedData = true;
      });
    } catch (e) {
      if (kDebugMode) print('❌ ERROR fetching history data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadedData = true;
      });
    }
  }

  Future<void> _loadMorePurchases() async {
    if (_isLoadingMorePurchases ||
        !_hasMorePurchases ||
        _lastPurchaseDoc == null) {
      return;
    }

    setState(() => _isLoadingMorePurchases = true);

    try {
      final result = await _pickupsRepo.fetchReviewedPurchasesPaginated(
        limit: _pageSize,
        startAfter: _lastPurchaseDoc,
      );

      final morePurchases = result['items'] as List<NewPickupItem>;
      _lastPurchaseDoc = result['lastDoc'] as Object?;

      if (mounted) {
        setState(() {
          _reviewedPurchases.addAll(morePurchases);
          _hasMorePurchases = morePurchases.length >= _pageSize;
          _isLoadingMorePurchases = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading more purchases: $e');
      if (mounted) {
        setState(() => _isLoadingMorePurchases = false);
      }
    }
  }

  Future<void> _loadMoreSales() async {
    if (_isLoadingMoreSales || !_hasMoreSales || _lastSaleDoc == null) return;

    setState(() => _isLoadingMoreSales = true);

    try {
      final result = await _pickupsRepo.fetchSalesPaginated(
        limit: _pageSize,
        startAfter: _lastSaleDoc,
      );

      final moreSales = result['items'] as List<NewPickupItem>;
      _lastSaleDoc = result['lastDoc'] as Object?;

      if (mounted) {
        setState(() {
          _sales.addAll(moreSales);
          _hasMoreSales = moreSales.length >= _pageSize;
          _isLoadingMoreSales = false;
          if (kDebugMode) print('📜 Loaded ${moreSales.length} more sales');
        });
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading more sales: $e');
      if (mounted) {
        setState(() => _isLoadingMoreSales = false);
      }
    }
  }

  String _getTimeAgo(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            message,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filterType != null) count++;
    if (_dateRange != null) count++;
    if (_sortBy != 'date' || _sortAscending != false) count++;
    return count;
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '₱${formatter.format(amount)}';
  }

  List<NewPickupItem> _applyFiltersAndSearch(
    List<NewPickupItem> items, {
    bool applyTypeFilter = true,
  }) {
    var filtered = items;

    // Apply search filter
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        final nameMatch =
            (item.householdName?.toLowerCase().contains(query) ?? false);
        final idMatch = item.id.toLowerCase().contains(query);
        final itemsMatch = item.items.any(
          (material) => material.toLowerCase().contains(query),
        );
        return nameMatch || idMatch || itemsMatch;
      }).toList();
    }

    // Apply type filter
    if (applyTypeFilter && _filterType != null) {
      filtered = filtered.where((item) {
        if (_filterType == 'onsite') {
          return _manualPayouts.any((mp) => mp.id == item.id);
        } else if (_filterType == 'pickup') {
          return !_manualPayouts.any((mp) => mp.id == item.id);
        }
        return true;
      }).toList();
    }

    // Apply date range filter
    if (_dateRange != null) {
      filtered = filtered.where((item) {
        final itemDate = item.reviewedAt ?? item.createdAt;
        if (itemDate == null) return false;
        // Use isAfter with -1 day to include start date (effectively >=)
        return itemDate.isAfter(
              _dateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            itemDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'date':
        filtered.sort((a, b) {
          final dateA = a.reviewedAt ?? a.createdAt ?? DateTime.now();
          final dateB = b.reviewedAt ?? b.createdAt ?? DateTime.now();
          return _sortAscending
              ? dateA.compareTo(dateB)
              : dateB.compareTo(dateA);
        });
        break;
      case 'name':
        filtered.sort((a, b) {
          final nameA = a.householdName ?? '';
          final nameB = b.householdName ?? '';
          return _sortAscending
              ? nameA.compareTo(nameB)
              : nameB.compareTo(nameA);
        });
        break;
      case 'price':
        filtered.sort((a, b) {
          return _sortAscending
              ? a.totalValue.compareTo(b.totalValue)
              : b.totalValue.compareTo(a.totalValue);
        });
        break;
      case 'items':
        filtered.sort((a, b) {
          return _sortAscending
              ? a.items.length.compareTo(b.items.length)
              : b.items.length.compareTo(a.items.length);
        });
        break;
    }

    return filtered;
  }

  void _showFilterModal() {
    final isPurchasesTab = _tabController.index == 0;

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
                    'Filter & Sort',
                    style: AppTextStyles.h5.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _sortBy = 'date';
                        _sortAscending = false;
                        _filterType = null;
                        _dateRange = null;
                      });
                      Navigator.pop(context);
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

              // Sort By
              Text(
                'Sort By',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<String>(
                  value: _sortBy,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'date', child: Text('Date')),
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'price', child: Text('Price')),
                    DropdownMenuItem(value: 'items', child: Text('Items')),
                  ],
                  onChanged: (value) {
                    setModalState(() => _sortBy = value!);
                    setState(() => _sortBy = value!);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Sort Direction
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sort Direction',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDirectionButton(
                          label: 'Ascending',
                          icon: Icons.arrow_upward,
                          isSelected: _sortAscending,
                          isLeft: true,
                          onTap: () {
                            setModalState(() => _sortAscending = true);
                            setState(() => _sortAscending = true);
                          },
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.borderLight,
                        ),
                        _buildDirectionButton(
                          label: 'Descending',
                          icon: Icons.arrow_downward,
                          isSelected: !_sortAscending,
                          isLeft: false,
                          onTap: () {
                            setModalState(() => _sortAscending = false);
                            setState(() => _sortAscending = false);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Type Filter (Purchases only)
              if (isPurchasesTab) ...[
                Text(
                  'Type',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      isSelected: _filterType == null,
                      onTap: () {
                        setModalState(() => _filterType = null);
                        setState(() => _filterType = null);
                      },
                    ),
                    _buildFilterChip(
                      label: 'Onsite',
                      isSelected: _filterType == 'onsite',
                      onTap: () {
                        setModalState(() => _filterType = 'onsite');
                        setState(() => _filterType = 'onsite');
                      },
                    ),
                    _buildFilterChip(
                      label: 'Pickup',
                      isSelected: _filterType == 'pickup',
                      onTap: () {
                        setModalState(() => _filterType = 'pickup');
                        setState(() => _filterType = 'pickup');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Date Range
              Text(
                'Date Range',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _dateRange,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.junkshopPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setModalState(() => _dateRange = picked);
                    setState(() => _dateRange = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _dateRange == null
                              ? 'Select date range'
                              : '${DateFormat('MMM d, y').format(_dateRange!.start)} - ${DateFormat('MMM d, y').format(_dateRange!.end)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: _dateRange == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_dateRange != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setModalState(() => _dateRange = null);
                            setState(() => _dateRange = null);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.junkshopPrimary,
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

  Widget _buildDirectionButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.junkshopPrimary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(12) : Radius.zero,
            right: !isLeft ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? AppColors.junkshopPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected
                    ? AppColors.junkshopPrimary
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
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
          color: isSelected ? AppColors.junkshopPrimary : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.junkshopPrimary
                : AppColors.borderLight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? AppColors.textWhite : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
        ),
        title: Text(
          'Transaction History',
          style: AppTextStyles.h5.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: _showFilterModal,
                icon: const Icon(
                  Icons.filter_list,
                  color: AppColors.textPrimary,
                ),
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.junkshopPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.junkshopPrimary,
          labelStyle: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTextStyles.bodyMedium,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          onTap: (index) => setState(() {}),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppColors.backgroundLight,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, material, or ID...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF6B7280),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Color(0xFF6B7280),
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Summary statistics removed — available in Analytics
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildPurchasesTab(), _buildSalesTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final allPurchases = _applyFiltersAndSearch([
      ..._reviewedPurchases,
      ..._manualPayouts,
    ]);

    if (allPurchases.isEmpty) {
      return _buildEmptyState('No purchases found');
    }

    return RefreshIndicator(
      onRefresh: _fetchReviewedPurchases,
      child: ListView.builder(
        controller: _purchasesScrollController,
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        itemCount: allPurchases.length + (_isLoadingMorePurchases ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == allPurchases.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildPurchaseItem(allPurchases[index]);
        },
      ),
    );
  }

  Widget _buildSalesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final sortedSales = _applyFiltersAndSearch([
      ..._sales,
    ], applyTypeFilter: false);

    if (sortedSales.isEmpty) {
      return _buildEmptyState('No sales found');
    }

    return RefreshIndicator(
      onRefresh: _fetchReviewedPurchases,
      child: ListView.builder(
        controller: _salesScrollController,
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        itemCount: sortedSales.length + (_isLoadingMoreSales ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == sortedSales.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildSaleItem(sortedSales[index]);
        },
      ),
    );
  }

  Widget _buildPurchaseItem(NewPickupItem purchase) {
    final isManualPayout = purchase.householdId == 'manual_payout';

    return Column(
      children: [
        InkWell(
          onTap: () => showPurchaseDetailsModal(context, purchase),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacing12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Purchase details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isManualPayout
                                  ? (purchase.householdName != null &&
                                            purchase.householdName!.isNotEmpty
                                        ? 'Onsite Customer ${purchase.householdName}'
                                        : 'Onsite Customer')
                                  : 'Collection from ${purchase.householdName ?? "Unknown"}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isManualPayout ? 'ONSITE' : 'PICKUP',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.successColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${purchase.items.length} items • ${_formatCurrency(purchase.totalValue)} • ${_getTimeAgo(purchase.reviewedAt ?? purchase.createdAt)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.borderLight),
      ],
    );
  }

  Widget _buildSaleItem(NewPickupItem sale) {
    final buyer = sale.householdName ?? 'Unknown Buyer';

    return Column(
      children: [
        InkWell(
          onTap: () => _showSaleDetails(sale),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacing12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Details column (inventory-style, no circle icon)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Sale to $buyer',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SALE',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sale.items.length} items • +${_formatCurrency(sale.totalValue)} • ${_getTimeAgo(sale.createdAt)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.borderLight),
      ],
    );
  }

  void _showSaleDetails(NewPickupItem sale) {
    // Helper to format currency within this modal context
    String formatCurrency(double amount) {
      final formatter = NumberFormat('#,##0.00', 'en_US');
      return '₱${formatter.format(amount)}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(
                    Icons.sell,
                    size: 32,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sale Details',
                          style: AppTextStyles.h6.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _getTimeAgo(sale.createdAt),
                          style: AppTextStyles.bodySmall.copyWith(
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

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Sale ID', sale.id),
                    if (sale.householdName != null)
                      _buildDetailRow('Buyer', sale.householdName!),
                    _buildDetailRow(
                      'Total Amount',
                      '+${_formatCurrency(sale.totalValue)}',
                      valueColor: AppColors.successColor,
                    ),
                    _buildDetailRow('Items', '${sale.items.length} items'),
                    _buildDetailRow(
                      'Sale Date',
                      DateFormat(
                        'MMM d, y • h:mm a',
                      ).format(sale.createdAt ?? DateTime.now()),
                    ),
                    const SizedBox(height: 16),
                    if (sale.items.isNotEmpty) ...[
                      Text(
                        'Items Sold',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...sale.itemDetails.map((item) {
                        final qty = double.tryParse(item.quantity) ?? 0.0;
                        // Derive pricePerUnit if missing but totalPrice is available
                        double derivedPricePerUnit = item.pricePerUnit ?? 0.0;
                        final rawTotal = item.totalPrice;
                        if (derivedPricePerUnit == 0.0 &&
                            rawTotal != null &&
                            rawTotal > 0 &&
                            qty > 0) {
                          derivedPricePerUnit = rawTotal / qty;
                        }
                        final totalPrice =
                            rawTotal ?? (qty * derivedPricePerUnit);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      derivedPricePerUnit > 0
                                          ? '${item.quantity} ${item.unit} • ₱${derivedPricePerUnit.toStringAsFixed(2)} per ${item.unit}'
                                          : '${item.quantity} ${item.unit}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (totalPrice > 0)
                                Text(
                                  formatCurrency(totalPrice),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
