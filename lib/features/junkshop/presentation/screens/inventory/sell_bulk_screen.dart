import 'package:flutter/material.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';

class SellBulkScreen extends StatefulWidget {
  final List<Map<String, dynamic>> materials;
  final void Function(List<Map<String, dynamic>> lines) onConfirm;

  const SellBulkScreen({
    super.key,
    required this.materials,
    required this.onConfirm,
  });

  @override
  State<SellBulkScreen> createState() => _SellBulkScreenState();
}

class _SellBulkScreenState extends State<SellBulkScreen> {
  final TextEditingController buyerController = TextEditingController();
  final FocusNode _buyerFocusNode = FocusNode();
  List<String> _allBuyerNames = [];
  List<String> _filteredSuggestions = [];
  bool _showSuggestions = false;
  final Map<String, double> qty = {};
  final Map<String, TextEditingController> qtyControllers = {};
  final Map<String, double> sellPrice = {};
  final Map<String, TextEditingController> priceControllers = {};
  final List<String> lineIds = [];

  @override
  void initState() {
    super.initState();
    _loadPastBuyers();
    buyerController.addListener(_onBuyerTextChanged);
    _buyerFocusNode.addListener(() {
      if (!_buyerFocusNode.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    buyerController.removeListener(_onBuyerTextChanged);
    buyerController.dispose();
    _buyerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPastBuyers() async {
    final uid = currentUid;
    if (uid == null) return;
    try {
      final rows = await supabase
          .from('sales')
          .select('buyer')
          .eq('junkshop_id', uid)
          .order('created_at', ascending: false)
          .limit(500);
      final names = <String>{};
      for (final row in rows) {
        final buyer = row['buyer'];
        if (buyer is String && buyer.trim().isNotEmpty) {
          names.add(buyer.trim());
        }
      }
      if (mounted) setState(() => _allBuyerNames = names.toList());
    } catch (_) {}
  }

  void _onBuyerTextChanged() {
    final query = buyerController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    final filtered = _allBuyerNames
        .where((n) => n.toLowerCase().contains(query))
        .toList();
    setState(() {
      _filteredSuggestions = filtered;
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  static final _currencyFormat = NumberFormat('#,##0.00');
  String _fmt(double v) => _currencyFormat.format(v);

  double _basePrice(Map<String, dynamic> m) => (m['price'] as double? ?? 0.0);
  double _cost(Map<String, dynamic> m) =>
      (m['cost'] as double?) ?? _basePrice(m);

  double get totalSale {
    double t = 0.0;
    for (final id in lineIds) {
      final m = widget.materials.firstWhere((e) => e['id'] == id);
      final qVal = qty[id] ?? 0.0;
      final pVal = sellPrice[id] ?? _basePrice(m);
      if (qVal > 0) t += qVal * pVal;
    }
    return t;
  }

  bool get hasValidSelection {
    if (buyerController.text.trim().isEmpty) return false;
    for (final id in lineIds) {
      final m = widget.materials.firstWhere((e) => e['id'] == id);
      final qVal = qty[id] ?? 0.0;
      if (qVal > 0 && qVal <= (m['stock'] as double)) return true;
    }
    return false;
  }

  void _showAddItemPicker() {
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerCtx) => StatefulBuilder(
        builder: (pickerCtx, setPickerState) {
          final candidates = widget.materials.where((m) {
            final already = lineIds.contains(m['id']);
            final name = (m['name'] as String).toLowerCase();
            final matches =
                search.isEmpty || name.contains(search.toLowerCase());
            final hasStock = (m['stock'] as double) > 0;
            return !already && matches && hasStock;
          }).toList();

          return Padding(
            padding: MediaQuery.of(pickerCtx).viewInsets,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(pickerCtx).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add Material',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(pickerCtx),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'X',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        onChanged: (v) => setPickerState(() => search = v),
                        decoration: const InputDecoration(
                          hintText: 'Search materials...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Color(0xFF9CA3AF),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (candidates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No materials available',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        itemCount: candidates.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (ctx2, i) {
                          final m = candidates[i];
                          return InkWell(
                            onTap: () {
                              Navigator.pop(pickerCtx);
                              setState(() {
                                final id = m['id'].toString();
                                lineIds.add(id);
                                qty[id] = 0.0;
                                final base = _basePrice(m);
                                qtyControllers[id] = TextEditingController();
                                priceControllers[id] = TextEditingController(
                                  text: base.toStringAsFixed(2),
                                );
                                sellPrice[id] = base;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m['name'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${(m['stock'] as double).toStringAsFixed(1)} ${m['unit']} available  x  P${_fmt(m['price'] as double)}/${m['unit']}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      size: 16,
                                      color: AppColors.primaryGreen,
                                    ),
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveSale(
    List<Map<String, dynamic>> lines,
    double total,
  ) async {
    try {
      final uid = currentUid;
      if (uid == null) return;

      final items = lines.map((l) {
        return {
          'materialId': l['id'],
          'name': l['name'],
          'quantity': l['qty'],
          'unit': l['unit'],
          'pricePerUnit': l['price'],
          'subtotal': l['subtotal'],
        };
      }).toList();

      final sale = await supabase
          .from('sales')
          .insert({
            'junkshop_id': uid,
            'items': items,
            'total_amount': total,
            'buyer': buyerController.text.trim().isEmpty
                ? null
                : buyerController.text.trim(),
            'status': 'completed',
            'type': 'bulk_sale',
            'created_by': uid,
          })
          .select('id')
          .single();

      final buyer = buyerController.text.trim();
      String title;
      if (items.length == 1) {
        final item = items.first;
        title =
            'Sale of ${item['name']} (P${item['subtotal'].toStringAsFixed(2)}) (${item['quantity']} ${item['unit']})${buyer.isNotEmpty ? ' to $buyer' : ''}';
      } else {
        final firstItem = items.first;
        final remainingCount = items.length - 1;
        title =
            'Sale of ${firstItem['name']} (P${firstItem['subtotal'].toStringAsFixed(2)}) (${firstItem['quantity']} ${firstItem['unit']}) + $remainingCount more${buyer.isNotEmpty ? ' to $buyer' : ''}';
      }

      final itemsSummary = items
          .map(
            (item) => '${item['name']} (${item['quantity']} ${item['unit']})',
          )
          .join(', ');

      await supabase.from('activity_logs').insert({
        'junkshop_id': uid,
        'type': 'sale',
        'title': title,
        'details': {
          'saleId': sale['id'],
          'totalAmount': total,
          'itemsCount': items.length,
          'buyer': buyer.isEmpty ? null : buyer,
          'items': itemsSummary,
        },
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save sale record: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  void _showSummary() {
    final List<Map<String, dynamic>> lines = [];
    for (final id in lineIds) {
      final m = widget.materials.firstWhere((e) => e['id'] == id);
      final qVal = qty[id] ?? 0.0;
      if (qVal > 0) {
        final price = sellPrice[id] ?? _basePrice(m);
        lines.add({
          'id': id,
          'name': m['name'],
          'unit': m['unit'],
          'qty': qVal,
          'price': price,
          'subtotal': price * qVal,
        });
      }
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please add at least one item with a valid quantity.',
          ),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    final total = lines.fold<double>(
      0,
      (s, l) => s + (l['subtotal'] as double),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sale Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            buyerController.text.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'X',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx2, i) {
                    final l = lines[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l['name'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${(l['qty'] as double).toStringAsFixed(2)} ${l['unit']}  x  P${_fmt(l['price'] as double)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'P${_fmt(l['subtotal'] as double)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          Text(
                            'P${_fmt(total)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final navCtx = Navigator.of(ctx);
                              final navOuter = Navigator.of(context);
                              await _saveSale(lines, total);
                              widget.onConfirm(lines);
                              navCtx.pop();
                              navOuter.pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Confirm Sale',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffix,
    required void Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          prefixText: prefix,
          suffixText: suffix,
          prefixStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
          suffixStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'New Sale',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Buyer field with autocomplete suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: buyerController,
                      focusNode: _buyerFocusNode,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                      onTap: () {
                        if (buyerController.text.trim().isNotEmpty &&
                            _filteredSuggestions.isNotEmpty) {
                          setState(() => _showSuggestions = true);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Buyer name',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 10),
                          child: Text(
                            'To',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  if (_showSuggestions)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: _filteredSuggestions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (context, index) {
                          final name = _filteredSuggestions[index];
                          return InkWell(
                            onTap: () {
                              buyerController.text = name;
                              buyerController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: buyerController.text.length,
                                    ),
                                  );
                              setState(() => _showSuggestions = false);
                              _buyerFocusNode.unfocus();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
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
              const SizedBox(height: 20),
              // Items header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showAddItemPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Add item',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Empty state
              if (lineIds.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 24,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No items yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Add item" to get started',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              // Line items
              ...lineIds.map((id) {
                final material = widget.materials.firstWhere(
                  (e) => e['id'] == id,
                );
                final unit = material['unit'] as String;
                final stock = material['stock'] as double;
                final base = _basePrice(material);
                final cost = _cost(material);
                qtyControllers.putIfAbsent(id, () => TextEditingController());
                priceControllers.putIfAbsent(
                  id,
                  () => TextEditingController(text: base.toStringAsFixed(2)),
                );
                final lineQty = qty[id] ?? 0.0;
                final linePrice = sellPrice[id] ?? base;
                final lineSubtotal = (lineQty > 0) ? lineQty * linePrice : 0.0;
                final lineProfit = (linePrice - cost) * lineQty;
                final isProfit = lineProfit >= 0;
                final profitColor = lineProfit < 0
                    ? AppColors.errorColor
                    : (lineProfit > 0
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    material['name'],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${stock.toStringAsFixed(1)} $unit in stock',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  lineIds.remove(id);
                                  qty.remove(id);
                                  sellPrice.remove(id);
                                  qtyControllers.remove(id);
                                  priceControllers.remove(id);
                                });
                              },
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.grey.shade400,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 16,
                        thickness: 1,
                        color: Colors.grey.shade100,
                        indent: 14,
                        endIndent: 14,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    controller: priceControllers[id]!,
                                    label: 'Price / $unit',
                                    prefix: 'P',
                                    onChanged: (v) {
                                      final parsed = double.tryParse(v) ?? 0.0;
                                      setState(() => sellPrice[id] = parsed);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildInputField(
                                    controller: qtyControllers[id]!,
                                    label: 'Quantity',
                                    suffix: unit,
                                    onChanged: (v) {
                                      final parsed = double.tryParse(v) ?? 0.0;
                                      final clamped = parsed.clamp(0.0, stock);
                                      setState(() => qty[id] = clamped);
                                      if (parsed > stock) {
                                        final corrected = stock.toStringAsFixed(
                                          2,
                                        );
                                        qtyControllers[id]!
                                            .value = TextEditingValue(
                                          text: corrected,
                                          selection: TextSelection.collapsed(
                                            offset: corrected.length,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: profitColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${isProfit ? 'Profit' : 'Loss'}: P${_fmt(lineProfit.abs())}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: profitColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          qty[id] = stock;
                                          qtyControllers[id]!.text = stock
                                              .toStringAsFixed(2);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGreen
                                              .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Max',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryGreen,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'P${_fmt(lineSubtotal)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              if (lineIds.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        'P${_fmt(totalSale)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: hasValidSelection ? _showSummary : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Review & Confirm',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
