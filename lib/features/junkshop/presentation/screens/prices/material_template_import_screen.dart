import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class MaterialTemplateImportScreen extends StatefulWidget {
  const MaterialTemplateImportScreen({super.key});

  @override
  State<MaterialTemplateImportScreen> createState() =>
      _MaterialTemplateImportScreenState();
}

class _MaterialTemplateImportScreenState
    extends State<MaterialTemplateImportScreen> {
  final _uuid = const Uuid();

  // Template data grouped by category
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  List<String> _categoryOrder = [];

  // Selection state
  final Set<String> _selectedIds = {};

  // Custom materials added by the owner
  final List<Map<String, dynamic>> _customMaterials = [];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Already-imported material names (lowercase) to avoid duplicates
  Set<String> _existingNames = {};

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Collapsed categories
  final Set<String> _collapsedCats = {};

  // Per-item overrides (priceMin, priceMax, commission, unit)
  final Map<String, Map<String, dynamic>> _overrides = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = currentUid;
      if (uid == null) throw Exception('Not authenticated');

      // Fetch templates (read-only for the app)
      final tmplDocs = rowsToDocs(
        'material_templates',
        await supabase.from('material_templates').select(),
      );

      // Fetch already-existing junkshop materials
      final existingRows = await supabase
          .from('junkshop_materials')
          .select('name')
          .eq('junkshop_id', uid);

      _existingNames = existingRows
          .map((d) => ((d['name'] as String?) ?? '').toLowerCase().trim())
          .where((n) => n.isNotEmpty)
          .toSet();

      // Group templates by category
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final data in tmplDocs) {
        final name = ((data['name'] as String?) ?? '').toLowerCase().trim();
        if (_existingNames.contains(name)) continue; // already imported

        final category = ((data['category'] as String?) ?? 'others')
            .toLowerCase();
        grouped.putIfAbsent(category, () => []).add({
          ...data,
          '_templateId': data['id'].toString(),
        });
      }

      // Sort categories alphabetically; put "others" last
      final cats = grouped.keys.toList()
        ..sort((a, b) {
          if (a == 'others') return 1;
          if (b == 'others') return -1;
          return a.compareTo(b);
        });

      setState(() {
        _grouped = grouped;
        _categoryOrder = cats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Selection helpers ──────────────────────────────────────────────────────

  List<String> _allTemplateIds() => _grouped.values
      .expand((list) => list)
      .map((m) => m['_templateId'] as String)
      .toList();

  List<String> _customIds() =>
      _customMaterials.map((m) => m['_id'] as String).toList();

  void _toggleSelectAll(bool? val) {
    final all = val == true;
    setState(() {
      if (all) {
        _selectedIds
          ..addAll(_allTemplateIds())
          ..addAll(_customIds());
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleCategory(String category, bool? val) {
    final ids = (_grouped[category] ?? [])
        .map((m) => m['_templateId'] as String)
        .toList();
    setState(() {
      if (val == true) {
        _selectedIds.addAll(ids);
      } else {
        _selectedIds.removeAll(ids);
      }
    });
  }

  bool _isCategorySelected(String category) {
    final ids = (_grouped[category] ?? [])
        .map((m) => m['_templateId'] as String)
        .toSet();
    return ids.isNotEmpty && ids.every((id) => _selectedIds.contains(id));
  }

  bool _isCategoryIndeterminate(String category) {
    final ids = (_grouped[category] ?? [])
        .map((m) => m['_templateId'] as String)
        .toSet();
    if (ids.isEmpty) return false;
    final selected = ids.where(_selectedIds.contains).length;
    return selected > 0 && selected < ids.length;
  }

  void _toggleItem(String id, bool? val) {
    setState(() {
      if (val == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  int get _totalSelected => _selectedIds.length;

  // ── Custom materials ───────────────────────────────────────────────────────

  void _showAddCustomDialog() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    String? nameError;

    final availableCats = _categoryOrder.toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add Custom Material',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Material name',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g., Copper Wire',
                  errorText: nameError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Category',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: catCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: availableCats.isNotEmpty
                      ? 'e.g., ${_capitalize(availableCats.first)}'
                      : 'e.g., Metals',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Custom materials may not be detected by AI.',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.orange.shade700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.junkshopPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  setDlg(() => nameError = 'Name is required');
                  return;
                }
                final category = catCtrl.text.trim().isEmpty
                    ? 'others'
                    : catCtrl.text.trim().toLowerCase();
                final id = _uuid.v4();
                setState(() {
                  _customMaterials.add({
                    'name': name,
                    'category': category,
                    'priceMin': 0.0,
                    'priceMax': 0.0,
                    'unit': 'kg',
                    'commission': 0.0,
                    'isCustom': true,
                    '_id': id,
                  });
                  _selectedIds.add(id);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeCustom(String id) {
    setState(() {
      _customMaterials.removeWhere((m) => m['_id'] == id);
      _selectedIds.remove(id);
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _importSelected() async {
    if (_totalSelected == 0) return;

    setState(() => _isSaving = true);
    try {
      final uid = currentUid;
      if (uid == null) throw Exception('Not authenticated');

      final newRows = <Map<String, dynamic>>[];
      Map<String, dynamic> toRow(Map<String, dynamic> doc) {
        final clean = Map<String, dynamic>.from(doc)
          ..remove('id')
          ..remove('isCustom')
          ..remove('createdAt')
          ..remove('updatedAt');
        return {
          ...docToRow('junkshop_materials', clean, forUpdate: false),
          'junkshop_id': uid,
        };
      }

      // Import selected template materials
      for (final cat in _categoryOrder) {
        for (final m in (_grouped[cat] ?? [])) {
          final id = m['_templateId'] as String;
          if (!_selectedIds.contains(id)) continue;
          final templateData = Map<String, dynamic>.from(m)
            ..remove('_templateId');
          final override = _overrides[id] ?? {};
          newRows.add(toRow({...templateData, ...override}));
        }
      }

      // Import selected custom materials
      for (final m in _customMaterials) {
        final id = m['_id'] as String;
        if (!_selectedIds.contains(id)) continue;
        final customData = Map<String, dynamic>.from(m)..remove('_id');
        newRows.add(toRow(customData));
      }

      if (newRows.isNotEmpty) {
        await supabase.from('junkshop_materials').insert(newRows);
      }

      if (mounted) {
        Navigator.pop(context, true); // return true = reload needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Materials',
              style: AppTextStyles.h6.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            if (!_isLoading && _error == null)
              Text(
                '$_totalSelected selected',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.junkshopPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: const [],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.junkshopPrimary,
              ),
            )
          : _error != null
          ? _buildError()
          : _grouped.isEmpty && _customMaterials.isEmpty
          ? _buildAllImported()
          : _buildBody(),
      bottomNavigationBar: (!_isLoading && _error == null)
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.errorColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load templates',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.junkshopPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllImported() {
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
                color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 40,
                color: AppColors.junkshopPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All templates imported',
              style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ve already imported all available templates.\nUse "Custom" to add a material not in the list.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _showAddCustomDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Custom Material'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.junkshopPrimary,
                side: const BorderSide(color: AppColors.junkshopPrimary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final query = _searchQuery.toLowerCase().trim();

    // Filter items by search query
    final filteredGrouped = <String, List<Map<String, dynamic>>>{};
    for (final cat in _categoryOrder) {
      final items = (_grouped[cat] ?? []).where((m) {
        if (query.isEmpty) return true;
        final name = ((m['name'] as String?) ?? '').toLowerCase();
        return name.contains(query) || cat.contains(query);
      }).toList();
      if (items.isNotEmpty) filteredGrouped[cat] = items;
    }
    final filteredCats = _categoryOrder
        .where((c) => filteredGrouped.containsKey(c))
        .toList();
    final filteredCustom = query.isEmpty
        ? _customMaterials
        : _customMaterials.where((m) {
            final name = ((m['name'] as String?) ?? '').toLowerCase();
            return name.contains(query);
          }).toList();
    final hasResults = filteredCats.isNotEmpty || filteredCustom.isNotEmpty;

    final allIds = {..._allTemplateIds(), ..._customIds()};
    final selectAllValue =
        allIds.isNotEmpty && allIds.every((id) => _selectedIds.contains(id));
    final isIndeterminate = _selectedIds.isNotEmpty && !selectAllValue;

    return CustomScrollView(
      slivers: [
        // ── Search bar ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search materials...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        }),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.junkshopPrimary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Select All (hidden while searching) ──
        if (query.isEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  _TriStateCheckbox(
                    value: selectAllValue,
                    isIndeterminate: isIndeterminate,
                    onChanged: _toggleSelectAll,
                    activeColor: AppColors.junkshopPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Select All',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_selectedIds.length} / ${allIds.length} selected',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.junkshopPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ── No results ──
        if (!hasResults && query.isNotEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 52,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No materials found',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try a different search term.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // ── Template categories ──
          for (final category in filteredCats)
            if ((filteredGrouped[category] ?? []).isNotEmpty) ...[
              _buildCategoryHeader(category),
              _buildCategoryItems(
                category,
                filteredGrouped[category]!,
                collapsed: _collapsedCats.contains(category) && query.isEmpty,
              ),
            ],

          // ── Custom materials ──
          if (filteredCustom.isNotEmpty) ...[
            _buildCustomHeader(),
            _buildCustomItems(filteredCustom),
          ],
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildCategoryHeader(String category) {
    final isSel = _isCategorySelected(category);
    final isIndet = _isCategoryIndeterminate(category);
    final isCollapsed = _collapsedCats.contains(category);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: isCollapsed ? const Radius.circular(10) : Radius.zero,
            bottomRight: isCollapsed ? const Radius.circular(10) : Radius.zero,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            if (_collapsedCats.contains(category)) {
              _collapsedCats.remove(category);
            } else {
              _collapsedCats.add(category);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleCategory(category, !isSel),
                  child: _TriStateCheckbox(
                    value: isSel,
                    isIndeterminate: isIndet,
                    onChanged: (v) => _toggleCategory(category, v),
                    activeColor: AppColors.junkshopPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _capitalize(category),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3730A3),
                    ),
                  ),
                ),
                Text(
                  '${(_grouped[category] ?? []).length} items',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF6366F1),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isCollapsed
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 20,
                  color: const Color(0xFF6366F1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItems(
    String category,
    List<Map<String, dynamic>> items, {
    bool collapsed = false,
  }) {
    if (collapsed) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _buildTemplateItem(items[i]),
              if (i < items.length - 1)
                Divider(height: 1, indent: 48, color: AppColors.borderLight),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateItem(Map<String, dynamic> material) {
    final id = material['_templateId'] as String;
    final isSelected = _selectedIds.contains(id);
    final override = _overrides[id] ?? {};
    final unit =
        (override['unit'] as String?) ?? (material['unit'] as String?) ?? 'kg';
    final min =
        ((override['priceMin'] ?? material['priceMin']) as num?)?.toDouble() ??
        0.0;
    final max =
        ((override['priceMax'] ?? material['priceMax']) as num?)?.toDouble() ??
        0.0;
    final hasPriceRange = min > 0 || max > 0;
    final isEdited = _overrides.containsKey(id);

    return InkWell(
      onTap: () => _toggleItem(id, !isSelected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (v) => _toggleItem(id, v),
              activeColor: AppColors.junkshopPrimary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (material['name'] as String?) ?? '',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isEdited)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.junkshopPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'edited',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.junkshopPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (hasPriceRange) ...[
                    const SizedBox(height: 1),
                    Text(
                      '₱${min.toStringAsFixed(0)} – ₱${max.toStringAsFixed(0)} / $unit',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: () => _showEditSheet(material, id),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        decoration: const BoxDecoration(
          color: Color(0xFFFFF7ED),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Text(
                'Custom Materials',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade800,
                ),
              ),
              const Spacer(),
              Text(
                '${_customMaterials.length} added',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.orange.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomItems(List<Map<String, dynamic>> items) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _buildCustomItem(items[i]),
              if (i < items.length - 1)
                Divider(height: 1, indent: 48, color: AppColors.borderLight),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditSheet(Map<String, dynamic> m, String id) {
    final override = _overrides[id] ?? {};
    final minCtrl = TextEditingController(
      text:
          ((override['priceMin'] ?? m['priceMin']) as num?)?.toStringAsFixed(
            0,
          ) ??
          '0',
    );
    final maxCtrl = TextEditingController(
      text:
          ((override['priceMax'] ?? m['priceMax']) as num?)?.toStringAsFixed(
            0,
          ) ??
          '0',
    );
    final commissionCtrl = TextEditingController(
      text:
          ((override['commission'] ?? m['commission']) as num?)
              ?.toStringAsFixed(0) ??
          '0',
    );
    String unit =
        (override['unit'] as String?) ?? (m['unit'] as String?) ?? 'kg';
    const units = ['kg', 'piece', 'case', 'unit'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Before Import',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _capitalize((m['name'] as String?) ?? ''),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _capitalize((m['category'] as String?) ?? ''),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Price range (₱ per unit)'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _dec('Min'),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                '–',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: maxCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _dec('Max'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _label('Commission (₱)'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: commissionCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _dec('e.g., 5'),
                        ),
                        const SizedBox(height: 16),
                        _label('Unit'),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: unit,
                              isExpanded: true,
                              items: units
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setSheet(() => unit = v);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.junkshopPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              setState(() {
                                _overrides[id] = {
                                  'priceMin':
                                      double.tryParse(minCtrl.text) ?? 0.0,
                                  'priceMax':
                                      double.tryParse(maxCtrl.text) ?? 0.0,
                                  'commission':
                                      double.tryParse(commissionCtrl.text) ??
                                      0.0,
                                  'unit': unit,
                                };
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );

  static InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: AppColors.junkshopPrimary,
        width: 1.5,
      ),
    ),
  );

  Widget _buildCustomItem(Map<String, dynamic> m) {
    final id = m['_id'] as String;
    final isSelected = _selectedIds.contains(id);

    return InkWell(
      onTap: () => _toggleItem(id, !isSelected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (v) => _toggleItem(id, v),
              activeColor: AppColors.junkshopPrimary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        (m['name'] as String?) ?? '',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _capitalize((m['category'] as String?) ?? 'others'),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
              onPressed: () => _removeCustom(id),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasSelection = _totalSelected > 0;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: hasSelection && !_isSaving ? _importSelected : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.junkshopPrimary,
            disabledBackgroundColor: AppColors.junkshopPrimary.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  hasSelection
                      ? 'Import $_totalSelected Material${_totalSelected != 1 ? 's' : ''}'
                      : 'Select materials to import',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

/// A checkbox that supports indeterminate state.
class _TriStateCheckbox extends StatelessWidget {
  final bool value;
  final bool isIndeterminate;
  final ValueChanged<bool?> onChanged;
  final Color activeColor;

  const _TriStateCheckbox({
    required this.value,
    required this.isIndeterminate,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Checkbox(
        value: isIndeterminate ? null : value,
        tristate: true,
        onChanged: (v) {
          // Tri-state cycles: null/false → true, true → false
          if (v == null || v == false) {
            onChanged(isIndeterminate ? true : false);
          } else {
            onChanged(true);
          }
        },
        activeColor: activeColor,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
