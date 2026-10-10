import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import 'package:flutter/services.dart' show rootBundle;

class PriceGuideScreen extends StatefulWidget {
  const PriceGuideScreen({super.key});

  @override
  State<PriceGuideScreen> createState() => _PriceGuideScreenState();
}

class _PriceGuideScreenState extends State<PriceGuideScreen> {
  List<dynamic> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/config/material_prices.json',
      );
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _categories = data['categories'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load price guide';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Price Guide'),
        backgroundColor: AppColors.householdPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.householdPrimary),
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: AppTextStyles.bodyMedium));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.padding2xl),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index] as Map<String, dynamic>;
        final materials = (cat['materials'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        return Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.spacing24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingXl,
              vertical: AppDimensions.spacing16,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingXl,
              0,
              AppDimensions.paddingXl,
              AppDimensions.paddingXl,
            ),
            initiallyExpanded: index == 0,
            title: Row(
              children: [
                Text(
                  (cat['icon'] ?? '') as String,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (cat['name'] ?? 'Category') as String,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            children: [...materials.map((m) => _buildMaterialTile(m))],
          ),
        );
      },
    );
  }

  Widget _buildMaterialTile(Map<String, dynamic> m) {
    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.spacing16),
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (m['name'] ?? 'Material') as String,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if ((m['description'] ?? '').toString().isNotEmpty)
                  Text(
                    (m['description'] ?? '') as String,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.householdPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (m['price_range'] ?? '') as String,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.householdPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'per ${(m['unit'] ?? 'kg')}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
