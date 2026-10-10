import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../data/repositories/household_posting_repository.dart';
import 'collection_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all';
  String _selectedSort = 'date_desc';
  DateTimeRange? _selectedDateRange;
  final _searchController = TextEditingController();

  List<CompletedCollection> _collections = [];
  bool _isLoading = true;
  final _repository = getIt<IHouseholdPostingRepository>();

  // Deep-link support: if provided, open this collection's details on load
  String? _focusCollectionId;
  bool _didHandleInitialFocus = false;

  // Cache filtered and computed values to avoid recalculating on every build
  List<CompletedCollection>? _cachedFilteredCollections;
  String _lastFilter = 'all';
  String _lastSort = 'date_desc';
  DateTimeRange? _lastDateRange;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read optional navigation arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final id = (args['focusId'] ?? args['collectionId'] ?? args['id']);
      if (id is String && id.isNotEmpty) {
        _focusCollectionId = id;
        debugPrint('[HistoryScreen] Received focusId: $_focusCollectionId');
      }
    }
  }

  Future<void> _loadCollections() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('[HistoryScreen] Calling repository to fetch collections...');
      final collections = await _repository.fetchCompletedCollections();
      debugPrint(
        '[HistoryScreen] Received ${collections.length} collections from repository',
      );
      setState(() {
        _collections = collections;
        _isLoading = false;
        // Invalidate caches when data changes
        _cachedFilteredCollections = null;
      });
      debugPrint(
        '[HistoryScreen] State updated with ${_collections.length} collections',
      );

      // After loading, open focused collection if requested
      _openFocusedCollectionIfAny();
    } catch (e) {
      debugPrint('Error loading collections: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openFocusedCollectionIfAny() {
    if (_didHandleInitialFocus) return;
    if (_focusCollectionId == null || _focusCollectionId!.isEmpty) return;
    if (_collections.isEmpty) return;

    CompletedCollection? match;
    try {
      match = _collections.firstWhere((c) => c.id == _focusCollectionId);
    } catch (_) {
      match = null;
    }
    if (match != null) {
      _didHandleInitialFocus = true;
      // Use post-frame to ensure context is ready for bottom sheet/dialog
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Small delay makes sure push animation finished
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        _showCollectionDetails(match!);
      });
    }
  }

  // Note: Build method remains unchanged below. We only added deep-link handling
  // via didChangeDependencies and _openFocusedCollectionIfAny().

  List<CompletedCollection> get _filteredCollections {
    // Invalidate cache if filters changed
    if (_lastFilter != _selectedFilter ||
        _lastSort != _selectedSort ||
        _lastDateRange != _selectedDateRange) {
      _cachedFilteredCollections = null;
      _lastFilter = _selectedFilter;
      _lastSort = _selectedSort;
      _lastDateRange = _selectedDateRange;
    }

    // Return cached value if available
    if (_cachedFilteredCollections != null) return _cachedFilteredCollections!;

    var filtered = _collections.where((collection) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final matchesSearch =
            collection.id.toLowerCase().contains(searchLower) ||
            (collection.junkshopName?.toLowerCase().contains(searchLower) ??
                false) ||
            (collection.collectorName?.toLowerCase().contains(searchLower) ??
                false) ||
            collection.items.any(
              (item) => item.toLowerCase().contains(searchLower),
            );

        if (!matchesSearch) return false;
      }

      // Status filter
      if (_selectedFilter != 'all') {
        final collectionStatus = collection.status ?? 'completed';
        // Map 'declined' filter to both 'cancelled' and 'declined' statuses
        if (_selectedFilter == 'declined') {
          if (collectionStatus != 'cancelled' &&
              collectionStatus != 'declined') {
            return false;
          }
        } else if (_selectedFilter == 'completed') {
          if (collectionStatus != 'completed') {
            return false;
          }
        }
      }

      // Date range filter
      if (_selectedDateRange != null) {
        final transactionDate =
            collection.reviewedAt ??
            collection.collectedAt ??
            collection.createdAt;
        if (transactionDate != null &&
            (transactionDate.isBefore(_selectedDateRange!.start) ||
                transactionDate.isAfter(
                  _selectedDateRange!.end.add(const Duration(days: 1)),
                ))) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort collections
    filtered.sort((a, b) {
      switch (_selectedSort) {
        case 'date_asc':
          final dateA =
              a.reviewedAt ?? a.collectedAt ?? a.createdAt ?? DateTime.now();
          final dateB =
              b.reviewedAt ?? b.collectedAt ?? b.createdAt ?? DateTime.now();
          return dateA.compareTo(dateB);
        case 'date_desc':
          final dateA =
              a.reviewedAt ?? a.collectedAt ?? a.createdAt ?? DateTime.now();
          final dateB =
              b.reviewedAt ?? b.collectedAt ?? b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
        case 'amount_asc':
          return a.totalValue.compareTo(b.totalValue);
        case 'amount_desc':
          return b.totalValue.compareTo(a.totalValue);
        default:
          final dateA =
              a.reviewedAt ?? a.collectedAt ?? a.createdAt ?? DateTime.now();
          final dateB =
              b.reviewedAt ?? b.collectedAt ?? b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
      }
    });

    _cachedFilteredCollections = filtered;
    return _cachedFilteredCollections!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F0F0)),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(child: _buildAllTransactionsTab()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search by junkshop, collector, item…',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFADB5BD),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFFADB5BD),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _cachedFilteredCollections = null;
                            });
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Color(0xFFADB5BD),
                          ),
                        )
                      : null,
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _cachedFilteredCollections = null;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter row — touches edges
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 0, bottom: 10),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Completed', 'completed'),
                _buildFilterChip('Declined', 'declined'),
                const SizedBox(width: 8),
                _buildDateRangeChip(),
                const SizedBox(width: 8),
                _buildSortChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String text, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeChip() {
    final active = _selectedDateRange != null;
    return GestureDetector(
      onTap: _showDateRangePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryGreen : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              active ? 'Custom Range' : 'Date',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _selectedDateRange = null),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip() {
    return GestureDetector(
      onTap: _showSortDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, size: 15, color: Color(0xFF6B7280)),
            SizedBox(width: 4),
            Text(
              'Sort',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption('Date (Newest First)', 'date_desc'),
            _buildSortOption('Date (Oldest First)', 'date_asc'),
            _buildSortOption('Amount (Highest First)', 'amount_desc'),
            _buildSortOption('Amount (Lowest First)', 'amount_asc'),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: _selectedSort,
      onChanged: (selected) {
        setState(() {
          _selectedSort = selected!;
        });
        Navigator.of(context).pop();
      },
      activeColor: AppColors.primaryGreen,
    );
  }

  void _showDateRangePicker() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (result != null) {
      setState(() {
        _selectedDateRange = result;
      });
    }
  }

  Widget _buildAllTransactionsTab() {
    debugPrint(
      '[HistoryScreen] _buildAllTransactionsTab - isLoading: $_isLoading, collections count: ${_collections.length}',
    );

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredCollections = _filteredCollections;
    debugPrint(
      '[HistoryScreen] Filtered collections count: ${filteredCollections.length}',
    );

    if (filteredCollections.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadCollections,
      color: AppColors.primaryGreen,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: filteredCollections.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFF3F4F6),
          indent: 31,
        ),
        itemBuilder: (context, index) {
          final collection = filteredCollections[index];
          return _buildCollectionCard(collection);
        },
      ),
    );
  }

  Widget _buildCollectionCard(CompletedCollection collection) {
    final isDeclined =
        collection.status?.toLowerCase() == 'declined' ||
        collection.status?.toLowerCase() == 'cancelled';

    final displayDate = isDeclined
        ? (collection.declinedAt ??
              collection.reviewedAt ??
              collection.createdAt)
        : (collection.reviewedAt ??
              collection.collectedAt ??
              collection.createdAt);
    final collectedDate = displayDate != null
        ? _formatShortDate(displayDate)
        : 'N/A';

    double computedTotal = 0.0;
    for (final item in collection.itemsData) {
      double itemValue = 0.0;
      if (item['junkshopTotalPrice'] != null) {
        itemValue = (item['junkshopTotalPrice'] as num).toDouble();
      } else if (item['totalPrice'] != null) {
        itemValue = (item['totalPrice'] as num).toDouble();
      } else if (item['pricePerUnit'] != null && item['quantity'] != null) {
        itemValue =
            (item['pricePerUnit'] as num).toDouble() *
            (item['quantity'] as num).toDouble();
      } else if (item['junkshopPricePerUnit'] != null &&
          item['quantity'] != null) {
        itemValue =
            (item['junkshopPricePerUnit'] as num).toDouble() *
            (item['quantity'] as num).toDouble();
      }
      computedTotal += itemValue;
    }

    final statusColor = _getStatusColor(collection.status);

    // Build item label: first item + overflow count
    final itemCount = collection.items.length;
    final firstItem = itemCount > 0 ? collection.items.first : null;
    final itemLabel = firstItem != null
        ? (itemCount > 1 ? '$firstItem +${itemCount - 1}' : firstItem)
        : '$itemCount item${itemCount != 1 ? 's' : ''}';

    return GestureDetector(
      onTap: () => _showCollectionDetails(collection),
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: junkshop + amount
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          collection.junkshopName ?? 'Unknown Junkshop',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isDeclined)
                        Text(
                          '₱${NumberFormat('#,##0.00').format(computedTotal)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getStatusLabel(collection.status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Bottom row: date · items · status pill (completed only)
                  Row(
                    children: [
                      Text(
                        collectedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        '  ·  ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD1D5DB),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          itemLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isDeclined)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getStatusLabel(collection.status),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFD1D5DB),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 30,
                color: Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results found'
                  : 'No transactions yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different keyword or clear filters'
                  : _selectedFilter == 'declined'
                  ? 'No declined or cancelled collections'
                  : 'Completed collections will show up here',
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showCollectionDetails(CompletedCollection collection) {
    // Use actual item data with prices from verifiedItems/purchasedItems
    double calculatedTotal = 0.0;
    for (final item in collection.itemsData) {
      // Priority: junkshopTotalPrice > totalPrice > quantity * pricePerUnit
      double itemValue = 0.0;
      if (item['junkshopTotalPrice'] != null) {
        itemValue = (item['junkshopTotalPrice'] as num).toDouble();
      } else if (item['totalPrice'] != null) {
        itemValue = (item['totalPrice'] as num).toDouble();
      } else if (item['pricePerUnit'] != null && item['quantity'] != null) {
        final pricePerUnit = (item['pricePerUnit'] as num).toDouble();
        final quantity = (item['quantity'] as num).toDouble();
        itemValue = pricePerUnit * quantity;
      } else if (item['junkshopPricePerUnit'] != null &&
          item['quantity'] != null) {
        final pricePerUnit = (item['junkshopPricePerUnit'] as num).toDouble();
        final quantity = (item['quantity'] as num).toDouble();
        itemValue = pricePerUnit * quantity;
      }
      calculatedTotal += itemValue;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CollectionDetailsScreen(
          collection: collection,
          calculatedTotal: calculatedTotal,
          parsedItems: collection.itemsData,
          onRefresh: _loadCollections,
        ),
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    const months = [
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'declined':
        return 'Declined';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Completed';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return AppColors.primaryGreen;
      case 'declined':
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors.primaryGreen;
    }
  }
}

class FullScreenPhotoViewer extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;

  const FullScreenPhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = widget.photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentPhoto['icon'] as IconData,
              color: currentPhoto['color'] as Color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              currentPhoto['title'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (currentPhoto['color'] as Color).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentIndex + 1}/${widget.photos.length}',
              style: TextStyle(
                color: currentPhoto['color'] as Color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.photos.length,
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: photo['url'] as String,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Navigation arrows
          if (widget.photos.length > 1) ...[
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _currentIndex > 0
                      ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                      : null,
                  icon: Icon(
                    Icons.chevron_left,
                    color: _currentIndex > 0
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    size: 48,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _currentIndex < widget.photos.length - 1
                      ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                      : null,
                  icon: Icon(
                    Icons.chevron_right,
                    color: _currentIndex < widget.photos.length - 1
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    size: 48,
                  ),
                ),
              ),
            ),
          ],

          // Photo indicators
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photos.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentIndex
                        ? (widget.photos[index]['color'] as Color)
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
