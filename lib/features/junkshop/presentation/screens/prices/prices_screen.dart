import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../shared/widgets/common/common_widgets.dart';
import 'material_template_import_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class PricesScreen extends StatefulWidget {
  const PricesScreen({super.key});

  @override
  State<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends State<PricesScreen> {

  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSortOrder = 'Name (A-Z)';

  final List<String> _units = ['kg', 'piece', 'case', 'unit'];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';

  // Pagination
  static const int _itemsPerPage = 10;
  int _currentPage = 0;

  // Inline template import state (shown when no materials exist)
  final _uuid = const Uuid();
  Map<String, List<Map<String, dynamic>>> _templateGrouped = {};
  List<String> _templateCategoryOrder = [];
  final Set<String> _selectedTemplateIds = {};
  final List<Map<String, dynamic>> _customImportMaterials = [];
  bool _isLoadingTemplates = false;
  bool _isSavingImport = false;
  String _importSearchQuery = '';
  final TextEditingController _importSearchController = TextEditingController();
  // Tracks which category headers are collapsed
  final Set<String> _collapsedImportCats = {};
  // Per-item overrides applied before import (keyed by templateId or custom _id)
  final Map<String, Map<String, dynamic>> _importOverrides = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _resetPagination();
      });
    });
    _loadMaterials();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _importSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = currentUid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // Load materials from junkshop's materials
      final docs = rowsToDocs(
        'junkshop_materials',
        await supabase
            .from('junkshop_materials')
            .select()
            .eq('junkshop_id', uid)
            .order('category')
            .order('name'),
      );

      // A material is "custom" when it does not come from a template
      final templateNames = (await supabase
              .from('material_templates')
              .select('name'))
          .map((r) => ((r['name'] as String?) ?? '').toLowerCase().trim())
          .toSet();

      setState(() {
        _materials = docs.map((data) {
          return {
            'id': data['id'],
            'name': data['name'] ?? '',
            'priceMin': (data['priceMin'] as num?)?.toDouble() ?? 0.0,
            'priceMax': (data['priceMax'] as num?)?.toDouble() ?? 0.0,
            'price':
                (data['priceMax'] as num?)?.toDouble() ??
                0.0, // Use max price as display price
            'unit': data['unit'] ?? 'kg',
            'category': data['category'] ?? 'others',
            'commission': (data['commission'] as num?)?.toDouble() ?? 0.0,
            'householdPriceMin':
                (data['householdPriceMin'] as num?)?.toDouble() ?? 0.0,
            'householdPriceMax':
                (data['householdPriceMax'] as num?)?.toDouble() ?? 0.0,
            'isCustom': !templateNames.contains(
              ((data['name'] as String?) ?? '').toLowerCase().trim(),
            ),
          };
        }).toList();

        // Extract unique categories from loaded materials
        final uniqueCategories =
            _materials
                .map((m) => (m['category'] as String).toLowerCase())
                .toSet()
                .toList()
              ..sort();
        _categories = ['All', ...uniqueCategories];

        _isLoading = false;
      });

      // Auto-load templates if no materials yet
      if (_materials.isEmpty) {
        _loadTemplates();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      if (kDebugMode) print('Error loading materials: $e');
    }
  }

  Future<void> _navigateToImport() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MaterialTemplateImportScreen()),
    );
    if (result == true && mounted) {
      await _loadMaterials();
    }
  }

  // ── Inline template import ─────────────────────────────────────────────────

  Future<void> _loadTemplates() async {
    setState(() => _isLoadingTemplates = true);
    try {
      if (currentUid == null) return;

      final tmplDocs = rowsToDocs(
        'material_templates',
        await supabase.from('material_templates').select(),
      );

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final data in tmplDocs) {
        final category = ((data['category'] as String?) ?? 'others')
            .toLowerCase();
        grouped.putIfAbsent(category, () => []).add({
          ...data,
          '_templateId': data['id'].toString(),
        });
      }

      final cats = grouped.keys.toList()
        ..sort((a, b) {
          if (a == 'others') return 1;
          if (b == 'others') return -1;
          return a.compareTo(b);
        });

      if (mounted) {
        setState(() {
          _templateGrouped = grouped;
          _templateCategoryOrder = cats;
          _isLoadingTemplates = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTemplates = false);
    }
  }

  List<String> _allTemplateIds() => _templateGrouped.values
      .expand((list) => list)
      .map((m) => m['_templateId'] as String)
      .toList();

  List<String> _customImportIds() =>
      _customImportMaterials.map((m) => m['_id'] as String).toList();

  bool _isTmplCategorySelected(String cat) {
    final ids = (_templateGrouped[cat] ?? [])
        .map((m) => m['_templateId'] as String)
        .toSet();
    return ids.isNotEmpty && ids.every(_selectedTemplateIds.contains);
  }

  bool _isTmplCategoryIndeterminate(String cat) {
    final ids = (_templateGrouped[cat] ?? [])
        .map((m) => m['_templateId'] as String)
        .toSet();
    if (ids.isEmpty) return false;
    final sel = ids.where(_selectedTemplateIds.contains).length;
    return sel > 0 && sel < ids.length;
  }

  void _toggleTmplSelectAll(bool? val) {
    setState(() {
      if (val == true) {
        _selectedTemplateIds
          ..addAll(_allTemplateIds())
          ..addAll(_customImportIds());
      } else {
        _selectedTemplateIds.clear();
      }
    });
  }

  void _toggleTmplCategory(String cat, bool? val) {
    final ids = (_templateGrouped[cat] ?? [])
        .map((m) => m['_templateId'] as String)
        .toList();
    setState(() {
      if (val == true) {
        _selectedTemplateIds.addAll(ids);
      } else {
        _selectedTemplateIds.removeAll(ids);
      }
    });
  }

  void _toggleTmplItem(String id, bool? val) {
    setState(() {
      if (val == true) {
        _selectedTemplateIds.add(id);
      } else {
        _selectedTemplateIds.remove(id);
      }
    });
  }

  void _removeCustomImport(String id) {
    setState(() {
      _customImportMaterials.removeWhere((m) => m['_id'] == id);
      _selectedTemplateIds.remove(id);
    });
  }

  void _showAddCustomForImport() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '0');
    final maxCtrl = TextEditingController(text: '0');
    final commissionCtrl = TextEditingController(text: '0');
    String unit = 'kg';
    const units = ['kg', 'piece', 'case', 'unit'];
    String? nameError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            expand: false,
            builder: (ctx, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // ── Drag handle ──
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.junkshopPrimary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_box_rounded,
                            color: AppColors.junkshopPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Custom Material',
                                style: AppTextStyles.h6.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Define a material not in the templates.',
                                style: AppTextStyles.caption.copyWith(
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

                  const SizedBox(height: 8),
                  Divider(height: 1, color: AppColors.borderLight),

                  // ── Scrollable form ──
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      children: [
                        // Material name
                        _sheetLabel('Material name *'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _sheetInputDec(
                            'e.g., Copper Wire',
                          ).copyWith(errorText: nameError),
                          onChanged: (_) {
                            if (nameError != null) {
                              setSheet(() => nameError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Category
                        _sheetLabel('Category'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: catCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _sheetInputDec(
                            _templateCategoryOrder.isNotEmpty
                                ? 'e.g., ${_cap(_templateCategoryOrder.first)}'
                                : 'e.g., Metals',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Price range
                        _sheetLabel('Price range (₱ per unit)'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _sheetInputDec('Min'),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                '–',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: maxCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _sheetInputDec('Max'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Commission
                        _sheetLabel('Commission (₱)'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: commissionCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _sheetInputDec('e.g., 5'),
                        ),
                        const SizedBox(height: 16),

                        // Unit — dropdown
                        _sheetLabel('Unit'),
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
                        const SizedBox(height: 12),

                        // AI note
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Custom materials may not be detected by AI scanning.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // ── Action button ──
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      12 + MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.junkshopPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'Add Material',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            setSheet(() => nameError = 'Required');
                            return;
                          }
                          final cat = catCtrl.text.trim().isEmpty
                              ? 'others'
                              : catCtrl.text.trim().toLowerCase();
                          final id = _uuid.v4();
                          setState(() {
                            _customImportMaterials.add({
                              'name': name,
                              'category': cat,
                              'priceMin': double.tryParse(minCtrl.text) ?? 0.0,
                              'priceMax': double.tryParse(maxCtrl.text) ?? 0.0,
                              'commission':
                                  double.tryParse(commissionCtrl.text) ?? 0.0,
                              'unit': unit,
                              'isCustom': true,
                              '_id': id,
                            });
                            _selectedTemplateIds.add(id);
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _doImportSelected() async {
    if (_selectedTemplateIds.isEmpty) return;
    setState(() => _isSavingImport = true);
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

      // Template materials
      for (final cat in _templateCategoryOrder) {
        for (final m in (_templateGrouped[cat] ?? [])) {
          final id = m['_templateId'] as String;
          if (!_selectedTemplateIds.contains(id)) continue;
          final data = Map<String, dynamic>.from(m)
            ..remove('_templateId')
            ..addAll(_importOverrides[id] ?? {});
          newRows.add(toRow(data));
        }
      }

      // Custom materials
      for (final m in _customImportMaterials) {
        final id = m['_id'] as String;
        if (!_selectedTemplateIds.contains(id)) continue;
        final data = Map<String, dynamic>.from(m)..remove('_id');
        newRows.add(toRow(data));
      }

      if (newRows.isNotEmpty) {
        await supabase.from('junkshop_materials').insert(newRows);
      }
      _selectedTemplateIds.clear();
      _customImportMaterials.clear();
      _importOverrides.clear();
      if (mounted) await _loadMaterials();
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
      if (mounted) setState(() => _isSavingImport = false);
    }
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  List<Map<String, dynamic>> get _filteredMaterials {
    var list = _materials;
    // Category filter
    if (_selectedCategory != 'All') {
      list = list.where((m) => m['category'] == _selectedCategory).toList();
    }
    // Name search filter
    final q = _searchQuery.trim();
    if (q.isNotEmpty) {
      list = list
          .where((m) => (m['name'] as String).toLowerCase().contains(q))
          .toList();
    }
    // Sorting (Name or Price)
    switch (_selectedSortOrder) {
      case 'Name (A-Z)':
        list.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
        break;
      case 'Name (Z-A)':
        list.sort(
          (a, b) => (b['name'] as String).compareTo(a['name'] as String),
        );
        break;
      case 'Price (High-Low)':
        list.sort(
          (a, b) => (b['price'] as double).compareTo(a['price'] as double),
        );
        break;
      case 'Price (Low-High)':
        list.sort(
          (a, b) => (a['price'] as double).compareTo(b['price'] as double),
        );
        break;
    }
    return list;
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
    final isImportMode =
        !_isLoading && _errorMessage == null && _materials.isEmpty;
    final totalSelected = _selectedTemplateIds.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        surfaceTintColor: AppColors.backgroundLight,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
        ),
        title: isImportMode
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Materials',
                    style: AppTextStyles.h5.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (totalSelected > 0)
                    Text(
                      '$totalSelected selected',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.junkshopPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              )
            : Text(
                'Price Management',
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
        actions: isImportMode
            ? [
                TextButton.icon(
                  onPressed: _showAddCustomForImport,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Custom'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.junkshopPrimary,
                  ),
                ),
              ]
            : [
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textPrimary,
                  ),
                  onSelected: (value) {
                    if (value == 'add') _addNewMaterial();
                    if (value == 'import') _navigateToImport();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'add',
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline_rounded,
                            size: 20,
                            color: Color(0xFF374151),
                          ),
                          SizedBox(width: 12),
                          Text('Add Material'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(
                            Icons.download_outlined,
                            size: 20,
                            color: Color(0xFF374151),
                          ),
                          SizedBox(width: 12),
                          Text('Import Material'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
      ),
      bottomNavigationBar: isImportMode
          ? Container(
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
                height: 50,
                child: FilledButton(
                  onPressed: totalSelected > 0 && !_isSavingImport
                      ? _doImportSelected
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.junkshopPrimary,
                    disabledBackgroundColor: AppColors.junkshopPrimary
                        .withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSavingImport
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          totalSelected > 0
                              ? 'Import $totalSelected Material${totalSelected != 1 ? 's' : ''}'
                              : 'Select materials to import',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            )
          : null,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.junkshopPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading Material Prices',
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Setting up your pricing list...',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text('Error loading materials', style: AppTextStyles.h5),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(text: 'Retry', onPressed: _loadMaterials),
                ],
              ),
            )
          : _materials.isEmpty
          ? _buildInlineImportView()
          : Column(
              children: [
                // Filters row (Category + Sort) – Inventory style, no stock filter
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Category dropdown
                        SizedBox(
                          width: 160,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderLight),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCategory,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                ),
                                style: AppTextStyles.bodySmall,
                                items: _categories
                                    .map(
                                      (category) => DropdownMenuItem(
                                        value: category,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.category,
                                              size: 16,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(category),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCategory = value;
                                      _resetPagination();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sort dropdown (Name/Price)
                        SizedBox(
                          width: 160,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderLight),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSortOrder,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                ),
                                style: AppTextStyles.bodySmall,
                                items:
                                    [
                                          'Name (A-Z)',
                                          'Name (Z-A)',
                                          'Price (High-Low)',
                                          'Price (Low-High)',
                                        ]
                                        .map(
                                          (sort) => DropdownMenuItem(
                                            value: sort,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  sort.startsWith('Name')
                                                      ? Icons.sort_by_alpha
                                                      : Icons.attach_money,
                                                  size: 16,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    sort,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedSortOrder = value;
                                      _resetPagination();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search bar (styled like Inbox)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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

                // Materials list
                Expanded(
                  child: ListView.builder(
                    itemCount: _currentPageMaterials.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _currentPageMaterials.length) {
                        return _buildPaginationControls();
                      }

                      final material = _currentPageMaterials[index];
                      return Column(
                        children: [
                          InkWell(
                            onTap: () => _editMaterial(material),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  // Material details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                material['name'] ?? 'Unknown',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            if (material['isCustom'] ==
                                                true) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.orange.shade400,
                                                      Colors
                                                          .deepOrange
                                                          .shade500,
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      size: 10,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'Custom',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.white,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          material['category'] ?? 'others',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        if (material['isCustom'] == true) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                size: 11,
                                                color: Colors.orange.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'AI may not detect this material',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                        color: Colors
                                                            .orange
                                                            .shade700,
                                                        fontSize: 10,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (material['description'] != null &&
                                            (material['description'] as String)
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            material['description'],
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: const Color(
                                                    0xFF6B7280,
                                                  ),
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                          ),
                                        ],
                                        if (((material['commission'] as num?)
                                                    ?.toDouble() ??
                                                0.0) >
                                            0) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Commission: ${AppFormatters.currency((material['commission'] as num?)?.toDouble() ?? 0.0)}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: const Color(
                                                    0xFF10B981,
                                                  ),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Price display
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${AppFormatters.currency((material['priceMin'] as num?)?.toDouble() ?? 0.0)}-${AppFormatters.currency((material['priceMax'] as num?)?.toDouble() ?? 0.0)}',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.junkshopPrimary,
                                            ),
                                      ),
                                      Text(
                                        'per ${material['unit'] ?? ''}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
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
    );
  }

  // ── Redesigned inline import view ──────────────────────────────────────────

  Widget _buildInlineImportView() {
    if (_isLoadingTemplates) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.junkshopPrimary),
            const SizedBox(height: 16),
            Text(
              'Loading materials...',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Filter logic
    final query = _importSearchQuery.toLowerCase().trim();
    final Map<String, List<Map<String, dynamic>>> filteredGrouped;
    final List<String> filteredCatOrder;
    final List<Map<String, dynamic>> filteredCustom;

    if (query.isEmpty) {
      filteredGrouped = _templateGrouped;
      filteredCatOrder = _templateCategoryOrder;
      filteredCustom = _customImportMaterials;
    } else {
      filteredGrouped = {};
      for (final cat in _templateCategoryOrder) {
        final catMatches = cat.toLowerCase().contains(query);
        final items = catMatches
            ? (_templateGrouped[cat] ?? [])
            : (_templateGrouped[cat] ?? []).where((m) {
                final override = _importOverrides[m['_templateId'] as String];
                final name =
                    ((override?['name'] as String?) ??
                            (m['name'] as String?) ??
                            '')
                        .toLowerCase();
                return name.contains(query);
              }).toList();
        if (items.isNotEmpty) filteredGrouped[cat] = items;
      }
      filteredCatOrder = filteredGrouped.keys.toList();
      filteredCustom = _customImportMaterials.where((m) {
        final override = _importOverrides[m['_id'] as String];
        final name =
            ((override?['name'] as String?) ?? (m['name'] as String?) ?? '')
                .toLowerCase();
        return name.contains(query);
      }).toList();
    }

    final allIds = {..._allTemplateIds(), ..._customImportIds()};
    final selectAllValue =
        allIds.isNotEmpty && allIds.every(_selectedTemplateIds.contains);
    final isIndeterminate = _selectedTemplateIds.isNotEmpty && !selectAllValue;
    final totalVisible =
        filteredGrouped.values.fold(0, (s, l) => s + l.length) +
        filteredCustom.length;
    final hasResults = totalVisible > 0;

    return CustomScrollView(
      slivers: [
        // ── Header banner ──
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Up Materials',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select materials your junkshop accepts. '
                        'Tap the edit icon to adjust prices before import.',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Search bar ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              controller: _importSearchController,
              onChanged: (v) => setState(() => _importSearchQuery = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search materials or categories...',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _importSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          _importSearchController.clear();
                          setState(() => _importSearchQuery = '');
                        },
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.borderLight,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.borderLight,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.junkshopPrimary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Select All pill (hidden while searching) ──
        if (query.isEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _toggleTmplSelectAll(!selectAllValue),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _InlineTriCheckbox(
                          value: selectAllValue,
                          isIndeterminate: isIndeterminate,
                          onChanged: _toggleTmplSelectAll,
                        ),
                        const SizedBox(width: 8),
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
                            color: AppColors.junkshopPrimary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedTemplateIds.length} / ${allIds.length} selected',
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
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

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
          // ── Template category cards ──
          for (final cat in filteredCatOrder)
            if ((filteredGrouped[cat] ?? []).isNotEmpty)
              SliverToBoxAdapter(
                child: _ImportCategoryCard(
                  category: cat,
                  items: filteredGrouped[cat]!,
                  isCollapsed:
                      _collapsedImportCats.contains(cat) && query.isEmpty,
                  isCategorySelected: _isTmplCategorySelected(cat),
                  isCategoryIndeterminate: _isTmplCategoryIndeterminate(cat),
                  selectedIds: _selectedTemplateIds,
                  overrides: _importOverrides,
                  onToggleCollapse: () => setState(() {
                    if (_collapsedImportCats.contains(cat)) {
                      _collapsedImportCats.remove(cat);
                    } else {
                      _collapsedImportCats.add(cat);
                    }
                  }),
                  onToggleCategory: (v) => _toggleTmplCategory(cat, v),
                  onToggleItem: _toggleTmplItem,
                  onEdit: _showEditBeforeImport,
                  cap: _cap,
                ),
              ),

          // ── Custom materials card ──
          if (filteredCustom.isNotEmpty)
            SliverToBoxAdapter(
              child: _ImportCustomCard(
                items: filteredCustom,
                isCollapsed:
                    _collapsedImportCats.contains('__custom__') &&
                    query.isEmpty,
                selectedIds: _selectedTemplateIds,
                overrides: _importOverrides,
                onToggleCollapse: () => setState(() {
                  if (_collapsedImportCats.contains('__custom__')) {
                    _collapsedImportCats.remove('__custom__');
                  } else {
                    _collapsedImportCats.add('__custom__');
                  }
                }),
                onToggleItem: _toggleTmplItem,
                onEdit: _showEditBeforeImport,
                onRemove: _removeCustomImport,
                cap: _cap,
              ),
            ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  /// Opens a bottom sheet to edit price/commission/unit before importing.
  void _showEditBeforeImport(Map<String, dynamic> m, String id) {
    final override = _importOverrides[id] ?? {};
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
                // Handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title row
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
                              style: AppTextStyles.h6.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _cap(m['name'] as String? ?? ''),
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _cap(m['category'] as String? ?? ''),
                              style: AppTextStyles.bodySmall.copyWith(
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price range
                        _sheetLabel('Price range (₱ per unit)'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _sheetInputDec('Min'),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                '–',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: maxCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _sheetInputDec('Max'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Commission
                        _sheetLabel('Commission (₱)'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: commissionCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _sheetInputDec('e.g., 5'),
                        ),
                        const SizedBox(height: 16),

                        // Unit
                        _sheetLabel('Unit'),
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

                        // Save button
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
                                _importOverrides[id] = {
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

  static Widget _sheetLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );

  static InputDecoration _sheetInputDec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.borderLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: AppColors.junkshopPrimary,
        width: 1.5,
      ),
    ),
  );

  void _editMaterial(Map<String, dynamic> material) {
    final priceMinController = TextEditingController(
      text: (material['priceMin'] ?? 0.0).toString(),
    );
    final priceMaxController = TextEditingController(
      text: (material['priceMax'] ?? 0.0).toString(),
    );
    final commissionController = TextEditingController(
      text: (material['commission'] ?? 0.0).toString(),
    );
    final descriptionController = TextEditingController(
      text: material['description'] ?? '',
    );
    String selectedUnit = (material['unit'] as String?) ?? 'kg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          // Avoid an overly tall sheet; allow content to define height up to max
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                                material['name'] ?? 'Edit Material',
                                style: AppTextStyles.h6.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                material['category'] ?? 'others',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete material',
                          onPressed: () async {
                            final deleted = await _deleteMaterial(material);
                            if (deleted && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.delete),
                          color: AppColors.errorColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Form
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Price Min and Max in one row
                    Text(
                      'Price Range',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Min',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: priceMinController,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  prefixText: '₱',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Max',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: priceMaxController,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  prefixText: '₱',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Unit
                    Text(
                      'Unit',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedUnit,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: _units.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedUnit = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Commission field (peso-based)
                    Text(
                      'Collector Commission (₱)',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Commission amount deducted from the price shown to households',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commissionController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: '₱',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Material Guidelines/Requirements
                    Text(
                      'Guidelines (Optional)',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requirements or conditions for this material (e.g., "Must be clean and dry", "No cracks or chips")',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'e.g., Must be clean, no cracks, sorted by color...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),

                    // Small spacing before action buttons
                    const SizedBox(height: 70),

                    // Action buttons: Cancel + Save Changes
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              foregroundColor: AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.buttonRadius,
                                ),
                              ),
                              fixedSize: Size.fromHeight(
                                AppDimensions.buttonHeightLarge,
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            text: 'Save Changes',
                            onPressed: () async {
                              // Update material in Firebase
                              try {
                                final uid = currentUid;
                                if (uid == null) {
                                  throw Exception('Not authenticated');
                                }

                                final commission =
                                    double.tryParse(
                                      commissionController.text,
                                    ) ??
                                    0.0;
                                final priceMin =
                                    double.tryParse(priceMinController.text) ??
                                    0.0;
                                final priceMax =
                                    double.tryParse(priceMaxController.text) ??
                                    0.0;

                                final updatedMaterial = {
                                  'name': material['name'],
                                  'priceMin': priceMin,
                                  'priceMax': priceMax,
                                  'unit': selectedUnit,
                                  'category': material['category'],
                                  'commission': commission,
                                  'householdPriceMin': priceMin - commission,
                                  'householdPriceMax': priceMax - commission,
                                  'description': descriptionController.text
                                      .trim(),
                                };

                                await supabase
                                    .from('junkshop_materials')
                                    .update(
                                      docToRow(
                                        'junkshop_materials',
                                        updatedMaterial,
                                      ),
                                    )
                                    .eq('id', material['id']);

                                // Log activity
                                final oldMin =
                                    material['priceMin'] as num? ?? 0;
                                final oldMax =
                                    material['priceMax'] as num? ?? 0;
                                final priceChanged =
                                    oldMin != priceMin || oldMax != priceMax;

                                if (priceChanged) {
                                  await supabase.from('activity_logs').insert({
                                        'junkshop_id': uid,
                                        'type': 'price_update',
                                        'title':
                                            'Updated ${material['name']} price from ₱${oldMin.toStringAsFixed(0)}-₱${oldMax.toStringAsFixed(0)} to ₱${priceMin.toStringAsFixed(0)}-₱${priceMax.toStringAsFixed(0)}/$selectedUnit',
                                        'details': {
                                          'materialId': material['id'],
                                          'materialName': material['name'],
                                          'oldPriceMin': oldMin,
                                          'oldPriceMax': oldMax,
                                          'newPriceMin': priceMin,
                                          'newPriceMax': priceMax,
                                          'unit': selectedUnit,
                                        },
                                      });
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '✅ Material updated successfully',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }

                                // Reload materials
                                if (context.mounted) {
                                  await _loadMaterials();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '❌ Material update failed. Please try again.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            backgroundColor: AppColors.junkshopPrimary,
                            borderRadius: AppDimensions.buttonRadius,
                            height: AppDimensions.buttonHeightLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewMaterial() {
    final nameController = TextEditingController();
    final priceMinController = TextEditingController();
    final priceMaxController = TextEditingController();
    final commissionController = TextEditingController(text: '0');
    final descriptionController = TextEditingController();
    String selectedUnit = 'kg';
    String? nameError;

    final availableCategories =
        _categories.where((c) => c.toLowerCase() != 'all').toSet().toList()
          ..sort();
    String selectedCategory = availableCategories.isNotEmpty
        ? availableCategories.first.toLowerCase()
        : 'others';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // ── Drag handle ──
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.junkshopPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.junkshopPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Material',
                              style: AppTextStyles.h6.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Set name, pricing, and details.',
                              style: AppTextStyles.caption.copyWith(
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

                const SizedBox(height: 8),
                Divider(height: 1, color: AppColors.borderLight),

                // ── Scrollable form ──
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    children: [
                      // AI warning
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Custom materials may not be detected by AI scanning.',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Material name
                      _sheetLabel('Material name *'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _sheetInputDec(
                          'e.g., Plastic Bottles',
                        ).copyWith(errorText: nameError),
                        onChanged: (_) {
                          if (nameError != null) {
                            setSheet(() => nameError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category
                      _sheetLabel('Category'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.borderLight,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFF9FAFB),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            items: availableCategories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.toLowerCase(),
                                    child: Text(
                                      c[0].toUpperCase() + c.substring(1),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setSheet(() => selectedCategory = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Price range
                      _sheetLabel('Price range (₱ per unit)'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceMinController,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: _sheetInputDec('Min'),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '–',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: priceMaxController,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: _sheetInputDec('Max'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Unit
                      _sheetLabel('Unit'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.borderLight,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFF9FAFB),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedUnit,
                            isExpanded: true,
                            items: _units
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setSheet(() => selectedUnit = v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Commission
                      _sheetLabel('Commission (₱)'),
                      const SizedBox(height: 4),
                      Text(
                        'Deducted from the price shown to households.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: commissionController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _sheetInputDec('e.g., 5'),
                      ),
                      const SizedBox(height: 16),

                      // Guidelines
                      _sheetLabel('Guidelines (optional)'),
                      const SizedBox(height: 4),
                      Text(
                        'Requirements or conditions for this material.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: _sheetInputDec(
                          'e.g., Must be clean, no cracks...',
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),

                // ── Action button ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    12 + MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.junkshopPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Add Material',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          setSheet(() => nameError = 'Required');
                          return;
                        }
                        if (priceMinController.text.isEmpty ||
                            priceMaxController.text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter price range'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final uid = currentUid;
                          if (uid == null) {
                            throw Exception('Not authenticated');
                          }
                          final priceMin =
                              double.tryParse(priceMinController.text) ?? 0.0;
                          final priceMax =
                              double.tryParse(priceMaxController.text) ?? 0.0;
                          final commission =
                              double.tryParse(commissionController.text) ?? 0.0;
                          await supabase.from('junkshop_materials').insert({
                            'junkshop_id': uid,
                            'name': name,
                            'price_min': priceMin,
                            'price_max': priceMax,
                            'unit': selectedUnit,
                            'category': selectedCategory,
                            'commission': commission,
                            'household_price_min': priceMin - commission,
                            'household_price_max': priceMax - commission,
                            'description': descriptionController.text.trim(),
                            'is_active': true,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('$name added successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          await _loadMaterials();
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to add material. Please try again.',
                                ),
                                backgroundColor: AppColors.errorColor,
                              ),
                            );
                          }
                        }
                      },
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

  Future<bool> _deleteMaterial(Map<String, dynamic> material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text('Are you sure you want to delete "${material['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    if (currentUid == null) return false;

    await supabase
        .from('junkshop_materials')
        .delete()
        .eq('id', material['id'] as String);

    setState(() {
      _materials.removeWhere((m) => m['id'] == material['id']);
    });
    return true;
  }
}

// ── Import category card (collapsible) ──────────────────────────────────────

class _ImportCategoryCard extends StatelessWidget {
  const _ImportCategoryCard({
    required this.category,
    required this.items,
    required this.isCollapsed,
    required this.isCategorySelected,
    required this.isCategoryIndeterminate,
    required this.selectedIds,
    required this.overrides,
    required this.onToggleCollapse,
    required this.onToggleCategory,
    required this.onToggleItem,
    required this.onEdit,
    required this.cap,
  });

  final String category;
  final List<Map<String, dynamic>> items;
  final bool isCollapsed;
  final bool isCategorySelected;
  final bool isCategoryIndeterminate;
  final Set<String> selectedIds;
  final Map<String, Map<String, dynamic>> overrides;
  final VoidCallback onToggleCollapse;
  final ValueChanged<bool?> onToggleCategory;
  final void Function(String id, bool? val) onToggleItem;
  final void Function(Map<String, dynamic> m, String id) onEdit;
  final String Function(String) cap;

  @override
  Widget build(BuildContext context) {
    final selectedInCat = items
        .where((m) => selectedIds.contains(m['_templateId']))
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Category header row
            InkWell(
              onTap: onToggleCollapse,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    // Tri-state checkbox (selection only, does not collapse)
                    GestureDetector(
                      onTap: () => onToggleCategory(!isCategorySelected),
                      child: Checkbox(
                        value: isCategoryIndeterminate
                            ? null
                            : isCategorySelected,
                        tristate: true,
                        onChanged: onToggleCategory,
                        activeColor: AppColors.junkshopPrimary,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Category name
                    Expanded(
                      child: Text(
                        cap(category),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                    ),
                    // Selected count badge
                    if (selectedInCat > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.junkshopPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$selectedInCat/${items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${items.length}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    // Collapse arrow
                    AnimatedRotation(
                      turns: isCollapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Items (shown when not collapsed)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: isCollapsed
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        for (int i = 0; i < items.length; i++) ...[
                          _ImportTemplateRow(
                            m: items[i],
                            overrides: overrides,
                            selectedIds: selectedIds,
                            onToggle: onToggleItem,
                            onEdit: onEdit,
                          ),
                          if (i < items.length - 1)
                            const Divider(
                              height: 1,
                              indent: 56,
                              endIndent: 16,
                              color: Color(0xFFF1F5F9),
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

class _ImportTemplateRow extends StatelessWidget {
  const _ImportTemplateRow({
    required this.m,
    required this.overrides,
    required this.selectedIds,
    required this.onToggle,
    required this.onEdit,
  });

  final Map<String, dynamic> m;
  final Map<String, Map<String, dynamic>> overrides;
  final Set<String> selectedIds;
  final void Function(String id, bool? val) onToggle;
  final void Function(Map<String, dynamic> m, String id) onEdit;

  @override
  Widget build(BuildContext context) {
    final id = m['_templateId'] as String;
    final override = overrides[id];
    final isSelected = selectedIds.contains(id);
    final hasOverride = override != null;

    final name = (override?['name'] as String?) ?? (m['name'] as String?) ?? '';
    final unit =
        (override?['unit'] as String?) ?? (m['unit'] as String?) ?? 'kg';
    final min =
        ((override?['priceMin'] ?? m['priceMin']) as num?)?.toDouble() ?? 0.0;
    final max =
        ((override?['priceMax'] ?? m['priceMax']) as num?)?.toDouble() ?? 0.0;

    return InkWell(
      onTap: () => onToggle(id, !isSelected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (v) => onToggle(id, v),
              activeColor: AppColors.junkshopPrimary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13.5,
                            color: isSelected
                                ? const Color(0xFF1E1B4B)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (hasOverride) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'edited',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (min > 0 || max > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '₱${min.toStringAsFixed(0)} – ₱${max.toStringAsFixed(0)} / $unit',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Edit button
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onEdit(m, id),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: hasOverride
                        ? const Color(0xFF059669)
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Import custom materials card ─────────────────────────────────────────────

class _ImportCustomCard extends StatelessWidget {
  const _ImportCustomCard({
    required this.items,
    required this.isCollapsed,
    required this.selectedIds,
    required this.overrides,
    required this.onToggleCollapse,
    required this.onToggleItem,
    required this.onEdit,
    required this.onRemove,
    required this.cap,
  });

  final List<Map<String, dynamic>> items;
  final bool isCollapsed;
  final Set<String> selectedIds;
  final Map<String, Map<String, dynamic>> overrides;
  final VoidCallback onToggleCollapse;
  final void Function(String id, bool? val) onToggleItem;
  final void Function(Map<String, dynamic> m, String id) onEdit;
  final void Function(String id) onRemove;
  final String Function(String) cap;

  @override
  Widget build(BuildContext context) {
    final selectedCount = items
        .where((m) => selectedIds.contains(m['_id']))
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            InkWell(
              onTap: onToggleCollapse,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add_box_outlined,
                        size: 18,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Custom Materials',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                    if (selectedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$selectedCount/${items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${items.length}',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: isCollapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: Colors.orange.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: isCollapsed
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.orange.shade100,
                        ),
                        for (int i = 0; i < items.length; i++) ...[
                          _ImportCustomRow(
                            m: items[i],
                            overrides: overrides,
                            selectedIds: selectedIds,
                            onToggle: onToggleItem,
                            onEdit: onEdit,
                            onRemove: onRemove,
                            cap: cap,
                          ),
                          if (i < items.length - 1)
                            Divider(
                              height: 1,
                              indent: 56,
                              endIndent: 16,
                              color: Colors.orange.shade50,
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

class _ImportCustomRow extends StatelessWidget {
  const _ImportCustomRow({
    required this.m,
    required this.overrides,
    required this.selectedIds,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
    required this.cap,
  });

  final Map<String, dynamic> m;
  final Map<String, Map<String, dynamic>> overrides;
  final Set<String> selectedIds;
  final void Function(String id, bool? val) onToggle;
  final void Function(Map<String, dynamic> m, String id) onEdit;
  final void Function(String id) onRemove;
  final String Function(String) cap;

  @override
  Widget build(BuildContext context) {
    final id = m['_id'] as String;
    final override = overrides[id];
    final isSelected = selectedIds.contains(id);
    final name = (override?['name'] as String?) ?? (m['name'] as String?) ?? '';
    final catLabel = cap((m['category'] as String?) ?? 'others');

    return InkWell(
      onTap: () => onToggle(id, !isSelected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (v) => onToggle(id, v),
              activeColor: Colors.orange.shade700,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                      color: isSelected
                          ? const Color(0xFF7C2D12)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    catLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Edit
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onEdit(m, id),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: Colors.orange.shade300,
                  ),
                ),
              ),
            ),
            // Remove
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onRemove(id),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tri-state checkbox used in the inline import view.
class _InlineTriCheckbox extends StatelessWidget {
  const _InlineTriCheckbox({
    required this.value,
    required this.isIndeterminate,
    required this.onChanged,
  });

  final bool value;
  final bool isIndeterminate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: isIndeterminate ? null : value,
      tristate: true,
      onChanged: (v) {
        if (isIndeterminate) {
          onChanged(true);
        } else {
          onChanged(v ?? false);
        }
      },
      activeColor: AppColors.junkshopPrimary,
      visualDensity: VisualDensity.compact,
    );
  }
}
