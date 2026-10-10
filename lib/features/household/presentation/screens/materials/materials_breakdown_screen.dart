import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/supabase/supabase_helpers.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';

class MaterialsBreakdownScreen extends StatefulWidget {
  const MaterialsBreakdownScreen({super.key});

  @override
  State<MaterialsBreakdownScreen> createState() =>
      _MaterialsBreakdownScreenState();
}

class _MaterialsBreakdownScreenState extends State<MaterialsBreakdownScreen> {
  bool _isLoading = true;
  Map<String, MaterialStats> _materials = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final rows = rowsToDocs(
        'postings',
        await Supabase.instance.client
            .from('postings')
            .select()
            .eq('household_id', userId)
            .eq('status', 'completed'),
      );

      final Map<String, MaterialStats> materialsMap = {};

      for (final data in rows) {
        final items = _extractItems(data);
        for (final item in items) {
          final category =
              item['name'] as String? ?? item['category'] as String? ?? 'Other';
          final weight = _extractWeight(item);
          final value = _extractValue(item);
          final quantity = _extractQuantity(item);
          final unit = item['unit'] as String? ?? 'kg';
          if (materialsMap.containsKey(category)) {
            materialsMap[category] = MaterialStats(
              count: materialsMap[category]!.count + 1,
              quantity: materialsMap[category]!.quantity + quantity,
              totalWeight: materialsMap[category]!.totalWeight + weight,
              totalValue: materialsMap[category]!.totalValue + value,
              unit: materialsMap[category]!.unit,
            );
          } else {
            materialsMap[category] = MaterialStats(
              count: 1,
              quantity: quantity,
              totalWeight: weight,
              totalValue: value,
              unit: unit,
            );
          }
        }
      }

      final sortedEntries = materialsMap.entries.toList()
        ..sort((a, b) => b.value.totalValue.compareTo(a.value.totalValue));

      setState(() {
        _materials = Map<String, MaterialStats>.fromEntries(sortedEntries);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading materials: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _extractItems(Map<String, dynamic> postingData) {
    final purchasedItems = postingData['purchasedItems'];
    final verifiedItems = postingData['verifiedItems'];
    if (purchasedItems != null && purchasedItems is Map) {
      if (purchasedItems['list'] is List) {
        return List<Map<String, dynamic>>.from(purchasedItems['list']);
      }
    } else if (verifiedItems != null) {
      if (verifiedItems is Map && verifiedItems['items'] != null) {
        return List<Map<String, dynamic>>.from(verifiedItems['items']);
      } else if (verifiedItems is List) {
        return List<Map<String, dynamic>>.from(verifiedItems);
      }
    } else if (postingData['items'] != null) {
      return List<Map<String, dynamic>>.from(postingData['items']);
    }
    return [];
  }

  double _extractWeight(Map<String, dynamic> item) {
    final v = item['quantity'] ?? item['weight'] ?? item['weightKg'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  double _extractQuantity(Map<String, dynamic> item) {
    final v = item['quantity'] ?? item['weight'] ?? item['weightKg'];
    if (v == null) return 1.0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v) ?? 1.0;
    return 1.0;
  }

  double _extractValue(Map<String, dynamic> item) {
    final price = item['junkshopPricePerUnit'];
    final qty = item['quantity'] ?? item['weight'] ?? item['weightKg'];
    if (price != null && qty != null) {
      double p = price is num
          ? price.toDouble()
          : double.tryParse(price.toString()) ?? 0.0;
      double q = qty is num
          ? qty.toDouble()
          : double.tryParse(qty.toString()) ?? 0.0;
      return p * q;
    }
    final est = item['estimatedValue'];
    if (est != null) {
      if (est is num) return est.toDouble();
      if (est is String) return double.tryParse(est) ?? 0.0;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Materials Breakdown',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF3F4F6)),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
                strokeWidth: 2.5,
              ),
            )
          : _materials.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadMaterials,
              color: AppColors.primaryGreen,
              child: Column(
                children: [
                  _buildSearchBar(),
                  _buildSummaryRow(),
                  Expanded(child: _buildList()),
                ],
              ),
            ),
    );
  }

  //  Empty state

  Widget _buildEmptyState() {
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
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.recycle,
                size: 30,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Materials Yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start recycling to see your\nmaterials breakdown.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  //  Search bar

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 14.5, color: Color(0xFF1A1A2E)),
          decoration: InputDecoration(
            hintText: 'Search materials...',
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14.5,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF9CA3AF),
              size: 19,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: Color(0xFF9CA3AF),
                      size: 18,
                    ),
                    onPressed: () => _searchController.clear(),
                    padding: EdgeInsets.zero,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  //  Summary row

  Widget _buildSummaryRow() {
    final totalValue = _materials.values.fold<double>(
      0.0,
      (s, m) => s + m.totalValue,
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          _buildSummaryTile(
            icon: FontAwesomeIcons.layerGroup,
            label: 'Types',
            value: '${_materials.length}',
          ),
          const SizedBox(width: 10),
          _buildSummaryTile(
            icon: FontAwesomeIcons.pesoSign,
            label: 'Total value',
            value: NumberFormat('#,##0', 'en_US').format(totalValue),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FaIcon(icon, size: 13, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  //  List

  Widget _buildList() {
    final filtered = _searchQuery.isEmpty
        ? _materials
        : Map.fromEntries(
            _materials.entries.where(
              (e) => e.key.toLowerCase().contains(_searchQuery),
            ),
          );

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 32,
              color: Color(0xFFD1D5DB),
            ),
            SizedBox(height: 14),
            Text(
              'No results',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    final entries = filtered.entries.toList();
    final totalValue = entries.fold<double>(
      0.0,
      (s, e) => s + e.value.totalValue,
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 1,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: List.generate(entries.length, (i) {
            final entry = entries[i];
            final pct = totalValue > 0
                ? (entry.value.totalValue / totalValue * 100)
                : 0.0;
            return _buildMaterialRow(
              name: entry.key,
              stats: entry.value,
              percentage: pct,
              isLast: i == entries.length - 1,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMaterialRow({
    required String name,
    required MaterialStats stats,
    required double percentage,
    required bool isLast,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 4,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPill(
                    '₱${NumberFormat('#,##0.00', 'en_US').format(stats.totalValue)}',
                  ),
                  const SizedBox(width: 6),
                  _buildPill(
                    '${NumberFormat('#,##0.0', 'en_US').format(stats.totalWeight)} ${stats.unit}',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF3F4F6),
            indent: 20,
          ),
      ],
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class MaterialStats {
  final int count;
  final double quantity;
  final double totalWeight;
  final double totalValue;
  final String unit;

  MaterialStats({
    required this.count,
    required this.quantity,
    required this.totalWeight,
    required this.totalValue,
    this.unit = 'kg',
  });

  double get averageWeight => count > 0 ? totalWeight / count : 0.0;
}
