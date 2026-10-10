import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/promotion.dart';

class PromotionDetailScreen extends StatefulWidget {
  final Promotion promotion;

  const PromotionDetailScreen({super.key, required this.promotion});

  @override
  State<PromotionDetailScreen> createState() => _PromotionDetailScreenState();
}

class _PromotionDetailScreenState extends State<PromotionDetailScreen> {
  Map<String, String> _materialsMap = {};
  bool _isLoadingMaterials = true;

  @override
  void initState() {
    super.initState();
    _loadMaterialNames();
  }

  Future<void> _loadMaterialNames() async {
    try {
      final rows = await Supabase.instance.client
          .from('junkshop_materials')
          .select('id, name')
          .eq('junkshop_id', widget.promotion.junkshopId);
      final map = <String, String>{};
      for (final row in rows) {
        map[row['id'].toString()] = (row['name'] as String?) ?? row['id'].toString();
      }
      if (mounted) {
        setState(() {
          _materialsMap = map;
          _isLoadingMaterials = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMaterials = false);
    }
  }

  String _materialName(String id) => _materialsMap[id] ?? id;

  int get _daysRemaining =>
      widget.promotion.endDate.difference(DateTime.now()).inDays;

  Color get _urgencyColor {
    if (_daysRemaining <= 3) return const Color(0xFFEF4444);
    if (_daysRemaining <= 7) return const Color(0xFFF59E0B);
    return AppColors.primaryGreen;
  }

  String get _urgencyLabel {
    if (_daysRemaining <= 0) return 'Expired';
    if (_daysRemaining == 1) return '1 day left';
    return '$_daysRemaining days left';
  }

  @override
  Widget build(BuildContext context) {
    final boost = widget.promotion.priceBoostDetails.boostPercentage;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Hero
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryGreen, AppColors.darkGreen],
                  ),
                ),
                child: Stack(
                  children: [
                    // Promotion image (full bleed when present)
                    if (widget.promotion.imageUrl != null)
                      Positioned.fill(
                        child: Image.network(
                          widget.promotion.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    // Dark scrim so text is always readable
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: widget.promotion.imageUrl != null
                                ? [
                                    Colors.black.withValues(alpha: 0.25),
                                    Colors.black.withValues(alpha: 0.72),
                                  ]
                                : [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.25),
                                  ],
                          ),
                        ),
                      ),
                    ),
                    // Decorative circles (only shown when no image)
                    if (widget.promotion.imageUrl == null) ...[
                      Positioned(
                        right: -60,
                        top: -40,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -30,
                        bottom: -20,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ],
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  FluentIcons.arrow_trending_20_filled,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Price Boost',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFamily:
                                        AppTextStyles.bodySmall.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '+${boost.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.promotion.title,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                FluentIcons.building_shop_20_filled,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  widget.promotion.junkshopName,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
          ),

          // Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick stats row
                  Row(
                    children: [
                      _StatTile(
                        icon: FluentIcons.clock_20_filled,
                        value: _urgencyLabel,
                        label: 'Time Left',
                        iconColor: _urgencyColor,
                        valueColor: _urgencyColor,
                      ),
                      const SizedBox(width: 10),
                      _StatTile(
                        icon: FluentIcons.arrow_trending_20_filled,
                        value: '+${boost.toStringAsFixed(0)}%',
                        label: 'Price Boost',
                        iconColor: AppColors.primaryGreen,
                        valueColor: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 10),
                      _StatTile(
                        icon: FluentIcons.box_20_filled,
                        value:
                            '${widget.promotion.materials.length} item${widget.promotion.materials.length == 1 ? '' : 's'}',
                        label: 'Materials',
                        iconColor: const Color(0xFF8B5CF6),
                        valueColor: AppColors.textPrimary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // About
                  if (widget.promotion.description.isNotEmpty) ...[
                    _SectionCard(
                      icon: FluentIcons.info_20_filled,
                      title: 'About this Promotion',
                      child: Text(
                        widget.promotion.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Eligible materials
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                          child: Row(
                            children: [
                              Text(
                                'Eligible Materials',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const Spacer(),
                              if (!_isLoadingMaterials)
                                Text(
                                  '${widget.promotion.materials.length} item${widget.promotion.materials.length == 1 ? '' : 's'}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: AppColors.borderLight),
                        // List
                        if (_isLoadingMaterials)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: widget.promotion.materials.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: AppColors.borderLight,
                            ),
                            itemBuilder: (context, i) {
                              final name = _materialName(
                                widget.promotion.materials[i],
                              );
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 13,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      '+${widget.promotion.priceBoostDetails.boostPercentage.toStringAsFixed(0)}%',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Validity timeline
                  _SectionCard(
                    icon: FluentIcons.calendar_20_filled,
                    title: 'Valid Period',
                    child: Row(
                      children: [
                        _DateBadge(
                          label: 'Start',
                          date: widget.promotion.startDate,
                          isStart: true,
                        ),
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 2,
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${widget.promotion.endDate.difference(widget.promotion.startDate).inDays}d',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryGreen,
                                    fontFamily:
                                        AppTextStyles.caption.fontFamily,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _DateBadge(
                          label: 'End',
                          date: widget.promotion.endDate,
                          isStart: false,
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

      // Bottom CTA
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/household-home',
                arguments: {
                  'initialIndex': 1,
                  'junkshopId': widget.promotion.junkshopId,
                  'promotionId': widget.promotion.id,
                  'promotionData': {
                    'materials': widget.promotion.materials,
                    'priceBoostDetails': {
                      'boostPercentage':
                          widget.promotion.priceBoostDetails.boostPercentage,
                    },
                  },
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.camera_add_20_filled, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Use This Promotion',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Stat tile (3-up quick stats row)

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color valueColor;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable section card

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 7),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// Date badge for validity timeline

class _DateBadge extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isStart;

  const _DateBadge({
    required this.label,
    required this.date,
    required this.isStart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          DateFormat('MMM dd').format(date),
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
        Text(
          DateFormat('yyyy').format(date),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
