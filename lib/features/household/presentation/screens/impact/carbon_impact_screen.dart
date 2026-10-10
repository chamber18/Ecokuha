import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../../core/services/carbon_calculator_service.dart';
import '../../../../../core/theme/app_colors.dart';

class CarbonImpactScreen extends StatefulWidget {
  final String userId;

  const CarbonImpactScreen({super.key, required this.userId});

  @override
  State<CarbonImpactScreen> createState() => _CarbonImpactScreenState();
}

class _CarbonImpactScreenState extends State<CarbonImpactScreen> {
  final CarbonCalculatorService _carbonService = CarbonCalculatorService();
  bool _isLoading = true;
  CarbonSavingsReport? _report;

  @override
  void initState() {
    super.initState();
    _loadCarbonData();
  }

  Future<void> _loadCarbonData() async {
    setState(() => _isLoading = true);
    try {
      final report = await _carbonService.calculateTotalCarbon(
        userId: widget.userId,
      );
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading carbon data: $e');
      setState(() => _isLoading = false);
    }
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
          'Carbon Impact',
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
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
                strokeWidth: 2.5,
              ),
            )
          : _report == null || _report!.totalKgCO2 == 0
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadCarbonData,
              color: AppColors.primaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroHeader(),
                    const SizedBox(height: 16),
                    _buildEquivalentsSection(),
                    const SizedBox(height: 8),
                    _buildMaterialBreakdown(),
                    const SizedBox(height: 8),
                    _buildMethodologyCard(),
                  ],
                ),
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
              child: const Icon(
                Icons.eco_outlined,
                size: 36,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Carbon Data Yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start recycling to see your\nenvironmental impact.',
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

  //  Hero header

  Widget _buildHeroHeader() {
    final totalCO2 = _report!.totalKgCO2;
    final collections = _report!.totalCollections;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.eco,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total CO Prevented',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$collections collection${collections != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB0B7C3),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: totalCO2.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryGreen,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const TextSpan(
                  text: ' kg CO\u2082',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'emissions prevented through recycling',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  //  Equivalents section

  Widget _buildEquivalentsSection() {
    final eq = _carbonService.getEquivalents(_report!.totalKgCO2);

    final items = [
      _EquivalentItem(
        icon: FontAwesomeIcons.tree,
        label: 'Trees for 1 year',
        value: eq.treesPlanted.toStringAsFixed(1),
      ),
      _EquivalentItem(
        icon: FontAwesomeIcons.car,
        label: 'km not driven',
        value: NumberFormat('#,##0').format(eq.carKilometersSaved),
      ),
      _EquivalentItem(
        icon: FontAwesomeIcons.house,
        label: 'Days of home energy',
        value: eq.homeEnergyDaysSaved.toStringAsFixed(1),
      ),
      _EquivalentItem(
        icon: FontAwesomeIcons.mobileScreenButton,
        label: 'Phone charges',
        value: NumberFormat('#,##0').format(eq.phoneChargesSaved),
      ),
      _EquivalentItem(
        icon: FontAwesomeIcons.lightbulb,
        label: 'LED bulb hours',
        value: NumberFormat('#,##0').format(eq.lightbulbHoursSaved),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 12),
            child: Text(
              'EQUIVALENT TO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          FaIcon(
                            item.icon,
                            size: 15,
                            color: const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          Text(
                            item.value,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < items.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF3F4F6),
                        indent: 20,
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  //  Material breakdown

  Widget _buildMaterialBreakdown() {
    final topMaterials = _report!.getTopMaterials(limit: 10);
    if (topMaterials.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 12),
            child: Text(
              'BY MATERIAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(topMaterials.length, (i) {
                final entry = topMaterials[i];
                final isLast = i == topMaterials.length - 1;
                return _buildMaterialRow(entry.key, entry.value, isLast);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialRow(
    String material,
    MaterialCarbonData data,
    bool isLast,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          material,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        subtitle: Text(
          '${data.totalCarbon.toStringAsFixed(2)} kg CO\u2082 saved',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFFB0B7C3),
          size: 20,
        ),
        children: [
          if (!isLast)
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF3F4F6),
              indent: 20,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              children: [
                _buildDetailRow(
                  'Weight recycled',
                  '${data.totalWeight.toStringAsFixed(2)} kg',
                ),
                _buildDetailRow('Items recycled', '${data.itemCount}'),
                _buildDetailRow(
                  'Carbon factor',
                  '${data.carbonFactor.toStringAsFixed(2)} kg CO\u2082/kg',
                ),
                _buildDetailRow(
                  'Avg weight/item',
                  '${data.averageWeight.toStringAsFixed(2)} kg',
                ),
              ],
            ),
          ),
          if (!isLast)
            const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  //  Methodology card

  Widget _buildMethodologyCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 12),
            child: Text(
              'METHODOLOGY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                childrenPadding: EdgeInsets.zero,
                title: const Text(
                  'How it\'s calculated',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                subtitle: const Text(
                  'EPA & industry emission factors',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                trailing: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFFB0B7C3),
                  size: 20,
                ),
                children: [
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF3F4F6),
                    indent: 20,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Formula',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'CO\u2082 saved = Material weight \u00d7 Carbon factor',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Data Sources',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildSource('EPA Waste Reduction Model (WARM)'),
                        _buildSource('World Bank Carbon Footprint Database'),
                        _buildSource('European Environment Agency'),
                        _buildSource(
                          'Industry associations (aluminium, steel, etc.)',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Last updated ${DateFormat('MMM d, yyyy').format(_report!.calculatedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB0B7C3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSource(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: CircleAvatar(
              radius: 2.5,
              backgroundColor: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }
}

//  Data model for equivalents display

class _EquivalentItem {
  final IconData icon;
  final String label;
  final String value;

  const _EquivalentItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}
