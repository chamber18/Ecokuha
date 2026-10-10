import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

class CollectionsHistoryScreen extends StatefulWidget {
  const CollectionsHistoryScreen({super.key});

  @override
  State<CollectionsHistoryScreen> createState() =>
      _CollectionsHistoryScreenState();
}

class _CollectionsHistoryScreenState extends State<CollectionsHistoryScreen> {
  // Default to completed-only view per UX requirement
  String _selectedFilter = 'completed';
  String _selectedSort = 'date_desc';
  DateTimeRange? _dateRange;
  final TextEditingController _searchController = TextEditingController();

  // Real data from Firestore
  List<Map<String, dynamic>> _collections = [];
  bool _isLoading = true;
  String? _error;

  // Cache for filtered collections to avoid recalculating on every build
  List<Map<String, dynamic>>? _cachedFilteredCollections;
  String _lastSearchTerm = '';
  String _lastFilter = 'completed';
  String _lastSort = 'date_desc';
  DateTimeRange? _lastDateRange;

  // Pagination
  static const int _pageSize = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchCompletedCollections();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload collections when screen becomes visible again (e.g., after completing a task)
    if (ModalRoute.of(context)?.isCurrent == true) {
      _fetchCompletedCollections();
    }
  }

  Future<void> _fetchCompletedCollections() async {
    final uid = currentUid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
        _error = 'Not logged in';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('📊 CollectionsHistory: ========== FETCH START ==========');
      debugPrint('📊 CollectionsHistory: Current user: $uid');

      // Query completed postings assigned to this collector
      debugPrint('🔍 Querying completed postings for collector $uid...');

      final postingRows = await supabase
          .from('postings')
          .select()
          .eq('collector_id', uid)
          .eq('status', 'completed');
      final myPostings = rowsToDocs('postings', postingRows);
      debugPrint('✅ Found ${myPostings.length} completed postings');

      debugPrint('📊 Processing ${myPostings.length} completed postings');

      final collections = <Map<String, dynamic>>[];

      for (final data in myPostings) {
        final docId = data['id'].toString();
        final status = data['status']?.toString() ?? 'completed';

        debugPrint('🔍 Processing posting $docId');

        // Extract items and total - get both purchasedItems (what junkshop paid) and verifiedItems (what collector paid)
        List<dynamic> itemsList = <dynamic>[];
        double?
        junkshopPayment; // What junkshop paid to collector (purchasedItems.total)
        double?
        collectorCost; // What collector paid to household (verifiedItems.totalValue)
        DateTime?
        purchasedAt; // When junkshop paid (purchasedItems.purchasedAt)
        String dataSource = 'items';

        // Debug: Show what structures exist
        debugPrint(
          '   - Has purchasedItems: ${data['purchasedItems'] != null} (type: ${data['purchasedItems'].runtimeType})',
        );
        debugPrint(
          '   - Has verifiedItems: ${data['verifiedItems'] != null} (type: ${data['verifiedItems'].runtimeType})',
        );
        debugPrint(
          '   - Has items: ${data['items'] != null} (type: ${data['items'].runtimeType})',
        );

        if (data['purchasedItems'] is Map<String, dynamic>) {
          // purchasedItems structure: { list: [...], total: X, purchasedAt: T }
          final purchased = data['purchasedItems'] as Map<String, dynamic>;
          itemsList = (purchased['list'] as List<dynamic>?) ?? [];
          junkshopPayment = (purchased['total'] is num)
              ? (purchased['total'] as num).toDouble()
              : null;
          purchasedAt = toDateTime(purchased['purchasedAt']);
          dataSource = 'purchasedItems';
          debugPrint('   - purchasedItems.list length: ${itemsList.length}');
          debugPrint('   - junkshopPayment: $junkshopPayment');
          debugPrint('   - purchasedAt: $purchasedAt');
          if (itemsList.isNotEmpty) {
            debugPrint('   - First item: ${itemsList[0]}');
          }
        }

        // Also extract collectorCost from verifiedItems
        if (data['verifiedItems'] is Map<String, dynamic>) {
          // verifiedItems structure: { items: [...], totalValue: X, verifiedAt: T, verifiedBy: U }
          final verified = data['verifiedItems'] as Map<String, dynamic>;
          collectorCost = (verified['totalValue'] is num)
              ? (verified['totalValue'] as num).toDouble()
              : null;
          debugPrint(
            '   - verifiedItems.items length: ${(verified['items'] as List<dynamic>?)?.length ?? 0}',
          );
          debugPrint('   - collectorCost: $collectorCost');

          // Use verifiedItems for display if purchasedItems not available
          if (itemsList.isEmpty) {
            itemsList = (verified['items'] as List<dynamic>?) ?? [];
            dataSource = 'verifiedItems';
            if (itemsList.isNotEmpty) {
              debugPrint('   - First item: ${itemsList[0]}');
            }
          }
        } else if (data['items'] is List<dynamic>) {
          // Legacy direct list
          itemsList = data['items'] as List<dynamic>;
          dataSource = 'items (legacy)';
        }

        debugPrint('   - Using $dataSource: ${itemsList.length} items');

        final items = <String>[];
        for (final item in itemsList) {
          if (item is Map<String, dynamic>) {
            // Extract name or type from the item object (type is used in verifiedItems, name in original items)
            final itemName =
                item['name']?.toString() ??
                item['type']?.toString() ??
                item['category']?.toString() ??
                item['label']?.toString() ??
                '';
            if (itemName.isNotEmpty && itemName != 'Item') {
              items.add(itemName);
            }
          } else if (item is String && item.isNotEmpty) {
            items.add(item);
          }
        }

        // Remove duplicates
        final uniqueItems = items.toSet().toList();
        debugPrint('   - Final items for display: $uniqueItems');

        // Calculate total weight
        final totalWeight = (data['estimatedTotalWeight'] is num)
            ? (data['estimatedTotalWeight'] as num).toDouble()
            : 0.0;

        // Get photos
        final photos = <String>[];
        final photoData = data['photos'];
        if (photoData is Map<String, dynamic>) {
          for (var category in ['arrival', 'collection', 'payment']) {
            final categoryPhotos = photoData[category];
            if (categoryPhotos is List) {
              photos.addAll(categoryPhotos.map((e) => e.toString()));
            }
          }
        }

        // Calculate commission: junkshop payment - collector cost
        final commission = (junkshopPayment != null && collectorCost != null)
            ? (junkshopPayment - collectorCost)
            : null;

        // Use junkshopPayment as earnings for backwards compatibility, but now we also track commission
        final earnings =
            junkshopPayment ??
            collectorCost ??
            _computeEarningsFromItems(itemsList);

        debugPrint(
          '   - Junkshop payment: ₱${junkshopPayment?.toStringAsFixed(2) ?? "N/A"}',
        );
        debugPrint(
          '   - Collector cost: ₱${collectorCost?.toStringAsFixed(2) ?? "N/A"}',
        );
        debugPrint(
          '   - Commission: ₱${commission?.toStringAsFixed(2) ?? "N/A"}',
        );

        // Debug: Show sample item prices being used
        if (itemsList.isNotEmpty && itemsList[0] is Map<String, dynamic>) {
          final firstItem = itemsList[0] as Map<String, dynamic>;
          debugPrint(
            '   - Sample item pricing: name="${firstItem['name']}", totalPrice=${firstItem['totalPrice']}, junkshopTotalPrice=${firstItem['junkshopTotalPrice']}',
          );
        }

        // Log final calculation
        debugPrint('   - Final earnings: ₱${earnings.toStringAsFixed(2)}');

        // Extract household info (nested structure support)
        final household = data['household'];
        String customerName = 'Household';
        String address = 'Address not available';

        if (household is Map<String, dynamic>) {
          customerName =
              household['full_name']?.toString() ??
              household['name']?.toString() ??
              'Household';

          final location = household['location'];
          if (location is Map<String, dynamic>) {
            address =
                location['addressShort']?.toString() ??
                location['address']?.toString() ??
                'Address not available';
          } else {
            address =
                household['address']?.toString() ??
                household['addressShort']?.toString() ??
                'Address not available';
          }
        } else {
          // Fallback to root-level fields (legacy structure)
          customerName = data['householdName']?.toString() ?? 'Household';
          address =
              data['addressShort']?.toString() ??
              data['address']?.toString() ??
              'Address not available';
        }

        // Extract collector info (this is the collector viewing their own history)
        final collectorData = data['collector'];
        String? collectorName;
        if (collectorData is Map<String, dynamic>) {
          collectorName = collectorData['name']?.toString();
        }

        collections.add({
          'id': docId,
          'customerName': customerName,
          'address': address,
          'date': toDateTime(data['updatedAt']) ?? DateTime.now(),
          'status': status,
          'earnings': earnings,
          'junkshopPayment': junkshopPayment, // What junkshop paid
          'collectorCost': collectorCost, // What collector paid
          'commission': commission, // Profit/commission
          'purchasedAt': purchasedAt, // When junkshop paid
          'items': uniqueItems,
          'itemsRaw': itemsList, // Pass raw items data for detailed view
          'rating': null, // Rating system not yet implemented
          'duration': null, // Duration tracking not yet implemented
          'weight': totalWeight > 0
              ? '${totalWeight.toStringAsFixed(1)} kg'
              : null,
          'dateCollected': toDateTime(data['updatedAt']),
          'datePosted': toDateTime(data['createdAt']),
          'scheduledDate': toDateTime(data['scheduledDate']),
          'assignedDate': toDateTime(data['assignedAt']),
          'collectorName': collectorName,
          'proofPhotos': photos,
        });
      }

      // Sort by date (most recent first)
      collections.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      debugPrint('📊 CollectionsHistory: ========== FETCH COMPLETE ==========');
      debugPrint(
        '� CollectionsHistory: Loaded ${collections.length} completed collections',
      );
      debugPrint(
        '📊 CollectionsHistory: =========================================',
      );

      setState(() {
        _collections = collections;
        _isLoading = false;
        // Invalidate cache when new data arrives
        _cachedFilteredCollections = null;
      });
    } on TimeoutException catch (e) {
      debugPrint('❌ CollectionsHistory: Timeout - $e');
      setState(() {
        _error = 'Request timed out. Check your Firestore security rules.';
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ CollectionsHistory: Error - $e');
      debugPrint('Stack: $stackTrace');
      setState(() {
        _error = 'Failed to load: $e';
        _isLoading = false;
      });
    }
  }

  double _computeEarningsFromItems(List<dynamic> items) {
    double total = 0.0;
    for (final raw in items) {
      if (raw is Map<String, dynamic>) {
        // First try to use junkshopTotalPrice (what junkshop actually paid)
        if (raw['junkshopTotalPrice'] != null) {
          final price = raw['junkshopTotalPrice'];
          if (price is num) {
            total += price.toDouble();
          } else {
            total += double.tryParse(price?.toString() ?? '') ?? 0.0;
          }
        } else if (raw['totalPrice'] != null) {
          // Fallback to totalPrice (from verifiedItems)
          final price = raw['totalPrice'];
          if (price is num) {
            total += price.toDouble();
          } else {
            total += double.tryParse(price?.toString() ?? '') ?? 0.0;
          }
        } else {
          // Fallback to estimation for old data
          final name =
              raw['name']?.toString() ?? raw['category']?.toString() ?? 'Item';
          final category =
              raw['category']?.toString() ?? _getCategoryFromItemName(name);
          final qty = raw['quantity'];
          double quantity;
          if (qty is num) {
            quantity = qty.toDouble();
          } else {
            quantity = double.tryParse(qty?.toString() ?? '') ?? 1.0;
          }
          final rate = _estimateRateForCategory(category);
          total += rate * quantity;
        }
      } else {
        // Fallback: treat as 1 unit of inferred category/name
        final name = raw.toString();
        final category = _getCategoryFromItemName(name);
        final rate = _estimateRateForCategory(category);
        total += rate * 1.0;
      }
    }
    return total;
  }

  String _getCategoryFromItemName(String name) {
    final n = name.toLowerCase();
    if (n.contains('plastic')) return 'Plastic';
    if (n.contains('metal') || n.contains('steel') || n.contains('aluminum')) {
      return 'Metal';
    }
    if (n.contains('paper') ||
        n.contains('carton') ||
        n.contains('cardboard')) {
      return 'Paper';
    }
    if (n.contains('glass') || n.contains('bottle')) return 'Glass';
    if (n.contains('elect') ||
        n.contains('appliance') ||
        n.contains('gadget')) {
      return 'Electronics';
    }
    return 'Other';
  }

  double _estimateRateForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'plastic':
        return 7.0;
      case 'metal':
        return 25.0;
      case 'paper':
        return 5.0;
      case 'glass':
        return 4.0;
      case 'electronics':
        return 100.0;
      default:
        return 10.0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredCollections();
    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 9999);
    // Reset page if filter changed and page is out of bounds
    if (_currentPage >= totalPages) _currentPage = 0;
    final pageItems = filtered
        .skip(_currentPage * _pageSize)
        .take(_pageSize)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Collection History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.collectorPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsBanner(),
          _buildSearchAndFilters(),
          Expanded(child: _buildBody(filtered, pageItems, totalPages)),
        ],
      ),
    );
  }

  // ─── Stats Banner ────────────────────────────────────────────────────────
  Widget _buildStatsBanner() {
    if (_isLoading) return const SizedBox.shrink();
    final all = _collections;
    final totalCommission = all.fold<double>(
      0.0,
      (acc, c) => acc + ((c['commission'] as double?) ?? 0.0),
    );
    final paid = all.where((c) => c['junkshopPayment'] != null).length;
    final unpaid = all.where((c) => c['junkshopPayment'] == null).length;

    return Container(
      color: AppColors.collectorPrimary,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _buildStatItem('${all.length}', 'Total'),
          _buildStatDivider(),
          _buildStatItem('$paid', 'Paid'),
          _buildStatDivider(),
          _buildStatItem('$unpaid', 'Unpaid'),
          _buildStatDivider(),
          _buildStatItem(
            '₱${NumberFormat('#,##0').format(totalCommission)}',
            'Commissions',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() => Container(
    height: 36,
    width: 1,
    color: Colors.white.withValues(alpha: 0.25),
  );

  // ─── Search + Filters ────────────────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by customer or address…',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _cachedFilteredCollections = null;
                        _currentPage = 0;
                      }),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.collectorPrimary),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 14,
              ),
              isDense: true,
            ),
            onChanged: (v) => setState(() {
              _cachedFilteredCollections = null;
              _currentPage = 0;
            }),
          ),

          const SizedBox(height: 10),

          // Chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', Icons.apps_rounded),
                _buildFilterChip(
                  'Paid',
                  'completed',
                  Icons.check_circle_rounded,
                ),
                _buildFilterChip('Unpaid', 'unpaid', Icons.pending_rounded),
                _buildFilterChip('This Week', 'week', Icons.view_week_rounded),
                _buildFilterChip(
                  'This Month',
                  'month',
                  Icons.calendar_month_rounded,
                ),
                const SizedBox(width: 4),
                _buildActionChip(
                  icon: Icons.sort_rounded,
                  label: 'Sort',
                  onTap: _showSortDialog,
                  active: _selectedSort != 'date_desc',
                ),
                const SizedBox(width: 6),
                _buildActionChip(
                  icon: Icons.date_range_rounded,
                  label: _dateRange != null ? 'Custom' : 'Dates',
                  onTap: _showDateRangePicker,
                  active: _dateRange != null,
                  trailing: _dateRange != null
                      ? GestureDetector(
                          onTap: () => setState(() {
                            _dateRange = null;
                            _cachedFilteredCollections = null;
                            _currentPage = 0;
                          }),
                          child: const Icon(Icons.close_rounded, size: 14),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedFilter = isSelected ? 'all' : value;
          _cachedFilteredCollections = null;
          _currentPage = 0;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.collectorPrimary
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.collectorPrimary.withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.collectorPrimary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active
                  ? AppColors.collectorPrimary
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active
                    ? AppColors.collectorPrimary
                    : const Color(0xFF64748B),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    List<Map<String, dynamic>> filtered,
    List<Map<String, dynamic>> pageItems,
    int totalPages,
  ) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.collectorPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading collections…',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 36,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to Load',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchCompletedCollections,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.collectorPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
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

    if (filtered.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.collectorPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        itemCount: pageItems.length + 1,
        itemBuilder: (context, index) {
          if (index < pageItems.length) {
            return _buildCollectionCard(pageItems[index]);
          }
          return _buildPaginationFooter(filtered.length, totalPages);
        },
      ),
    );
  }

  // ─── Collection Card ─────────────────────────────────────────────────────
  Widget _buildCollectionCard(Map<String, dynamic> collection) {
    final isPaid = collection['purchasedAt'] != null;
    final commission = collection['commission'] as double?;
    final collectorCost = collection['collectorCost'] as double?;
    final junkshopPayment = collection['junkshopPayment'] as double?;
    final items = (collection['items'] as List<dynamic>? ?? []).cast<String>();
    final date =
        collection['dateCollected'] as DateTime? ??
        collection['date'] as DateTime;
    final weight = collection['weight'] as String?;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/collector-collection-detail',
        arguments: collection,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: name + badge ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      collection['customerName'] as String? ?? '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPayBadge(isPaid),
                ],
              ),

              const SizedBox(height: 12),

              // ── Financial row ──
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildFinRow(
                      label: 'Spent',
                      value: collectorCost,
                      color: const Color(0xFFEF4444),
                    ),
                    _buildFinDivider(),
                    _buildFinRow(
                      label: 'Received',
                      value: junkshopPayment,
                      color: const Color(0xFF3B82F6),
                    ),
                    _buildFinDivider(),
                    _buildFinRow(
                      label: 'Commission',
                      value: commission,
                      color: AppColors.collectorPrimary,
                      bold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Bottom row: date + weight + items ──
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 11,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(date),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (weight != null) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.scale_rounded,
                      size: 11,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 3),
                    Text(
                      weight,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Color(0xFFCBD5E1),
                  ),
                ],
              ),

              // ── Items chips ──
              if (items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...items
                        .take(4)
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.collectorPrimary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.collectorPrimary,
                              ),
                            ),
                          ),
                        ),
                    if (items.length > 4)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${items.length - 4} more',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayBadge(bool isPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid
            ? AppColors.collectorPrimary.withValues(alpha: 0.1)
            : const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 11,
            color: isPaid
                ? AppColors.collectorPrimary
                : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 4),
          Text(
            isPaid ? 'Paid' : 'Unpaid',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isPaid
                  ? AppColors.collectorPrimary
                  : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinRow({
    required String label,
    required double? value,
    required Color color,
    bool bold = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value != null ? '₱${NumberFormat('#,##0.00').format(value)}' : '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: value != null ? color : const Color(0xFFCBD5E1),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFinDivider() => Container(
    height: 28,
    width: 1,
    color: const Color(0xFFE2E8F0),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );

  // ─── Pagination Footer ───────────────────────────────────────────────────
  Widget _buildPaginationFooter(int totalItems, int totalPages) {
    final start = _currentPage * _pageSize + 1;
    final end = ((_currentPage + 1) * _pageSize).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous
          _buildPageButton(
            icon: Icons.chevron_left_rounded,
            enabled: _currentPage > 0,
            onTap: () => setState(() => _currentPage--),
          ),

          // Page info
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Page ${_currentPage + 1} of $totalPages',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '$start–$end of $totalItems results',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),

          // Next
          _buildPageButton(
            icon: Icons.chevron_right_rounded,
            enabled: _currentPage < totalPages - 1,
            onTap: () => setState(() => _currentPage++),
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.collectorPrimary.withValues(alpha: 0.1)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.collectorPrimary : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters =
        _selectedFilter != 'all' ||
        _searchController.text.isNotEmpty ||
        _dateRange != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters ? Icons.search_off_rounded : Icons.history_rounded,
                size: 40,
                color: const Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilters ? 'No Matches Found' : 'No Collections Yet',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your filters or search term.'
                  : 'Your completed collections will appear here once you finish tasks.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _selectedFilter = 'all';
                  _searchController.clear();
                  _dateRange = null;
                  _cachedFilteredCollections = null;
                  _currentPage = 0;
                }),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.collectorPrimary,
                  side: BorderSide(color: AppColors.collectorPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredCollections() {
    final currentSearchTerm = _searchController.text;

    // Check if we can return cached results
    if (_cachedFilteredCollections != null &&
        _lastSearchTerm == currentSearchTerm &&
        _lastFilter == _selectedFilter &&
        _lastSort == _selectedSort &&
        _lastDateRange == _dateRange) {
      return _cachedFilteredCollections!;
    }

    // Update tracking variables
    _lastSearchTerm = currentSearchTerm;
    _lastFilter = _selectedFilter;
    _lastSort = _selectedSort;
    _lastDateRange = _dateRange;

    var filtered = _collections.where((collection) {
      // Text search
      if (currentSearchTerm.isNotEmpty) {
        final searchTerm = currentSearchTerm.toLowerCase();
        if (!collection['customerName'].toLowerCase().contains(searchTerm) &&
            !collection['address'].toLowerCase().contains(searchTerm)) {
          return false;
        }
      }

      // Status filter
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'week') {
          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          if (collection['date'].isBefore(weekAgo)) return false;
        } else if (_selectedFilter == 'month') {
          final monthAgo = DateTime.now().subtract(const Duration(days: 30));
          if (collection['date'].isBefore(monthAgo)) return false;
        } else if (_selectedFilter == 'completed') {
          // Completed: status is completed AND junkshop has paid
          if (collection['status'] != 'completed' ||
              collection['junkshopPayment'] == null) {
            return false;
          }
        } else if (_selectedFilter == 'unpaid') {
          // Unpaid: status is completed BUT junkshop hasn't paid yet
          if (collection['status'] != 'completed' ||
              collection['junkshopPayment'] != null) {
            return false;
          }
        } else if (collection['status'] != _selectedFilter) {
          return false;
        }
      }

      // Date range filter
      if (_dateRange != null) {
        final date = collection['date'] as DateTime;
        if (date.isBefore(_dateRange!.start) || date.isAfter(_dateRange!.end)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (_selectedSort) {
        case 'date_desc':
          return b['date'].compareTo(a['date']);
        case 'date_asc':
          return a['date'].compareTo(b['date']);
        case 'earnings_desc':
          return b['earnings'].compareTo(a['earnings']);
        case 'earnings_asc':
          return a['earnings'].compareTo(b['earnings']);
        case 'rating_desc':
          final aRating = a['rating'] ?? 0.0;
          final bRating = b['rating'] ?? 0.0;
          return bRating.compareTo(aRating);
        default:
          return 0;
      }
    });

    // Cache the result
    _cachedFilteredCollections = filtered;
    return filtered;
  }

  String _formatDate(DateTime date) {
    // Return full date format: "Nov 1, 2025"
    final months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Status helpers removed as status badge/controls are not shown in history view

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sort by',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(sheetCtx).pop(),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              ...[
                ('Date: Newest First', 'date_desc'),
                ('Date: Oldest First', 'date_asc'),
                ('Earnings: Highest', 'earnings_desc'),
                ('Earnings: Lowest', 'earnings_asc'),
              ].map(
                (item) => InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSort = item.$2;
                      _cachedFilteredCollections = null;
                      _currentPage = 0;
                    });
                    Navigator.of(sheetCtx).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.$1,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _selectedSort == item.$2
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _selectedSort == item.$2
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (_selectedSort == item.$2)
                          const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showDateRangePicker() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (result != null) {
      setState(() {
        _dateRange = result;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _fetchCompletedCollections();
  }
}
