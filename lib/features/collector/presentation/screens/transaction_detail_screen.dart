import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

class CollectionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> collection;
  const CollectionDetailScreen({super.key, required this.collection});

  // Cache material prices lookup
  static final Future<_PriceLookup> _priceLookupFuture = _loadPriceLookup();

  @override
  Widget build(BuildContext context) {
    final isCompleted = collection['status'] == 'completed';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Collection Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCompleted
                      ? [AppColors.primaryGreen, const Color(0xFF059669)]
                      : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCompleted
                                  ? 'Collection Completed'
                                  : 'Collection Cancelled',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              'id: ${collection['id'] ?? '—'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(
                                collection['dateCollected'] ??
                                    collection['date'],
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isCompleted) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Earnings',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '₱${collection['earnings'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.scale_outlined,
                      label: 'Weight',
                      value: collection['weight'] ?? '—',
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Items',
                      value: (collection['items'] is List)
                          ? '${(collection['items'] as List).length}'
                          : '—',
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                  if (collection['duration'] != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: collection['duration'],
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Customer Information
            _buildModernSection(
              title: 'Customer Information',
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF3B82F6),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.account_circle_outlined,
                    label: 'Name',
                    value: collection['customerName'],
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: collection['address'],
                    maxLines: 2,
                  ),
                  // ID moved to its own section below for full, selectable display
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Full Collection ID
            _buildModernSection(
              title: 'Collection ID',
              icon: Icons.tag_outlined,
              iconColor: const Color(0xFF0EA5E9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This is the exact ID from Firestore',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SelectableText(
                      collection['id'] ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Color(0xFF1E293B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Items Collected
            _buildModernSection(
              title: 'Items Collected',
              icon: Icons.checklist_rounded,
              iconColor: const Color(0xFF10B981),
              child: FutureBuilder<_PriceLookup>(
                future: _priceLookupFuture,
                builder: (context, snapshot) {
                  final items = (collection['items'] as List).cast<String>();
                  final lookup = snapshot.data;

                  return Column(
                    children: items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final name = entry.value;
                      final priceText = lookup?.priceForItem(name) ?? '—';

                      return Column(
                        children: [
                          if (index > 0) const Divider(height: 20),
                          _buildItemRow(
                            name: name,
                            priceText: priceText,
                            index: index + 1,
                          ),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Proof Photos
            ..._buildPhotoSections(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 1,
            color: const Color(0xFFF1F5F9),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
    TextStyle? valueStyle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style:
                    valueStyle ??
                    const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: maxLines,
                softWrap: true,
                overflow: maxLines > 2
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow({
    required String name,
    required String priceText,
    required int index,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            priceText,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM dd, yyyy • hh:mm a').format(date);
  }

  void _showPhotoDialog(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Close button at top
            Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            // Photo
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFF64748B),
                              size: 64,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build proof photo sections grouped by type.
  List<Widget> _buildPhotoSections() {
    final legacy = List<String>.from(
      collection['proofPhotos'] ?? const <String>[],
    );
    final groups = _extractProofPhotoGroups(collection, legacy);

    return groups.entries.where((e) => e.value.isNotEmpty).map((entry) {
      IconData sectionIcon;
      Color sectionColor;

      switch (entry.key) {
        case 'Arrival Proof':
          sectionIcon = Icons.location_on_outlined;
          sectionColor = const Color(0xFF3B82F6);
          break;
        case 'Collection Proof':
          sectionIcon = Icons.photo_camera_outlined;
          sectionColor = AppColors.primaryGreen;
          break;
        case 'Receipt Proof':
          sectionIcon = Icons.receipt_long_outlined;
          sectionColor = const Color(0xFF8B5CF6);
          break;
        default:
          sectionIcon = Icons.photo_library_outlined;
          sectionColor = const Color(0xFF64748B);
      }

      return _buildModernSection(
        title: entry.key,
        icon: sectionIcon,
        iconColor: sectionColor,
        child: SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entry.value.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final url = entry.value[index];
              return GestureDetector(
                onTap: () => _showPhotoDialog(context, url),
                child: Hero(
                  tag: '$url-$index',
                  child: Container(
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 200,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      color: Color(0xFF64748B),
                                      size: 40,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Failed to load',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 200,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      sectionColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Gradient overlay for better visibility of expand icon
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.4),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Expand icon
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.fullscreen,
                              size: 18,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }).toList();
  }

  // Load price lookup from asset
  static Future<_PriceLookup> _loadPriceLookup() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/config/material_prices.json',
      );
      final Map<String, dynamic> data = json.decode(raw);
      return _PriceLookup.fromJson(data);
    } catch (_) {
      return _PriceLookup.empty();
    }
  }

  // Normalize proof photo inputs
  Map<String, List<String>> _extractProofPhotoGroups(
    Map<String, dynamic> c,
    List<String> legacy,
  ) {
    List<String> asList(dynamic v) => v is List ? v.cast<String>() : <String>[];
    final arrived = asList(c['proofArrived']);
    final collected = asList(c['proofCollection']);
    final receipt = asList(c['proofReceipt']);

    final hasAny =
        arrived.isNotEmpty || collected.isNotEmpty || receipt.isNotEmpty;
    final collectionList = collected.isNotEmpty
        ? collected
        : (!hasAny ? legacy : <String>[]);

    return {
      'Arrived Proof': arrived,
      'Collection Proof': collectionList,
      'Receipt Proof': receipt,
    };
  }
}

// Simple price lookup model for displaying ranges
class _PriceLookup {
  final Map<String, String>
  materialToRange; // material name -> price range display
  final Map<String, String>
  categoryToRange; // category id -> price range display

  _PriceLookup({required this.materialToRange, required this.categoryToRange});

  factory _PriceLookup.fromJson(Map<String, dynamic> jsonData) {
    final materials = <String, String>{};
    final categories = <String, String>{};

    final cats = (jsonData['categories'] as List).cast<Map<String, dynamic>>();
    for (final cat in cats) {
      final id = (cat['id'] as String).toLowerCase();
      final mats = (cat['materials'] as List).cast<Map<String, dynamic>>();

      for (final m in mats) {
        final name = (m['name'] as String).trim();
        final range = (m['price_range'] as String).trim();
        materials[name.toLowerCase()] = range;
      }

      final kgMaterials = mats.where((m) => (m['unit'] as String) == 'kg');
      String displayRange;
      if (kgMaterials.isNotEmpty) {
        final minVal = kgMaterials
            .map((m) => (m['min_price'] as num).toDouble())
            .reduce((a, b) => a < b ? a : b);
        final maxVal = kgMaterials
            .map((m) => (m['max_price'] as num).toDouble())
            .reduce((a, b) => a > b ? a : b);
        displayRange =
            '₱${minVal.toStringAsFixed(0)}-${maxVal.toStringAsFixed(0)}/kg';
      } else {
        final first = mats.first;
        displayRange = (first['price_range'] as String).trim();
      }
      categories[id] = displayRange;
    }

    return _PriceLookup(
      materialToRange: materials,
      categoryToRange: categories,
    );
  }

  static _PriceLookup empty() =>
      _PriceLookup(materialToRange: {}, categoryToRange: {});

  String? priceForItem(String itemName) {
    final key = itemName.toLowerCase().trim();
    if (materialToRange.containsKey(key)) return materialToRange[key];

    // Category-level lookup for generic labels
    final catKey = _categoryKeyForName(key);
    if (catKey != null && categoryToRange.containsKey(catKey)) {
      return categoryToRange[catKey];
    }

    // Fuzzy partial match
    final match = materialToRange.entries.firstWhere(
      (e) => e.key.contains(key) || key.contains(e.key),
      orElse: () => const MapEntry('', ''),
    );
    if (match.key.isNotEmpty) return match.value;

    return null;
  }

  String? _categoryKeyForName(String key) {
    switch (key) {
      case 'plastic':
        return 'plastic';
      case 'metal':
        return 'metal';
      case 'paper':
        return 'paper';
      case 'glass':
        return 'glass';
      case 'electronics':
      case 'electronic':
        return 'electronics';
      default:
        return null;
    }
  }
}
