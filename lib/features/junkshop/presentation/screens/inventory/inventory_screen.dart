import 'package:flutter/material.dart';
import 'dart:async';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../data/repositories/pickups_repository.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {

  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  // Filter state
  String _sortBy = 'name'; // name, stock, price
  bool _sortAscending = true;
  String? _stockFilter; // null = all, 'in_stock', 'low_stock', 'out_of_stock'

  // Pagination state
  static const int _itemsPerPage = 10;
  int _currentPage = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _materialsSub;

  final List<String> _categories = [
    'All',
    'battery',
    'e-waste',
    'glass',
    'metal',
    'paper',
    'plastic',
    'iron',
    'others',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _resetPagination();
      });
    });
    _loadInventory();
    _startInventoryListener();
  }

  void _startInventoryListener() async {
    try {
      final uid = currentUid;
      if (uid == null) return;

      _materialsSub?.cancel();
      _materialsSub = supabase
          .from('junkshop_materials')
          .stream(primaryKey: ['id'])
          .eq('junkshop_id', uid)
          .listen((rows) {
            final materialsMap = <String, Map<String, dynamic>>{};
            for (final doc in rowsToDocs('junkshop_materials', rows)) {
              final data = doc;
              final materialId = data['id'];
              if (materialsMap.containsKey(materialId)) continue;
              materialsMap[materialId] = {
                'id': materialId,
                'docId': materialId,
                'name': data['name'] ?? '',
                'priceMin': (data['priceMin'] as num?)?.toDouble() ?? 0.0,
                'priceMax': (data['priceMax'] as num?)?.toDouble() ?? 0.0,
                'price': (data['priceMax'] as num?)?.toDouble() ?? 0.0,
                'unit': data['unit'] ?? 'kg',
                'category': data['category'] ?? 'others',
                'stock': (data['stock'] as num?)?.toDouble() ?? 0.0,
                'commission': (data['commission'] as num?)?.toDouble() ?? 0.0,
                'icon': _getCategoryIcon(data['category'] ?? 'others'),
              };
            }
            if (mounted) {
              setState(() {
                _materials = materialsMap.values.toList();
                _isLoading = false;
                _errorMessage = null;
              });
            }
          });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _materialsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = currentUid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // Load materials from junkshop's materials with stock data (including inactive)
      final snapshot = rowsToDocs(
        'junkshop_materials',
        await supabase
            .from('junkshop_materials')
            .select()
            .eq('junkshop_id', uid)
            .order('category')
            .order('name'),
      );

      // Use a Map to deduplicate materials by their ID
      final materialsMap = <String, Map<String, dynamic>>{};

      for (final data in snapshot) {
        final materialId = data['id'];

        // Skip if we already have this material (prevents duplicates)
        if (materialsMap.containsKey(materialId)) {
          continue;
        }

        materialsMap[materialId] = {
          'id': materialId,
          'docId': materialId,
          'name': data['name'] ?? '',
          'priceMin': (data['priceMin'] as num?)?.toDouble() ?? 0.0,
          'priceMax': (data['priceMax'] as num?)?.toDouble() ?? 0.0,
          'price': (data['priceMax'] as num?)?.toDouble() ?? 0.0,
          'avgPurchaseCost':
              (data['avgPurchaseCost'] as num?)?.toDouble() ??
              (data['priceMax'] as num?)?.toDouble() ??
              0.0,
          'unit': data['unit'] ?? 'kg',
          'category': data['category'] ?? 'others',
          'stock': (data['stock'] as num?)?.toDouble() ?? 0.0,
          'commission': (data['commission'] as num?)?.toDouble() ?? 0.0,
          'icon': _getCategoryIcon(data['category'] ?? 'others'),
        };
      }

      setState(() {
        _materials = materialsMap.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'battery':
        return '🔋';
      case 'e-waste':
        return '💻';
      case 'glass':
        return '🍾';
      case 'metal':
        return '🔩';
      case 'paper':
        return '📄';
      case 'plastic':
        return '🧴';
      case 'iron':
        return '⚙️';
      default:
        return '📦';
    }
  }

  List<Map<String, dynamic>> get _filteredMaterials {
    var filtered = _materials;

    // Apply category filter
    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((m) => m['category'] == _selectedCategory)
          .toList();
    }

    // Apply search filter (by name)
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((m) => (m['name'] as String).toLowerCase().contains(query))
          .toList();
    }

    // Apply stock filter
    if (_stockFilter != null) {
      switch (_stockFilter) {
        case 'in_stock':
          filtered = filtered.where((m) => (m['stock'] as double) > 0).toList();
          break;
        case 'low_stock':
          filtered = filtered.where((m) {
            final stock = m['stock'] as double;
            return stock > 0 && stock <= 10;
          }).toList();
          break;
        case 'out_of_stock':
          filtered = filtered
              .where((m) => (m['stock'] as double) == 0)
              .toList();
          break;
      }
    }

    // Apply sorting
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) {
          final comparison = (a['name'] as String).compareTo(
            b['name'] as String,
          );
          return _sortAscending ? comparison : -comparison;
        });
        break;
      case 'stock':
        filtered.sort((a, b) {
          final comparison = (a['stock'] as double).compareTo(
            b['stock'] as double,
          );
          return _sortAscending ? comparison : -comparison;
        });
        break;
      case 'price':
        filtered.sort((a, b) {
          final comparison = (a['price'] as double).compareTo(
            b['price'] as double,
          );
          return _sortAscending ? comparison : -comparison;
        });
        break;
    }

    return filtered;
  }

  List<Map<String, dynamic>> get _currentPageMaterials {
    final filtered = _filteredMaterials;
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, filtered.length);

    if (startIndex >= filtered.length) return [];
    return filtered.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    final filtered = _filteredMaterials;
    return (filtered.length / _itemsPerPage).ceil();
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _resetPagination() {
    if (_currentPage != 0) {
      setState(() {
        _currentPage = 0;
      });
    }
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != 'All') count++;
    if (_stockFilter != null) count++;
    if (_sortBy != 'name' || _sortAscending != true) count++;
    return count;
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
                    'Filter & Sort',
                    style: AppTextStyles.h5.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'All';
                        _sortBy = 'name';
                        _sortAscending = true;
                        _stockFilter = null;
                        _resetPagination();
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

              // Category Filter
              Text(
                'Category',
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
                  value: _selectedCategory,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category == 'All'
                            ? 'All Categories'
                            : category.toUpperCase(),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setModalState(() => _selectedCategory = value!);
                    setState(() {
                      _selectedCategory = value!;
                      _resetPagination();
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

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
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'stock', child: Text('Stock')),
                    DropdownMenuItem(value: 'price', child: Text('Price')),
                  ],
                  onChanged: (value) {
                    setModalState(() => _sortBy = value!);
                    setState(() {
                      _sortBy = value!;
                      _resetPagination();
                    });
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
                            setState(() {
                              _sortAscending = true;
                              _resetPagination();
                            });
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
                            setState(() {
                              _sortAscending = false;
                              _resetPagination();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stock Filter
              Text(
                'Stock Status',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip(
                    label: 'All',
                    isSelected: _stockFilter == null,
                    onTap: () {
                      setModalState(() => _stockFilter = null);
                      setState(() {
                        _stockFilter = null;
                        _resetPagination();
                      });
                    },
                  ),
                  _buildFilterChip(
                    label: 'In Stock',
                    isSelected: _stockFilter == 'in_stock',
                    onTap: () {
                      setModalState(() => _stockFilter = 'in_stock');
                      setState(() {
                        _stockFilter = 'in_stock';
                        _resetPagination();
                      });
                    },
                  ),
                  _buildFilterChip(
                    label: 'Low Stock',
                    isSelected: _stockFilter == 'low_stock',
                    onTap: () {
                      setModalState(() => _stockFilter = 'low_stock');
                      setState(() {
                        _stockFilter = 'low_stock';
                        _resetPagination();
                      });
                    },
                  ),
                  _buildFilterChip(
                    label: 'Out of Stock',
                    isSelected: _stockFilter == 'out_of_stock',
                    onTap: () {
                      setModalState(() => _stockFilter = 'out_of_stock');
                      setState(() {
                        _stockFilter = 'out_of_stock';
                        _resetPagination();
                      });
                    },
                  ),
                ],
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

  Widget _buildPaginationControls() {
    final totalPages = _totalPages;
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _currentPage > 0
                  ? () => _goToPage(_currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
              color: AppColors.junkshopPrimary,
              disabledColor: Colors.grey[300],
            ),
            const SizedBox(width: 8),
            Text(
              'Page ${_currentPage + 1} of $totalPages',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_filteredMaterials.length} items)',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _currentPage < totalPages - 1
                  ? () => _goToPage(_currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              color: AppColors.junkshopPrimary,
              disabledColor: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inventory',
          style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
      ),
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: _loadInventory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: $_errorMessage'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadInventory,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Search bar
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search materials...',
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

                  // Material list
                  Expanded(
                    child: _filteredMaterials.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No materials in this category',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _currentPageMaterials.length + 1,
                            itemBuilder: (_, i) {
                              if (i == _currentPageMaterials.length) {
                                return _buildPaginationControls();
                              }

                              final m = _currentPageMaterials[i];
                              final stock = m['stock'] as double;
                              final avgCost =
                                  (m['avgPurchaseCost'] as num?)?.toDouble() ??
                                  0.0;
                              final totalValue = stock * avgCost;
                              final isLowStock = stock > 0 && stock < 10;
                              final isOutOfStock = stock == 0;

                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () => _showMaterialHistoryModal(m),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        m['name'],
                                                        style: AppTextStyles
                                                            .bodyMedium
                                                            .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ),
                                                    if (isLowStock)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors
                                                              .warningColor
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          'LOW',
                                                          style: AppTextStyles
                                                              .caption
                                                              .copyWith(
                                                                color: AppColors
                                                                    .warningColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                    if (isOutOfStock)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors
                                                              .errorColor
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          'OUT',
                                                          style: AppTextStyles
                                                              .caption
                                                              .copyWith(
                                                                color: AppColors
                                                                    .errorColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Stock: ${stock.toStringAsFixed(2)} ${m['unit']} • Total: ${AppFormatters.currency(totalValue)}',
                                                  style: AppTextStyles.bodySmall
                                                      .copyWith(
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Edit stock button
                                          IconButton(
                                            onPressed: () =>
                                                _showEditStockModal(m),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            iconSize: 20,
                                            color: AppColors.junkshopPrimary,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            tooltip: 'Edit stock',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.borderLight,
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showEditStockModal(Map<String, dynamic> material) {
    final stockController = TextEditingController(
      text: material['stock'].toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(material['icon'], style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Stock',
                    style: AppTextStyles.h5.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    material['name'],
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Stock: ${material['stock'].toStringAsFixed(2)} ${material['unit']}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: stockController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'New Stock (${material['unit']})',
                hintText: 'Enter new stock quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.inventory_2_outlined),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warningColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.warningColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will directly update the inventory stock. Use carefully for development/debugging.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warningColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStockText = stockController.text.trim();
              final newStock = double.tryParse(newStockText);

              if (newStock == null || newStock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid stock quantity'),
                    backgroundColor: AppColors.errorColor,
                  ),
                );
                return;
              }

              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);

              try {
                final uid = currentUid;
                if (uid == null) return;

                final oldStock = material['stock'] as double;

                await supabase
                    .from('junkshop_materials')
                    .update({'stock': newStock})
                    .eq('id', material['docId']);

                // Log activity with before/after change
                await supabase.from('activity_logs').insert({
                  'junkshop_id': uid,
                  'type': 'stock_adjustment',
                  'title': 'Stock adjusted: ${material['name']}',
                  'details': {
                    'materialId': material['id'],
                    'materialName': material['name'],
                    'oldStock': oldStock,
                    'newStock': newStock,
                    'change': newStock - oldStock,
                    'unit': material['unit'],
                  },
                });

                nav.pop();

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Stock updated: ${material['name']} → ${newStock.toStringAsFixed(2)} ${material['unit']}',
                    ),
                    backgroundColor: AppColors.successColor,
                  ),
                );
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error updating stock: $e'),
                    backgroundColor: AppColors.errorColor,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.junkshopPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  void _navigateToHistoryDetails(Map<String, dynamic> purchase) {
    Navigator.pop(context);
  }

  void _showMaterialHistoryModal(Map<String, dynamic> material) async {
    if (currentUid == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MaterialHistoryModal(
        material: material,
        onNavigateToDetails: _navigateToHistoryDetails,
      ),
    );
  }
}

// Material History Modal Widget with Purchase & Sales Tabs
class _MaterialHistoryModal extends StatefulWidget {
  final Map<String, dynamic> material;
  final Function(Map<String, dynamic>) onNavigateToDetails;

  const _MaterialHistoryModal({
    required this.material,
    required this.onNavigateToDetails,
  });

  @override
  State<_MaterialHistoryModal> createState() => _MaterialHistoryModalState();
}

class _MaterialHistoryModalState extends State<_MaterialHistoryModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
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
                    Text(
                      widget.material['icon'],
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.material['name'],
                            style: AppTextStyles.h5.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Transaction History',
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

              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: AppColors.junkshopPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.junkshopPrimary,
                tabs: const [
                  Tab(text: 'Purchases'),
                  Tab(text: 'Sales'),
                ],
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPurchaseHistory(scrollController),
                    _buildSalesHistory(scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToSalesDetails(Map<String, dynamic> saleItem) async {
    try {
      if (currentUid == null) return;

      final saleId = saleItem['saleId'] as String;

      // Fetch the complete sale row
      final saleRow = await supabase
          .from('sales')
          .select()
          .eq('id', saleId)
          .maybeSingle();

      if (saleRow == null) {
        if (kDebugMode) print('Sale document not found: $saleId');
        return;
      }

      final saleData = rowToDoc('sales', saleRow);
      final items = saleData['items'] as List<dynamic>? ?? [];
      final totalAmount = (saleData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final createdAt = toDateTime(saleData['createdAt']);
      final buyer = saleData['buyer'] as String?;

      final saleToShow = NewPickupItem(
        id: saleId,
        householdId: 'sale',
        householdName: buyer ?? 'Walk-in Buyer',
        totalValue: totalAmount,
        items: items.map((item) {
          final itemMap = item as Map<String, dynamic>;
          final name = itemMap['name'] ?? 'Unknown';
          final qty = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
          final unit = itemMap['unit'] ?? 'kg';
          return '$name (${qty.toStringAsFixed(2)} $unit)';
        }).toList(),
        itemDetails: items.map((item) {
          final itemMap = item as Map<String, dynamic>;
          final qty = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
          final total =
              (itemMap['total'] as num?)?.toDouble() ??
              (itemMap['subtotal'] as num?)?.toDouble() ??
              0.0;
          final pricePerUnit = qty > 0 ? total / qty : 0.0;

          return ItemDetail(
            name: itemMap['name'] ?? 'Unknown',
            quantity: qty.toStringAsFixed(2),
            unit: itemMap['unit'] ?? 'kg',
            condition: 'good',
            pricePerUnit: pricePerUnit,
            totalPrice: total,
          );
        }).toList(),
        createdAt: createdAt,
      );

      if (mounted) {
        // Close material history modal first
        Navigator.pop(context);

        // Show sale details modal
        _showSaleDetails(saleToShow);
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching sale details: $e');
    }
  }

  void _showSaleDetails(NewPickupItem sale) {
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
                          _formatDateTime(sale.createdAt ?? DateTime.now()),
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
                    _buildSaleDetailRow('Sale ID', sale.id),
                    if (sale.householdName != null)
                      _buildSaleDetailRow('Buyer', sale.householdName!),
                    _buildSaleDetailRow(
                      'Total Amount',
                      formatCurrency(sale.totalValue),
                      valueColor: AppColors.primaryBlue,
                    ),
                    _buildSaleDetailRow('Items', '${sale.items.length} items'),
                    _buildSaleDetailRow(
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
                        final pricePerUnit = item.pricePerUnit ?? 0.0;
                        final totalPrice =
                            item.totalPrice ?? (qty * pricePerUnit);

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
                                      pricePerUnit > 0
                                          ? '${item.quantity} ${item.unit} • ${formatCurrency(pricePerUnit)} per ${item.unit}'
                                          : '${item.quantity} ${item.unit}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatCurrency(totalPrice),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseHistory(ScrollController scrollController) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchMaterialHistory(widget.material['name']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.junkshopPrimary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading purchase history',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No purchase history',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          itemCount: history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final purchase = history[index];
            return _buildTransactionCard(
              source: purchase['source'] ?? 'Unknown',
              type: purchase['type'] ?? 'Purchase',
              quantity: purchase['quantity']?.toDouble() ?? 0.0,
              unit: purchase['unit'] ?? 'kg',
              amount: purchase['amount']?.toDouble() ?? 0.0,
              date: purchase['date'] ?? 'Unknown date',
              color: AppColors.successColor,
              onTap: () => widget.onNavigateToDetails(purchase),
            );
          },
        );
      },
    );
  }

  Widget _buildSalesHistory(ScrollController scrollController) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchMaterialSalesHistory(widget.material['name']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.junkshopPrimary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading sales history',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final salesHistory = snapshot.data ?? [];

        if (salesHistory.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No sales history',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          itemCount: salesHistory.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final sale = salesHistory[index];
            return _buildTransactionCard(
              source: sale['buyer'] ?? 'Unknown',
              type: 'Sale',
              quantity: sale['quantity']?.toDouble() ?? 0.0,
              unit: sale['unit'] ?? 'kg',
              amount: sale['amount']?.toDouble() ?? 0.0,
              date: sale['date'] ?? 'Unknown date',
              color: Colors.blue,
              onTap: () => _navigateToSalesDetails(sale),
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionCard({
    required String source,
    required String type,
    required double quantity,
    required String unit,
    required double amount,
    required String date,
    required Color color,
    VoidCallback? onTap,
    double? pricePerKg,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    source,
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
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    type,
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quantity',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${quantity.toStringAsFixed(2)} $unit',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (pricePerKg != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${AppFormatters.currency(pricePerKg)}/$unit',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Amount',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        AppFormatters.currency(amount),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.junkshopPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              date,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMaterialHistory(
    String materialName,
  ) async {
    try {
      final uid = currentUid;
      if (uid == null) return [];

      final List<Map<String, dynamic>> allHistory = [];

      if (kDebugMode) print('🔍 Fetching material history for: $materialName');

      // 1. Fetch from manual purchases (cashier)
      final purchasesSnapshot = rowsToDocs(
        'purchases',
        await supabase
            .from('purchases')
            .select()
            .eq('junkshop_id', uid)
            .eq('status', 'completed')
            .order('created_at', ascending: false)
            .limit(50),
      );

      for (final data in purchasesSnapshot) {
        final items =
            data['verifiedItems'] as List<dynamic>? ??
            data['items'] as List<dynamic>? ??
            [];

        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          if (itemMap['name'] == materialName) {
            final createdAt = toDateTime(data['createdAt']);
            allHistory.add({
              'source': 'Walk-in Customer',
              'type': 'Manual',
              'quantity': (itemMap['quantity'] as num?)?.toDouble() ?? 0.0,
              'unit': itemMap['unit'] ?? 'kg',
              'amount': (itemMap['subtotal'] as num?)?.toDouble() ?? 0.0,
              'date': createdAt != null
                  ? _formatDateTime(createdAt)
                  : 'Unknown',
              'timestamp': createdAt ?? DateTime.now(),
              'purchaseId': data['id'],
              'purchaseData': data,
            });
          }
        }
      }

      // 2. Fetch from collector pickups using repository (same as History tab)
      final repository = JunkshopPickupsRepository();
      final reviewedPurchases = await repository.fetchReviewedPurchases();

      // Cache the purchases for detail view

      if (kDebugMode) {
        print(
          '📦 Found ${reviewedPurchases.length} reviewed purchases from repository',
        );
      }

      for (final purchase in reviewedPurchases) {
        for (final item in purchase.itemDetails) {
          if (item.name == materialName) {
            final amount = item.junkshopTotalPrice ?? item.totalPrice ?? 0.0;
            final quantity = double.tryParse(item.quantity) ?? 0.0;

            allHistory.add({
              'source': purchase.householdName ?? 'Household Collection',
              'type': 'Collector',
              'quantity': quantity,
              'unit': item.unit,
              'amount': amount,
              'date': purchase.reviewedAt != null
                  ? _formatDateTime(purchase.reviewedAt!)
                  : 'Unknown',
              'timestamp': purchase.reviewedAt ?? DateTime.now(),
              'postingId': purchase.id,
              'postingData': null,
            });
          }
        }
      }

      if (kDebugMode) {
        print(
          '📊 Total history items: ${allHistory.length} (${allHistory.where((h) => h['type'] == 'Manual').length} manual + ${allHistory.where((h) => h['type'] == 'Collector').length} collector)',
        );
      }

      // Sort by timestamp descending (most recent first)
      allHistory.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      return allHistory;
    } catch (e) {
      if (kDebugMode) print('Error fetching material history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMaterialSalesHistory(
    String materialName,
  ) async {
    try {
      final uid = currentUid;
      if (uid == null) return [];

      final List<Map<String, dynamic>> allSalesHistory = [];

      if (kDebugMode) print('🔍 Fetching sales history for: $materialName');

      final salesSnapshot = rowsToDocs(
        'sales',
        await supabase
            .from('sales')
            .select()
            .eq('junkshop_id', uid)
            .order('created_at', ascending: false)
            .limit(50),
      );

      if (kDebugMode) print('📦 Found ${salesSnapshot.length} sales');

      for (final data in salesSnapshot) {
        final items = data['items'] as List<dynamic>? ?? [];

        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          if (itemMap['name'] == materialName) {
            final createdAt = toDateTime(data['createdAt']);
            final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
            final total =
                (itemMap['total'] as num?)?.toDouble() ??
                (itemMap['subtotal'] as num?)?.toDouble() ??
                0.0;
            final pricePerKg = quantity > 0 ? total / quantity : 0.0;

            allSalesHistory.add({
              'buyer': data['buyer'] ?? 'Walk-in Buyer',
              'quantity': quantity,
              'unit': itemMap['unit'] ?? 'kg',
              'pricePerKg': pricePerKg,
              'amount': total,
              'date': createdAt != null
                  ? _formatDateTime(createdAt)
                  : 'Unknown',
              'timestamp': createdAt ?? DateTime.now(),
              'saleId': data['id'],
            });
          }
        }
      }

      if (kDebugMode) print('📊 Total sales items: ${allSalesHistory.length}');

      // Sort by timestamp descending (most recent first)
      allSalesHistory.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      return allSalesHistory;
    } catch (e) {
      if (kDebugMode) print('Error fetching material sales history: $e');
      return [];
    }
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hr' : 'hrs'} ago';
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
}
