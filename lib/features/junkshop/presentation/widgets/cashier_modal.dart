import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/widgets/common/common_widgets.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class CashierModal extends StatefulWidget {
  const CashierModal({super.key});

  @override
  State<CashierModal> createState() => _CashierModalState();
}

class _CashierModalState extends State<CashierModal> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _customerNameController = TextEditingController();
  final List<Map<String, dynamic>> _wasteItems = [];
  List<Map<String, dynamic>> _materials = [];
  List<String> _categories = ['All'];
  bool _loadingMaterials = true;
  List<String> _previousCustomers = [];
  List<String> _filteredCustomers = [];

  final List<String> _availableUnits = [
    'kg',
    'pcs',
    'piece',
    'lbs',
    'ton',
    'bundle',
  ];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    _loadPreviousCustomers();
  }

  Future<void> _loadPreviousCustomers() async {
    try {
      final uid = currentUid;
      if (uid == null) return;

      final rows = await supabase
          .from('purchases')
          .select('customer_name')
          .eq('junkshop_id', uid)
          .eq('type', 'manual_onsite')
          .order('created_at', ascending: false)
          .limit(100);

      final customersSet = <String>{};
      for (final row in rows) {
        final customerName = row['customer_name'] as String?;
        if (customerName != null && customerName.isNotEmpty) {
          customersSet.add(customerName);
        }
      }

      if (mounted) {
        setState(() {
          _previousCustomers = customersSet.toList()..sort();
        });
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading previous customers: $e');
    }
  }

  void _filterCustomers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = [];
      });
      return;
    }

    final filtered = _previousCustomers
        .where((name) => name.toLowerCase().contains(query.toLowerCase()))
        .take(5)
        .toList();

    setState(() {
      _filteredCustomers = filtered;
    });
  }

  Future<void> _loadMaterials() async {
    if (kDebugMode) print('🔄 Loading materials...');
    try {
      final uid = currentUid;
      if (kDebugMode) print('👤 Current user: $uid');

      if (uid == null) {
        if (kDebugMode) print('❌ No authenticated user');
        setState(() {
          _loadingMaterials = false;
        });
        return;
      }

      final snapshot = rowsToDocs(
        'junkshop_materials',
        await supabase
            .from('junkshop_materials')
            .select()
            .eq('junkshop_id', uid),
      );

      final materials = <Map<String, dynamic>>[];
      final categoriesSet = <String>{'All'};

      for (final data in snapshot) {
        materials.add({
          'id': data['id'],
          'name': data['name'] ?? '',
          'price': (data['priceMax'] as num?)?.toDouble() ?? 0.0,
          'priceMin': (data['priceMin'] as num?)?.toDouble() ?? 0.0,
          'priceMax': (data['priceMax'] as num?)?.toDouble() ?? 0.0,
          'unit': data['unit'] ?? 'kg',
          'category': data['category'] ?? 'others',
          'stock': (data['stock'] as num?)?.toDouble() ?? 0.0,
        });

        final category = data['category'] ?? 'others';
        categoriesSet.add(category);
      }

      if (kDebugMode) {
        print(
          '✅ Materials loaded: ${materials.length} items, ${categoriesSet.length} categories',
        );
      }

      if (mounted) {
        setState(() {
          _materials = materials;
          _categories = categoriesSet.toList()..sort();
          _loadingMaterials = false;
        });
        if (kDebugMode) print('✅ State updated successfully');
      } else {
        if (kDebugMode) print('⚠️ Widget not mounted, skipping state update');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print('❌ Error loading materials: $e');
      if (kDebugMode) print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _loadingMaterials = false;
        });
      }
    }
  }

  double get _totalAmount {
    return _wasteItems.fold(
      0.0,
      (acc, item) => acc + (item['price'] * item['quantity']),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.junkshopPrimary, AppColors.junkshopSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textWhite.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              const Icon(
                Icons.shopping_cart_checkout,
                color: AppColors.textWhite,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Onsite Purchase',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textWhite),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer name (required)
            Text(
              'Customer Name',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _customerNameController,
                  onChanged: _filterCustomers,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter customer name';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter customer name',
                    prefixIcon: const Icon(Icons.person_outline),
                    suffixIcon: _customerNameController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _customerNameController.clear();
                              _filterCustomers('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.junkshopPrimary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                ),
                if (_filteredCustomers.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredCustomers.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.history,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          title: Text(
                            customer,
                            style: AppTextStyles.bodyMedium,
                          ),
                          onTap: () {
                            _customerNameController.text = customer;
                            setState(() {
                              _filteredCustomers = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Waste Items Section
            _buildWasteItemsSection(),

            const SizedBox(height: 20),

            // Total Amount
            _buildTotalSection(),

            const SizedBox(height: 20),

            // Notes
            _buildNotesSection(),

            const SizedBox(height: 20),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // Collector selection removed for onsite manual payout

  Widget _buildWasteItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Waste Items',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _loadingMaterials ? null : _showAddItemModal,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: _loadingMaterials
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.junkshopPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_wasteItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.textSecondary,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _loadingMaterials
                      ? 'Loading materials...'
                      : 'No items added yet',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingMaterials)
                  const CircularProgressIndicator(
                    color: AppColors.junkshopPrimary,
                  )
                else
                  Text(
                    _materials.isEmpty
                        ? 'No materials configured. Please add materials in settings first.'
                        : 'Tap "Add Item" to start adding waste materials',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          )
        else
          Column(
            children: _wasteItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildWasteItemCard(item, index);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildWasteItemCard(Map<String, dynamic> item, int index) {
    final totalValue = (item['price'] as double) * (item['quantity'] as double);

    return CustomCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['quantity']} ${item['unit']} × ₱${(item['price'] as double).toStringAsFixed(2)} • Total: ₱${totalValue.toStringAsFixed(2)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditItemModal(index),
            color: AppColors.junkshopPrimary,
            iconSize: 20,
            tooltip: 'Edit item',
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeItem(index),
            color: AppColors.errorColor,
            iconSize: 20,
            tooltip: 'Remove item',
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    // Display total payout without a surrounding card for a cleaner look
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'TOTAL VALUE',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            '₱${_totalAmount.toStringAsFixed(2)}',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any additional notes...',
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
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.textSecondary),
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _wasteItems.isNotEmpty ? _processPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.junkshopPrimary,
                  foregroundColor: AppColors.textWhite,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Confirm Purchase'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _showAddItemModal() {
    String? selectedCategory;
    String? selectedMaterial;
    String? selectedUnit;
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final materialSearchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          // Filter materials by selected category and search text
          var filteredMaterials =
              selectedCategory == null || selectedCategory == 'All'
              ? _materials
              : _materials
                    .where((m) => m['category'] == selectedCategory)
                    .toList();

          // Apply search filter
          final searchText = materialSearchController.text.toLowerCase();
          if (searchText.isNotEmpty) {
            filteredMaterials = filteredMaterials
                .where(
                  (m) =>
                      m['name'].toString().toLowerCase().contains(searchText),
                )
                .toList();
          }

          // Get available units, including the selected material's unit if not in list
          final availableUnits = <String>[..._availableUnits];
          if (selectedUnit != null && !availableUnits.contains(selectedUnit)) {
            availableUnits.add(selectedUnit!);
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Add Waste Item',
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category dropdown
                  Text(
                    'Category',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    hint: const Text('Select category'),
                    isExpanded: true,
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          category.toUpperCase(),
                          style: AppTextStyles.bodyMedium,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedCategory = value;
                        selectedMaterial =
                            null; // Reset material when category changes
                        priceController.clear();
                        selectedUnit = null;
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.junkshopPrimary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Material name with integrated search
                  Text(
                    'Material Name',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Custom searchable dropdown
                  GestureDetector(
                    onTap: filteredMaterials.isEmpty
                        ? null
                        : () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (searchContext) => StatefulBuilder(
                                builder: (context, setSearchState) {
                                  // Filter materials inside the search modal for real-time updates
                                  var searchFilteredMaterials =
                                      filteredMaterials;
                                  final searchText = materialSearchController
                                      .text
                                      .toLowerCase();
                                  if (searchText.isNotEmpty) {
                                    searchFilteredMaterials = filteredMaterials
                                        .where(
                                          (m) => m['name']
                                              .toString()
                                              .toLowerCase()
                                              .contains(searchText),
                                        )
                                        .toList();
                                  }

                                  return Container(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.7,
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        // Header
                                        Text(
                                          'Select Material',
                                          style: AppTextStyles.h4.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Search bar
                                        TextField(
                                          controller: materialSearchController,
                                          autofocus: true,
                                          onChanged: (value) {
                                            setSearchState(() {});
                                          },
                                          decoration: InputDecoration(
                                            hintText: 'Search material...',
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              color: Color(0xFF6B7280),
                                              size: 20,
                                            ),
                                            suffixIcon:
                                                materialSearchController
                                                    .text
                                                    .isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear,
                                                      color: Color(0xFF6B7280),
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      setSearchState(() {
                                                        materialSearchController
                                                            .clear();
                                                      });
                                                    },
                                                  )
                                                : null,
                                            filled: true,
                                            fillColor: const Color(0xFFF3F4F6),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color:
                                                    AppColors.junkshopPrimary,
                                                width: 2,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Results count
                                        if (searchFilteredMaterials.isNotEmpty)
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '${searchFilteredMaterials.length} material${searchFilteredMaterials.length != 1 ? 's' : ''} found',
                                              style: AppTextStyles.bodySmall
                                                  .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        // Material list
                                        Expanded(
                                          child: searchFilteredMaterials.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    'No materials found',
                                                    style: AppTextStyles
                                                        .bodyMedium
                                                        .copyWith(
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                  ),
                                                )
                                              : ListView.builder(
                                                  itemCount:
                                                      searchFilteredMaterials
                                                          .length,
                                                  itemBuilder: (context, index) {
                                                    final material =
                                                        searchFilteredMaterials[index];
                                                    final priceMin =
                                                        material['priceMin'] ??
                                                        0.0;
                                                    final priceMax =
                                                        material['priceMax'] ??
                                                        0.0;
                                                    final priceDisplay =
                                                        priceMin == priceMax
                                                        ? '₱${priceMax.toStringAsFixed(2)}'
                                                        : '₱${priceMin.toStringAsFixed(2)}-${priceMax.toStringAsFixed(2)}';
                                                    final isSelected =
                                                        selectedMaterial ==
                                                        material['id'];

                                                    return InkWell(
                                                      onTap: () {
                                                        setModalState(() {
                                                          selectedMaterial =
                                                              material['id'];
                                                          priceController.text =
                                                              material['priceMin']
                                                                  .toString();
                                                          selectedUnit =
                                                              material['unit']
                                                                  .toString();
                                                          materialSearchController
                                                              .clear();
                                                        });
                                                        Navigator.pop(
                                                          searchContext,
                                                        );
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isSelected
                                                              ? AppColors
                                                                    .junkshopPrimary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    )
                                                              : AppColors
                                                                    .backgroundDark,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? AppColors
                                                                      .junkshopPrimary
                                                                : AppColors
                                                                      .borderLight,
                                                            width: isSelected
                                                                ? 2
                                                                : 1,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    material['name'],
                                                                    style: AppTextStyles.bodyMedium.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color:
                                                                          isSelected
                                                                          ? AppColors.junkshopPrimary
                                                                          : AppColors.textPrimary,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 4,
                                                                  ),
                                                                  Text(
                                                                    '$priceDisplay/${material['unit']}',
                                                                    style: AppTextStyles
                                                                        .bodySmall
                                                                        .copyWith(
                                                                          color:
                                                                              AppColors.textSecondary,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            if (isSelected)
                                                              const Icon(
                                                                Icons
                                                                    .check_circle,
                                                                color: AppColors
                                                                    .junkshopPrimary,
                                                                size: 24,
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: filteredMaterials.isEmpty
                            ? AppColors.borderLight.withValues(alpha: 0.3)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: filteredMaterials.isEmpty
                              ? AppColors.borderLight.withValues(alpha: 0.5)
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedMaterial != null
                                  ? () {
                                      final material = _materials.firstWhere(
                                        (m) => m['id'] == selectedMaterial,
                                      );
                                      final priceMin =
                                          material['priceMin'] ?? 0.0;
                                      final priceMax =
                                          material['priceMax'] ?? 0.0;
                                      final priceDisplay = priceMin == priceMax
                                          ? '₱${priceMax.toStringAsFixed(2)}'
                                          : '₱${priceMin.toStringAsFixed(2)}-${priceMax.toStringAsFixed(2)}';
                                      return '${material['name']} - $priceDisplay/${material['unit']}';
                                    }()
                                  : selectedCategory == null
                                  ? 'Select material'
                                  : filteredMaterials.isEmpty
                                  ? 'No materials in this category'
                                  : 'Tap to search and select material',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: selectedMaterial != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: filteredMaterials.isEmpty
                                ? AppColors.textSecondary.withValues(alpha: 0.5)
                                : AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quantity and Price per Unit in one row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantity',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (value) {
                                setModalState(
                                  () {},
                                ); // Trigger rebuild to update total
                              },
                              decoration: InputDecoration(
                                hintText: selectedUnit != null
                                    ? 'Enter amount'
                                    : 'Select material',
                                suffixText: selectedUnit ?? '',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.junkshopPrimary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price per Unit',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (value) {
                                setModalState(
                                  () {},
                                ); // Trigger rebuild to update total
                              },
                              decoration: InputDecoration(
                                hintText: 'Enter price',
                                prefixText: '₱',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.junkshopPrimary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (selectedMaterial != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      () {
                        final material = _materials.firstWhere(
                          (m) => m['id'] == selectedMaterial,
                        );
                        final priceMin = material['priceMin'] ?? 0.0;
                        final priceMax = material['priceMax'] ?? 0.0;
                        final priceDisplay = priceMin == priceMax
                            ? '₱${priceMax.toStringAsFixed(2)}'
                            : '₱${priceMin.toStringAsFixed(2)}-${priceMax.toStringAsFixed(2)}';
                        return 'Original price: $priceDisplay/${material['unit']}';
                      }(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Total Value display (without box)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Value:',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        () {
                          final quantity =
                              double.tryParse(quantityController.text) ?? 0.0;
                          final price =
                              double.tryParse(priceController.text) ?? 0.0;
                          final total = quantity * price;
                          return total > 0
                              ? '₱${total.toStringAsFixed(2)}'
                              : '₱0.00';
                        }(),
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.junkshopPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.textSecondary,
                            ),
                            foregroundColor: AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedMaterial != null &&
                                quantityController.text.isNotEmpty) {
                              final material = _materials.firstWhere(
                                (m) => m['id'] == selectedMaterial,
                              );
                              final quantity =
                                  double.tryParse(quantityController.text) ??
                                  0.0;
                              final price =
                                  double.tryParse(priceController.text) ??
                                  (material['price'] as double);
                              final unit = selectedUnit ?? material['unit'];

                              if (quantity > 0) {
                                setState(() {
                                  _wasteItems.add({
                                    'id': material['id'],
                                    'name': material['name'],
                                    'price': price,
                                    'quantity': quantity,
                                    'unit': unit,
                                    'category': material['category'],
                                    'originalPrice': material['priceMax'],
                                    'originalPriceMin': material['priceMin'],
                                    'originalPriceMax': material['priceMax'],
                                  });
                                });
                                Navigator.pop(context);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.junkshopPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Add Item'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditItemModal(int index) {
    final item = Map<String, dynamic>.from(_wasteItems[index]);
    final quantityController = TextEditingController(
      text: item['quantity'].toString(),
    );
    final priceController = TextEditingController(
      text: item['price'].toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Edit Item',
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Material name (read-only)
                  Text(
                    'Material',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      item['name'],
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quantity and Price per Unit in one row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantity',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (value) {
                                setModalState(
                                  () {},
                                ); // Trigger rebuild to update total
                              },
                              decoration: InputDecoration(
                                hintText: 'Enter amount',
                                suffixText: item['unit'],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.junkshopPrimary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price per Unit',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (value) {
                                setModalState(
                                  () {},
                                ); // Trigger rebuild to update total
                              },
                              decoration: InputDecoration(
                                hintText: 'Enter price',
                                prefixText: '₱',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.junkshopPrimary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (item['originalPrice'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      () {
                        final priceMin =
                            item['originalPriceMin'] ?? item['originalPrice'];
                        final priceMax =
                            item['originalPriceMax'] ?? item['originalPrice'];
                        final priceDisplay = priceMin == priceMax
                            ? '₱${priceMax.toStringAsFixed(2)}'
                            : '₱${priceMin.toStringAsFixed(2)}-${priceMax.toStringAsFixed(2)}';
                        return 'Original price: $priceDisplay/${item['unit']}';
                      }(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Total Value display (without box)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Value:',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        () {
                          final quantity =
                              double.tryParse(quantityController.text) ?? 0.0;
                          final price =
                              double.tryParse(priceController.text) ?? 0.0;
                          final total = quantity * price;
                          return total > 0
                              ? '₱${total.toStringAsFixed(2)}'
                              : '₱0.00';
                        }(),
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.junkshopPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.textSecondary,
                            ),
                            foregroundColor: AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final newQuantity =
                                double.tryParse(quantityController.text) ?? 0.0;
                            final newPrice =
                                double.tryParse(priceController.text) ??
                                (item['price'] as double);
                            if (newQuantity > 0) {
                              setState(() {
                                _wasteItems[index] = {
                                  ...item,
                                  'quantity': newQuantity,
                                  'price': newPrice,
                                };
                              });
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.junkshopPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _wasteItems.removeAt(index);
    });
  }

  void _processPayment() async {
    if (_formKey.currentState!.validate() && _wasteItems.isNotEmpty) {
      final uid = currentUid;
      if (uid == null) return;

      // The junkshop row must exist (it is created at registration)
      final junkshopRow = await supabase
          .from('junkshops')
          .select('id')
          .eq('id', uid)
          .maybeSingle();
      if (junkshopRow == null) {
        if (mounted) {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Missing junkshop record'),
              content: const Text(
                'No junkshop profile found. Please complete junkshop registration.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.junkshopPrimary),
        ),
      );

      try {
        // We'll gather items with material details and update stock
        final List<Map<String, dynamic>> purchasedItems = [];

        for (final item in _wasteItems) {
          final materialId = item['id'];
          final quantity = item['quantity'] as double;
          final pricePerKg = item['price'] as double;
          final subtotal = quantity * pricePerKg;

          // Fetch the material row to update its stock
          final materialRow = await supabase
              .from('junkshop_materials')
              .select()
              .eq('id', materialId)
              .eq('junkshop_id', uid)
              .maybeSingle();

          if (materialRow != null) {
            final currentStock = (materialRow['stock'] as num?)?.toDouble() ?? 0.0;
            final currentTotalCost =
                (materialRow['total_purchase_cost'] as num?)?.toDouble() ?? 0.0;

            final newStock = currentStock + quantity;
            final newTotalCost = currentTotalCost + subtotal;
            final newAvgCost = newStock > 0 ? newTotalCost / newStock : 0.0;

            await supabase
                .from('junkshop_materials')
                .update({
                  'stock': newStock,
                  'total_purchase_cost': newTotalCost,
                  'avg_purchase_cost': newAvgCost,
                })
                .eq('id', materialId);
          }

          // Add item to purchasedItems (only essential transaction data)
          purchasedItems.add({
            'materialId': item['id'],
            'name': item['name'],
            'quantity': item['quantity'],
            'unit': item['unit'],
            'price': item['price'],
            'subtotal': subtotal,
          });
        }

        final purchase = await supabase
            .from('purchases')
            .insert({
              'junkshop_id': uid,
              'items': purchasedItems,
              'total_amount': _totalAmount,
              'notes': _notesController.text.trim(),
              'customer_name': _customerNameController.text.trim(),
              'status': 'completed',
              'type': 'manual_onsite',
              'created_by': uid,
            })
            .select('id')
            .single();

        // Log activity
        await supabase.from('activity_logs').insert({
          'junkshop_id': uid,
          'type': 'purchase',
          'title':
              'Onsite purchase ₱${_totalAmount.toStringAsFixed(2)} from ${_customerNameController.text.trim()}',
          'details': {
            'purchaseId': purchase['id'],
            'totalAmount': _totalAmount,
            'itemsCount': _wasteItems.length,
            'customerName': _customerNameController.text.trim(),
          },
        });

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Show success dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.successColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Payout Confirmed',
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Value: ₱${_totalAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.junkshopPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Items: ${_wasteItems.length}'),
                  const SizedBox(height: 8),
                  Text('Stock updated successfully'),
                  if (_notesController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notes: ${_notesController.text}'),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close cashier modal
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: AppColors.junkshopPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Show error dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.errorColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text('Error'),
                ],
              ),
              content: Text('Failed to process payout. Please try again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }
}
