import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../screens/junkshop_profile_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class JunkshopSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> junkshops;
  final Map<String, dynamic>? selectedJunkshop;
  final Function(Map<String, dynamic>?) onJunkshopSelected;

  const JunkshopSelectionSheet({
    super.key,
    required this.junkshops,
    this.selectedJunkshop,
    required this.onJunkshopSelected,
  });

  @override
  State<JunkshopSelectionSheet> createState() => _JunkshopSelectionSheetState();
}

class _JunkshopSelectionSheetState extends State<JunkshopSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Sort state
  String _sortMode = 'nearest'; // 'nearest' | 'price_high' | 'rating'
  String? _selectedMaterial;
  List<String> _availableMaterials = [];
  Map<String, _MaterialPrice> _materialPriceMap = {}; // junkshopId → min/max
  bool _isLoadingPrices = false;
  bool _isLoadingMaterials = false;

  List<Map<String, dynamic>> get _filteredAndSortedJunkshops {
    var filtered = widget.junkshops.where((junkshop) {
      if (_searchQuery.isNotEmpty) {
        final name = (junkshop['name'] as String? ?? '').toLowerCase();
        final address =
            (junkshop['address'] as String? ??
                    junkshop['location'] as String? ??
                    '')
                .toLowerCase();
        final query = _searchQuery.toLowerCase();
        if (!name.contains(query) && !address.contains(query)) return false;
      }
      return true;
    }).toList();

    if (_sortMode == 'nearest') {
      filtered.sort((a, b) {
        final distA = (a['distance'] as num?)?.toDouble() ?? double.infinity;
        final distB = (b['distance'] as num?)?.toDouble() ?? double.infinity;
        return distA.compareTo(distB);
      });
    } else if (_sortMode == 'price_high') {
      filtered.sort((a, b) {
        final priceA = _materialPriceMap[a['id'] as String?]?.max ?? -1;
        final priceB = _materialPriceMap[b['id'] as String?]?.max ?? -1;
        return priceB.compareTo(priceA);
      });
    } else if (_sortMode == 'rating') {
      filtered.sort((a, b) {
        final rA = (a['rating'] as num?)?.toDouble() ?? 0;
        final rB = (b['rating'] as num?)?.toDouble() ?? 0;
        return rB.compareTo(rA);
      });
    }

    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _loadAvailableMaterials();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetch all distinct active material names across all junkshops.
  Future<void> _loadAvailableMaterials() async {
    if (widget.junkshops.isEmpty) return;
    setState(() => _isLoadingMaterials = true);
    try {
      final db = Supabase.instance.client;
      final nameSet = <String>{};
      for (final shop in widget.junkshops) {
        final id = shop['id'] as String?;
        if (id == null) continue;
        final rows = await db
            .from('junkshop_materials')
            .select('name')
            .eq('junkshop_id', id)
            .eq('is_active', true);
        for (final row in rows) {
          final name = row['name']?.toString().trim();
          if (name != null && name.isNotEmpty) nameSet.add(name);
        }
      }
      final sorted = nameSet.toList()..sort();
      setState(() {
        _availableMaterials = sorted;
        if (sorted.isNotEmpty && _selectedMaterial == null) {
          _selectedMaterial = sorted.first;
        }
      });
    } catch (_) {
    } finally {
      setState(() => _isLoadingMaterials = false);
    }
  }

  /// Load buying prices (householdPriceMin + householdPriceMax) for [materialName] per junkshop.
  Future<void> _loadPricesForMaterial(String materialName) async {
    setState(() => _isLoadingPrices = true);
    _materialPriceMap = {};
    try {
      final db = Supabase.instance.client;
      for (final shop in widget.junkshops) {
        final id = shop['id'] as String?;
        if (id == null) continue;
        final data = await db
            .from('junkshop_materials')
            .select('household_price_min, household_price_max')
            .eq('junkshop_id', id)
            .eq('is_active', true)
            .eq('name', materialName)
            .limit(1)
            .maybeSingle();
        if (data != null) {
          final min = (data['household_price_min'] as num?)?.toDouble();
          final max = (data['household_price_max'] as num?)?.toDouble() ?? 0.0;
          _materialPriceMap[id] = _MaterialPrice(min: min, max: max);
        }
      }
    } catch (_) {
    } finally {
      setState(() => _isLoadingPrices = false);
    }
  }

  void _onSortSelected(String mode) {
    setState(() => _sortMode = mode);
    if (mode == 'price_high' && _selectedMaterial != null) {
      _loadPricesForMaterial(_selectedMaterial!);
    }
  }

  void _onMaterialChanged(String name) {
    setState(() => _selectedMaterial = name);
    if (_sortMode == 'price_high') {
      _loadPricesForMaterial(name);
    }
  }

  /// Opens a searchable bottom sheet to pick a material.
  void _openMaterialSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MaterialSearchSheet(
        materials: _availableMaterials,
        selected: _selectedMaterial,
        onSelected: (name) {
          Navigator.pop(ctx);
          _onMaterialChanged(name);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredJunkshops = _filteredAndSortedJunkshops;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Junkshop',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Search bar
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search junkshops...',
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

              const SizedBox(height: 12),

              // ── Sort pills ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SortPill(
                        label: 'Nearest',
                        icon: Icons.near_me,
                        selected: _sortMode == 'nearest',
                        onTap: () => _onSortSelected('nearest'),
                      ),
                      const SizedBox(width: 8),
                      _SortPill(
                        label: 'Highest Price',
                        icon: Icons.arrow_upward,
                        selected: _sortMode == 'price_high',
                        onTap: () => _onSortSelected('price_high'),
                      ),
                      const SizedBox(width: 8),
                      _SortPill(
                        label: 'Top Rated',
                        icon: Icons.star_rounded,
                        selected: _sortMode == 'rating',
                        onTap: () => _onSortSelected('rating'),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Material picker (only for price sorting) ──────────
              if (_sortMode == 'price_high') ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                  ),
                  child: _isLoadingMaterials
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Loading materials...',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      : _availableMaterials.isEmpty
                      ? Text(
                          'No materials found',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        )
                      : Row(
                          children: [
                            Text(
                              'Material:',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: _openMaterialSearch,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.primaryGreen.withValues(alpha: 
                                        0.4,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedMaterial ??
                                              'Select material',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: _selectedMaterial != null
                                                    ? const Color(0xFF111827)
                                                    : const Color(0xFF9CA3AF),
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.search,
                                        size: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_isLoadingPrices) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],

              const SizedBox(height: 12),

              // Results count
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                ),
                child: Row(
                  children: [
                    Text(
                      '${filteredJunkshops.length} junkshop${filteredJunkshops.length != 1 ? 's' : ''} found',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Junkshop list
              Expanded(
                child: filteredJunkshops.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No junkshops found',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingL,
                          vertical: 8,
                        ),
                        itemCount: filteredJunkshops.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final junkshop = filteredJunkshops[index];
                          final isSelected =
                              widget.selectedJunkshop?['id'] == junkshop['id'];
                          return _buildJunkshopCard(junkshop, isSelected);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJunkshopCard(Map<String, dynamic> junkshop, bool isSelected) {
    final name = junkshop['name'] as String? ?? 'Unknown';
    final distance = (junkshop['distance'] as num?)?.toDouble();
    final serviceRadius = (junkshop['serviceRadius'] as num?)?.toDouble();
    final address =
        junkshop['address'] as String? ??
        junkshop['location'] as String? ??
        'Location not set';
    final isAvailable = junkshop['isAvailable'] as bool? ?? true;
    final shopId = junkshop['id'] as String?;
    final materialPrice =
        (_sortMode == 'price_high' &&
            shopId != null &&
            _materialPriceMap.containsKey(shopId))
        ? _materialPriceMap[shopId]
        : null;

    if (kDebugMode) {
      print(
        '[JunkshopCard] $name: distance=$distance, serviceRadius=$serviceRadius, showIndicator=${serviceRadius != null && distance != null}',
      );
    }

    return GestureDetector(
      onTap: () {
        if (!isAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                junkshop['unavailableReason'] as String? ??
                    'This junkshop is temporarily unavailable',
              ),
              backgroundColor: AppColors.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        widget.onJunkshopSelected(junkshop);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Main info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Star rating
                      Builder(
                        builder: (_) {
                          final r = (junkshop['rating'] as num?)?.toDouble();
                          if (r == null || r <= 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: _sortMode == 'rating'
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFD1D5DB),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  r.toStringAsFixed(1),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _sortMode == 'rating'
                                        ? const Color(0xFFF59E0B)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (distance != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Address and operation range
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  if (serviceRadius != null && distance != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          distance <= serviceRadius
                              ? Icons.check_circle
                              : Icons.info_outline,
                          size: 12,
                          color: distance <= serviceRadius
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distance <= serviceRadius
                              ? 'In Range (${serviceRadius.toStringAsFixed(0)} km)'
                              : 'Outside Range (${serviceRadius.toStringAsFixed(0)} km)',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: distance <= serviceRadius
                                ? Colors.green[700]
                                : Colors.orange[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    JunkshopProfileScreen(shop: junkshop),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'View Profile',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Material price badge — shown at the bottom of the card
                  if (materialPrice != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primaryGreen.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 13,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Buying price: ',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            materialPrice.label,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that lets the user search and select a material.
class _MaterialSearchSheet extends StatefulWidget {
  final List<String> materials;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _MaterialSearchSheet({
    required this.materials,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_MaterialSearchSheet> createState() => _MaterialSearchSheetState();
}

class _MaterialSearchSheetState extends State<_MaterialSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.materials);
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(widget.materials)
          : widget.materials.where((m) => m.toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Select Material',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    color: const Color(0xFF6B7280),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search materials...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            // Material list
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No materials found',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final name = _filtered[i];
                        final isSelected = name == widget.selected;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.circle,
                            size: 8,
                            color: isSelected
                                ? AppColors.primaryGreen
                                : const Color(0xFFD1D5DB),
                          ),
                          title: Text(
                            name,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primaryGreen
                                  : const Color(0xFF111827),
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: AppColors.primaryGreen,
                                )
                              : null,
                          onTap: () => widget.onSelected(name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Holds the min/max buying price for a material at a specific junkshop.
class _MaterialPrice {
  final double? min;
  final double max;

  const _MaterialPrice({required this.min, required this.max});

  /// Display string: shows range if min is set and differs from max,
  /// otherwise shows only the max price.
  String get label {
    if (min != null && min! > 0 && min! < max) {
      return '\u20B1${min!.toStringAsFixed(2)}\u2013\u20B1${max.toStringAsFixed(2)}/unit';
    }
    return '\u20B1${max.toStringAsFixed(2)}/unit';
  }
}
