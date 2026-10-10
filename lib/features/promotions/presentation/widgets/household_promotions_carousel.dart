import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/promotion.dart';
import '../bloc/household_promotions/household_promotions_bloc.dart';
import '../bloc/household_promotions/household_promotions_state.dart';
import '../screens/household/promotion_detail_screen.dart';

class HouseholdPromotionsCarousel extends StatelessWidget {
  const HouseholdPromotionsCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HouseholdPromotionsBloc, HouseholdPromotionsState>(
      builder: (context, state) {
        if (state is HouseholdPromotionsLoading) {
          return _buildLoadingState();
        }
        if (state is HouseholdPromotionsError) {
          return _buildErrorState(state.message);
        }
        if (state is HouseholdPromotionsLoaded) {
          if (state.promotions.isEmpty) return const SizedBox.shrink();
          return _PromotionsCarouselView(promotions: state.promotions);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacing16,
        AppDimensions.spacing20,
        AppDimensions.spacing16,
        AppDimensions.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(count: 0, isLoading: true),
          const SizedBox(height: 14),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: AppColors.successColor,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(count: 0, isLoading: false),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  FluentIcons.error_circle_24_regular,
                  color: AppColors.errorColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carousel view with PageView + dot indicators ─────────────────────────────

class _PromotionsCarouselView extends StatefulWidget {
  final List<Promotion> promotions;
  const _PromotionsCarouselView({required this.promotions});

  @override
  State<_PromotionsCarouselView> createState() =>
      _PromotionsCarouselViewState();
}

class _PromotionsCarouselViewState extends State<_PromotionsCarouselView> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.promotions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacing16,
            AppDimensions.spacing20,
            AppDimensions.spacing16,
            0,
          ),
          child: _SectionHeader(count: count, isLoading: false),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _pageController,
            itemCount: count,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 6,
                  right: index == count - 1 ? 0 : 6,
                ),
                child: _PromotionCard(promotion: widget.promotions[index]),
              );
            },
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 10),
          _DotIndicators(count: count, current: _currentPage),
        ],
        const SizedBox(height: AppDimensions.spacing12),
      ],
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final int count;
  final bool isLoading;
  const _SectionHeader({required this.count, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Active Promotions',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (!isLoading && count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (!isLoading && count > 0)
          Text(
            'Tap to view offer',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

// ─── Dot indicators ───────────────────────────────────────────────────────────

class _DotIndicators extends StatelessWidget {
  final int count;
  final int current;
  const _DotIndicators({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryGreen
                : AppColors.primaryGreen.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─── Promotion card ───────────────────────────────────────────────────────────

class _PromotionCard extends StatefulWidget {
  final Promotion promotion;

  const _PromotionCard({required this.promotion});

  @override
  State<_PromotionCard> createState() => _PromotionCardState();
}

class _PromotionCardState extends State<_PromotionCard> {
  List<String> _materialNames = [];
  bool _isLoadingMaterials = true;
  int _totalMaterialCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMaterialNames();
  }

  Future<void> _loadMaterialNames() async {
    if (widget.promotion.materials.isEmpty) {
      setState(() {
        _isLoadingMaterials = false;
      });
      return;
    }

    try {
      _totalMaterialCount = widget.promotion.materials.length;
      final materialsToLoad = widget.promotion.materials.take(2).toList();
      final names = <String>[];

      for (final materialId in materialsToLoad) {
        final row = await Supabase.instance.client
            .from('junkshop_materials')
            .select('name')
            .eq('id', materialId)
            .eq('junkshop_id', widget.promotion.junkshopId)
            .maybeSingle();

        if (row != null) {
          names.add((row['name'] as String?) ?? materialId);
        } else {
          names.add(materialId);
        }
      }

      if (mounted) {
        setState(() {
          _materialNames = names;
          _isLoadingMaterials = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMaterials = false;
        });
      }
    }
  }

  Color get _urgencyColor {
    final days = widget.promotion.endDate.difference(DateTime.now()).inDays;
    if (days <= 3) return const Color(0xFFEF4444);
    if (days <= 7) return const Color(0xFFF59E0B);
    return AppColors.primaryGreen;
  }

  String get _timeLabel {
    final days = widget.promotion.endDate.difference(DateTime.now()).inDays;
    if (days <= 0) return 'Ends today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }

  @override
  Widget build(BuildContext context) {
    final boostPct = widget.promotion.priceBoostDetails.boostPercentage
        .toStringAsFixed(0);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PromotionDetailScreen(promotion: widget.promotion),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent panel with boost %
            Container(
              width: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryGreen, AppColors.darkGreen],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '+$boostPct%',
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'BOOST',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Right content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top row: junkshop + time
                    Row(
                      children: [
                        const Icon(
                          FluentIcons.building_shop_20_filled,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.promotion.junkshopName,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _urgencyColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FluentIcons.clock_20_filled,
                                size: 10,
                                color: _urgencyColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _timeLabel,
                                style: AppTextStyles.caption.copyWith(
                                  color: _urgencyColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Title — single line
                    Text(
                      widget.promotion.title,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Material chips — single row, no wrap
                    if (!_isLoadingMaterials && _materialNames.isNotEmpty)
                      Row(
                        children: [
                          ..._materialNames
                              .take(2)
                              .map(
                                (name) => Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 5),
                                    child: _Chip(name: name),
                                  ),
                                ),
                              ),
                          if (_totalMaterialCount > 2)
                            _Chip(
                              name: '+${_totalMaterialCount - 2}',
                              muted: true,
                            ),
                        ],
                      )
                    else if (_isLoadingMaterials)
                      Container(
                        height: 18,
                        width: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Compact chip ─────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String name;
  final bool muted;
  const _Chip({required this.name, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted
            ? const Color(0xFFF1F5F9)
            : AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: AppTextStyles.caption.copyWith(
          color: muted ? AppColors.textSecondary : AppColors.primaryGreen,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
