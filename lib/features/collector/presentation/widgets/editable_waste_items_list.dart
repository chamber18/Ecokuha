import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

// Custom formatter to limit decimal places to 2
class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Allow only numbers and one decimal point
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text)) {
      return oldValue;
    }

    return newValue;
  }
}

class EditableWasteItemsList extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>>? originalItems;
  final void Function(List<Map<String, dynamic>> items) onChanged;
  final VoidCallback onPayPressed;
  final String? junkshopId;
  final double? distance;
  final double? baseFee;
  final double? distanceFee;
  const EditableWasteItemsList({
    super.key,
    required this.items,
    this.originalItems,
    required this.onChanged,
    required this.onPayPressed,
    this.junkshopId,
    this.distance,
    this.baseFee,
    this.distanceFee,
  });

  @override
  State<EditableWasteItemsList> createState() => _EditableWasteItemsListState();
}

class _EditableWasteItemsListState extends State<EditableWasteItemsList> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items.map((e) => Map<String, dynamic>.from(e)).toList();
    debugPrint(
      '[EditableWasteItemsList] initState - originalItems: ${widget.originalItems}',
    );
    debugPrint(
      '[EditableWasteItemsList] initState - originalItems is null: ${widget.originalItems == null}',
    );
    debugPrint(
      '[EditableWasteItemsList] initState - originalItems length: ${widget.originalItems?.length}',
    );
  }

  double get _total {
    return _items.fold(0.0, (acc, it) {
      // Price already includes the boost, so just sum it directly
      final price = (it['price'] ?? 0).toDouble();
      return acc + price;
    });
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (ctx) => _AddItemDialog(
        junkshopId: widget.junkshopId,
        onAdd: (newItem) {
          setState(() {
            _items.add(newItem);
          });
          widget.onChanged(_items);
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    widget.onChanged(_items);
  }

  void _updateItem(int index, String key, dynamic value) {
    setState(() {
      _items[index][key] = value;
    });
    widget.onChanged(_items);
  }

  void _reloadOriginalItems() {
    if (widget.originalItems == null) {
      debugPrint('[Reload] \u20B1 ï¸ originalItems is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No original items available to reload'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    debugPrint(
      '[Reload] Original items count: ${widget.originalItems!.length}',
    );
    debugPrint('[Reload] Original items: ${widget.originalItems}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reload Original Items?'),
        content: Text(
          'This will replace all current items (${_items.length}) with the original items (${widget.originalItems!.length}) from the household posting. Any changes you made will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _items = widget.originalItems!
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
              });
              debugPrint(
                '[Reload] âœ… Items reloaded, new count: ${_items.length}',
              );
              widget.onChanged(_items);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${_items.length} items reloaded from original posting',
                  ),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.collectorPrimary,
            ),
            child: const Text('Reload'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient background
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.collectorPrimary.withValues(alpha: 0.1),
                  AppColors.collectorPrimary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verify Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_items.length} item(s)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.collectorPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.collectorPrimary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: IconButton(
                        onPressed: _reloadOriginalItems,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        color: AppColors.collectorPrimary,
                        tooltip: 'Reload Original Items',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.collectorPrimary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: IconButton(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add, size: 20),
                        color: AppColors.collectorPrimary,
                        tooltip: 'Add Item',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items list
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No items added yet',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Column(
                children: List.generate(_items.length, (index) {
                  final item = _items[index];
                  return _EditableItemTile(
                    item: item,
                    onChanged: (key, val) => _updateItem(index, key, val),
                    onRemove: () => _removeItem(index),
                    isLast: index == _items.length - 1,
                    junkshopId: widget.junkshopId,
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditableItemTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final void Function(String key, dynamic value) onChanged;
  final VoidCallback onRemove;
  final bool isLast;
  final String? junkshopId;
  const _EditableItemTile({
    required this.item,
    required this.onChanged,
    required this.onRemove,
    required this.isLast,
    this.junkshopId,
  });

  @override
  State<_EditableItemTile> createState() => _EditableItemTileState();
}

class _EditableItemTileState extends State<_EditableItemTile> {
  late TextEditingController quantityController;
  late TextEditingController pricePerUnitController;
  late FocusNode quantityFocusNode;
  late FocusNode priceFocusNode;

  @override
  void initState() {
    super.initState();

    // Properly handle quantity conversion
    final quantity = (widget.item['quantity'] is num)
        ? (widget.item['quantity'] as num).toDouble()
        : (double.tryParse(widget.item['quantity']?.toString() ?? '0') ?? 0.0);

    // Use household's base price (priceMin or priceMax) for pricePerUnit
    // This is the base price WITHOUT the promotion boost
    double pricePerUnit = 0.0;

    final priceMax = (widget.item['priceMax'] is num)
        ? (widget.item['priceMax'] as num).toDouble()
        : 0.0;
    final priceMin = (widget.item['priceMin'] is num)
        ? (widget.item['priceMin'] as num).toDouble()
        : 0.0;

    if (priceMax > 0) {
      pricePerUnit = priceMax;
      debugPrint(
        '[EditableItem] Using household priceMax as base: $pricePerUnit',
      );
    } else if (priceMin > 0) {
      pricePerUnit = priceMin;
      debugPrint(
        '[EditableItem] Using household priceMin as base: $pricePerUnit',
      );
    } else {
      // Fallback: read from pricePerUnit field if base prices not available
      pricePerUnit = (widget.item['pricePerUnit'] is num)
          ? (widget.item['pricePerUnit'] as num).toDouble()
          : (double.tryParse(widget.item['pricePerUnit']?.toString() ?? '0') ??
                0.0);
      debugPrint(
        '[EditableItem] Using pricePerUnit field as fallback: $pricePerUnit',
      );
    }

    // Initialize controllers with clean values (no formatting)
    quantityController = TextEditingController(
      text: quantity > 0 ? quantity.toString() : '',
    );
    pricePerUnitController = TextEditingController(
      text: pricePerUnit > 0 ? pricePerUnit.toString() : '',
    );

    // Initialize focus nodes
    quantityFocusNode = FocusNode();
    priceFocusNode = FocusNode();

    // Select all text when field is tapped
    quantityFocusNode.addListener(() {
      if (quantityFocusNode.hasFocus) {
        quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: quantityController.text.length,
        );
      }
    });

    priceFocusNode.addListener(() {
      if (priceFocusNode.hasFocus) {
        pricePerUnitController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: pricePerUnitController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    quantityController.dispose();
    pricePerUnitController.dispose();
    quantityFocusNode.dispose();
    priceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.item['unit']?.toString() ?? 'kg';
    final category = widget.item['category']?.toString() ?? 'Mixed';
    final itemName = widget.item['type']?.toString() ?? 'Unknown Item';
    final isRejected = widget.item['isNotAcceptableByJunkshop'] == true;
    final categoryColor = _getCategoryColor(category);
    final hasPromo =
        widget.item['promotionBoostPercentage'] != null &&
        (widget.item['promotionBoostPercentage'] as num) > 0;
    final hasPriceInfo =
        widget.item['householdPriceMin'] != null ||
        widget.item['householdPriceMax'] != null ||
        (widget.item['commission'] != null &&
            (widget.item['commission'] as num) > 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRejected
              ? Colors.red.withValues(alpha: 0.3)
              : const Color(0xFFE8EDF2),
        ),
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
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Material icon
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isRejected
                        ? Colors.red.withValues(alpha: 0.08)
                        : categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.recycling_rounded,
                    size: 14,
                    color: isRejected ? Colors.red[400] : categoryColor,
                  ),
                ),
                const SizedBox(width: 10),
                // Name + badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (isRejected || hasPromo) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (isRejected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Text(
                                  'Not acceptable',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ),
                            if (hasPromo) ...[
                              if (isRejected) const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+${(widget.item['promotionBoostPercentage'] as num).toStringAsFixed(0)}% boost',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.successColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove Item'),
                        content: Text(
                          'Remove ${widget.item['type']?.toString() ?? 'this item'}?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              widget.onRemove();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red[400],
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: 'Remove item',
                ),
              ],
            ),
          ),

          // ── Price reference row ─────────────────────────
          if (hasPriceInfo) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  if (widget.item['householdPriceMin'] != null ||
                      widget.item['householdPriceMax'] != null) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HH PRICE RANGE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '\u20B1${((widget.item['householdPriceMin'] ?? 0.0) as num).toStringAsFixed(2)}\u2013\u20B1${((widget.item['householdPriceMax'] ?? 0.0) as num).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          Text(
                            'per $unit',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.item['householdPriceMax'] != null &&
                      widget.item['commission'] != null) ...[
                    Container(
                      width: 1,
                      height: 36,
                      color: const Color(0xFFE2E8F0),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR PAYMENT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '\u20B1${(((widget.item['householdPriceMax'] ?? 0.0) as num) - ((widget.item['commission'] ?? 0.0) as num)).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          Text(
                            'per $unit (after commission)',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (widget.item['commission'] != null &&
                      (widget.item['commission'] as num) > 0) ...[
                    Container(
                      width: 1,
                      height: 36,
                      color: const Color(0xFFE2E8F0),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'COMMISSION',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '\u20B1${((widget.item['commission'] ?? 0.0) as num).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'per $unit',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF94A3B8),
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

          // ── Editable fields ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quantity field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quantity',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: quantityController,
                                focusNode: quantityFocusNode,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 13,
                                  ),
                                  border: InputBorder.none,
                                  hintText: '0',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                onChanged: (v) {
                                  final qty = double.tryParse(v) ?? 0.0;
                                  widget.onChanged('quantity', qty);
                                  widget.onChanged('weight', '$qty $unit');
                                  final price =
                                      double.tryParse(
                                        pricePerUnitController.text,
                                      ) ??
                                      0.0;
                                  final baseTotal = qty * price;
                                  final boostPercentage =
                                      (widget.item['promotionBoostPercentage']
                                          is num)
                                      ? (widget.item['promotionBoostPercentage']
                                                as num)
                                            .toDouble()
                                      : 0.0;
                                  final boostedTotal = boostPercentage > 0
                                      ? baseTotal *
                                            (1 + (boostPercentage / 100))
                                      : baseTotal;
                                  widget.onChanged('price', boostedTotal);
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.12),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(9),
                                  bottomRight: Radius.circular(9),
                                ),
                              ),
                              child: Text(
                                unit,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Price per unit field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price / $unit',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text(
                                '\u20B1',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: pricePerUnitController,
                                focusNode: priceFocusNode,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [DecimalTextInputFormatter()],
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 13,
                                  ),
                                  border: InputBorder.none,
                                  hintText: '0.00',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                onChanged: (v) {
                                  final price = double.tryParse(v) ?? 0.0;
                                  widget.onChanged('pricePerUnit', price);
                                  final qty =
                                      double.tryParse(
                                        quantityController.text,
                                      ) ??
                                      0.0;
                                  final baseTotal = qty * price;
                                  final boostPercentage =
                                      (widget.item['promotionBoostPercentage']
                                          is num)
                                      ? (widget.item['promotionBoostPercentage']
                                                as num)
                                            .toDouble()
                                      : 0.0;
                                  final boostedTotal = boostPercentage > 0
                                      ? baseTotal *
                                            (1 + (boostPercentage / 100))
                                      : baseTotal;
                                  widget.onChanged('price', boostedTotal);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Item total footer ───────────────────────────
          () {
            final boostPercentage =
                widget.item['promotionBoostPercentage'] as num?;
            final hasBoost = boostPercentage != null && boostPercentage > 0;
            final storedPrice = (widget.item['price'] is num)
                ? (widget.item['price'] as num).toDouble()
                : 0.0;
            final basePrice = hasBoost
                ? storedPrice / (1 + (boostPercentage / 100))
                : storedPrice;

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Item Total',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (hasBoost)
                        Text(
                          '+${boostPercentage.toStringAsFixed(0)}% boost applied',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.successColor,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasBoost)
                        Text(
                          '\u20B1${basePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        '\u20B1${storedPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }(),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'plastic':
        return const Color(0xFF3B82F6);
      case 'paper':
        return const Color(0xFFF59E0B);
      case 'metal':
        return const Color(0xFF6366F1);
      case 'glass':
        return const Color(0xFF06B6D4);
      case 'electronics':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.collectorPrimary;
    }
  }
}

// Dialog for adding new items with all required fields
class _AddItemDialog extends StatefulWidget {
  final void Function(Map<String, dynamic> item) onAdd;
  final String? junkshopId;
  const _AddItemDialog({required this.onAdd, this.junkshopId});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _pricePerUnitController = TextEditingController(text: '0');

  String? _selectedCategory;
  String? _selectedItemName;
  String _selectedUnit = 'kg';
  Offset _dragOffset = Offset.zero;

  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _materialsByCategory = {};
  Map<String, Map<String, dynamic>> _materialDetails = {};

  List<String> get _categories => _materialsByCategory.keys.toList();
  List<Map<String, dynamic>> get _availableItems =>
      _materialsByCategory[_selectedCategory] ?? [];

  double get _totalPrice {
    final qty = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_pricePerUnitController.text) ?? 0;
    return qty * price;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _pricePerUnitController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchJunkshopMaterials();
  }

  Future<void> _fetchJunkshopMaterials() async {
    if (kDebugMode) {
      print(
        'ðŸ” _fetchJunkshopMaterials called with junkshopId: ${widget.junkshopId}',
      );
    }

    if (widget.junkshopId == null || widget.junkshopId!.isEmpty) {
      setState(() {
        _materialsByCategory = {
          'Plastic': [
            {'name': 'Plastic Bottles', 'unit': 'kg', 'price': 0.0},
            {'name': 'PET Bottles', 'unit': 'kg', 'price': 0.0},
          ],
          'Paper': [
            {'name': 'Cardboard', 'unit': 'kg', 'price': 0.0},
          ],
          'Metal': [
            {'name': 'Aluminum Cans', 'unit': 'kg', 'price': 0.0},
          ],
        };
        _isLoading = false;
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
          if (_availableItems.isNotEmpty) {
            _selectedItemName = _availableItems.first['name'];
            _updatePriceFromSelection();
          }
        }
      });
      return;
    }

    try {
      final materialRows = await supabase
          .from('junkshop_materials')
          .select()
          .eq('junkshop_id', widget.junkshopId!);
      final materialDocs = rowsToDocs('junkshop_materials', materialRows);

      if (kDebugMode) {
        print(
          'ðŸ“¦ Fetched ${materialDocs.length} materials from junkshop',
        );
      }

      if (materialDocs.isEmpty) {
        if (kDebugMode) {
          print(
            '\u20B1 ï¸ No materials found in junkshop materials subcollection',
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      final Map<String, Map<String, dynamic>> details = {};

      for (final mat in materialDocs) {

        // Skip inactive materials
        if (mat['isActive'] == false) {
          continue;
        }

        final category = (mat['category'] ?? 'Mixed').toString();
        final name = (mat['name'] ?? 'Unknown').toString();
        final unit = (mat['unit'] ?? 'kg').toString();

        final householdPriceMin = (mat['householdPriceMin'] is num)
            ? (mat['householdPriceMin'] as num).toDouble()
            : (double.tryParse(mat['householdPriceMin']?.toString() ?? '0') ??
                  0.0);
        final householdPriceMax = (mat['householdPriceMax'] is num)
            ? (mat['householdPriceMax'] as num).toDouble()
            : (double.tryParse(mat['householdPriceMax']?.toString() ?? '0') ??
                  0.0);
        final commission = (mat['commission'] is num)
            ? (mat['commission'] as num).toDouble()
            : (double.tryParse(mat['commission']?.toString() ?? '0') ?? 0.0);

        // Calculate collector's actual payment (household price - commission)
        final collectorPriceMin = householdPriceMin - commission;
        final collectorPriceMax = householdPriceMax - commission;

        if (kDebugMode) {
          print(
            '  âœ“ Material: $name (category: $category, unit: $unit, householdPrice: $householdPriceMin-$householdPriceMax, commission: $commission, collectorPrice: $collectorPriceMin-$collectorPriceMax)',
          );
        }

        final materialData = {
          'name': name,
          'unit': unit,
          'householdPriceMin': householdPriceMin,
          'householdPriceMax': householdPriceMax,
          'commission': commission,
          'collectorPriceMin': collectorPriceMin,
          'collectorPriceMax': collectorPriceMax,
          'category': category,
        };

        if (!grouped.containsKey(category)) {
          grouped[category] = [];
        }
        grouped[category]!.add(materialData);
        details[name] = materialData;
      }

      if (kDebugMode) print('ðŸ“Š Grouped materials: ${grouped.keys.toList()}');

      setState(() {
        _materialsByCategory = grouped;
        _materialDetails = details;
        _isLoading = false;

        // Don't pre-select - let user choose
        _selectedCategory = null;
        _selectedItemName = null;
      });
    } catch (e) {
      if (kDebugMode) print('âŒ Error fetching junkshop materials: $e');
      setState(() => _isLoading = false);
    }
  }

  void _updatePriceFromSelection() {
    if (kDebugMode) {
      print(
        'ðŸ“‹ Available material details keys: ${_materialDetails.keys.toList()}',
      );
    }

    final material = _materialDetails[_selectedItemName];
    if (kDebugMode) print('ðŸ“¦ Material found: $material');

    if (material != null) {
      final collectorPriceMin = material['collectorPriceMin'] ?? 0.0;
      final collectorPriceMax = material['collectorPriceMax'] ?? 0.0;
      final householdPriceMax = material['householdPriceMax'] ?? 0.0;
      final commission = material['commission'] ?? 0.0;
      final unit = material['unit'];
      if (kDebugMode) {
        print(
          'ðŸ’° Household price: $householdPriceMax, Commission: $commission, Collector pays: $collectorPriceMin-$collectorPriceMax, unit: $unit',
        );
      }

      // Use average of collectorPriceMin and collectorPriceMax
      if (collectorPriceMin > 0 || collectorPriceMax > 0) {
        final avgPrice = (collectorPriceMin + collectorPriceMax) / 2;
        _pricePerUnitController.text = avgPrice.toStringAsFixed(2);
        if (kDebugMode) {
          print(
            'âœ… Set price to average: $avgPrice (min: $collectorPriceMin, max: $collectorPriceMax)',
          );
        }
      } else {
        _pricePerUnitController.text =
            ''; // Clear field so user can enter price
        if (kDebugMode) {
          print(
            '\u20B1 ï¸ Material price is 0 or null, user must enter manually',
          );
        }
      }

      _selectedUnit = unit ?? 'kg';
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final qty = double.tryParse(_quantityController.text) ?? 0;
      final pricePerUnit = double.tryParse(_pricePerUnitController.text) ?? 0;

      widget.onAdd({
        'type': _selectedItemName,
        'category': _selectedCategory,
        'quantity': qty,
        'unit': _selectedUnit,
        'weight': '$qty $_selectedUnit',
        'pricePerUnit': pricePerUnit,
        'price': qty * pricePerUnit,
      });

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Transform.translate(
        offset: _dragOffset,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: screenSize.height * 0.88,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              GestureDetector(
                onPanUpdate: (details) =>
                    setState(() => _dragOffset += details.delta),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.collectorPrimary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.add_circle_outline_rounded,
                            color: AppColors.collectorPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Add Item',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.basic,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              minimumSize: const Size(34, 34),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

              // â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // â”€â”€ Category label â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                              const Text(
                                'CATEGORY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // â”€â”€ Category chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                              SizedBox(
                                height: 34,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _categories.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    final cat = _categories[i];
                                    final selected = cat == _selectedCategory;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCategory = cat;
                                          _selectedItemName = null;
                                          _pricePerUnitController.clear();
                                          _selectedUnit = 'kg';
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.collectorPrimary
                                              : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? AppColors.collectorPrimary
                                                : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Text(
                                          cat,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 20),

                              // â”€â”€ Item section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                              if (_selectedCategory == null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(
                                        Icons.category_outlined,
                                        color: Color(0xFFCBD5E1),
                                        size: 28,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Select a category to see items',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                const Text(
                                  'SELECT ITEM',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_availableItems.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: const Text(
                                      'No items in this category',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  )
                                else
                                  ..._availableItems.map((itemData) {
                                    final itemName =
                                        itemData['name'] as String? ?? '';
                                    final details =
                                        _materialDetails[itemName] ?? itemData;
                                    final priceMin =
                                        (details['householdPriceMin'] as num?)
                                            ?.toDouble() ??
                                        0;
                                    final priceMax =
                                        (details['householdPriceMax'] as num?)
                                            ?.toDouble() ??
                                        0;
                                    final unit =
                                        details['unit'] as String? ?? 'kg';
                                    final isSelected =
                                        itemName == _selectedItemName;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(
                                          () => _selectedItemName = itemName,
                                        );
                                        _updatePriceFromSelection();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 11,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.collectorPrimary
                                                    .withValues(alpha: 0.06)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.collectorPrimary
                                                : const Color(0xFFE2E8F0),
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            isSelected
                                                ? Icon(
                                                    Icons.check_circle_rounded,
                                                    color: AppColors
                                                        .collectorPrimary,
                                                    size: 18,
                                                  )
                                                : Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFFCBD5E1,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                itemName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: isSelected
                                                      ? AppColors
                                                            .collectorPrimary
                                                      : const Color(0xFF334155),
                                                ),
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  priceMax > 0
                                                      ? '\u20B1${priceMin.toStringAsFixed(0)}\u2013${priceMax.toStringAsFixed(0)}'
                                                      : '\u2014',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: priceMax > 0
                                                        ? const Color(
                                                            0xFF10B981,
                                                          )
                                                        : const Color(
                                                            0xFFCBD5E1,
                                                          ),
                                                  ),
                                                ),
                                                Text(
                                                  'per $unit',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],

                              // â”€â”€ Quantity & Price (shown when item selected)
                              if (_selectedItemName != null) ...[
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Quantity field
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'QUANTITY',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF94A3B8),
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors
                                                      .collectorPrimary
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  _selectedUnit,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors
                                                        .collectorPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _quantityController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                            decoration: InputDecoration(
                                              hintText: '0',
                                              hintStyle: const TextStyle(
                                                color: Color(0xFFCBD5E1),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 13,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide(
                                                  color: AppColors
                                                      .collectorPrimary,
                                                  width: 1.5,
                                                ),
                                              ),
                                              filled: true,
                                              fillColor: const Color(
                                                0xFFF8FAFC,
                                              ),
                                            ),
                                            validator: (v) {
                                              if (v == null || v.isEmpty) {
                                                return 'Required';
                                              }
                                              if (double.tryParse(v) == null) {
                                                return 'Invalid number';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Price per unit field
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'PRICE / $_selectedUnit'
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF94A3B8),
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _pricePerUnitController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                            decoration: InputDecoration(
                                              prefixText: '\u20B1 ',
                                              prefixStyle: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                              hintText: '0.00',
                                              hintStyle: const TextStyle(
                                                color: Color(0xFFCBD5E1),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 13,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide(
                                                  color: AppColors
                                                      .collectorPrimary,
                                                  width: 1.5,
                                                ),
                                              ),
                                              filled: true,
                                              fillColor: const Color(
                                                0xFFF8FAFC,
                                              ),
                                            ),
                                            validator: (v) {
                                              if (v == null || v.isEmpty) {
                                                return 'Required';
                                              }
                                              if (double.tryParse(v) == null) {
                                                return 'Invalid number';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // â”€â”€ Total row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total Price',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      Text(
                                        '\u20B1${_totalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // â”€â”€ Action buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: _selectedItemName != null
                                          ? _submit
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.collectorPrimary,
                                        disabledBackgroundColor: const Color(
                                          0xFFE2E8F0,
                                        ),
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: const Color(
                                          0xFF94A3B8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Add Item',
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
