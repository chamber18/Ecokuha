import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../domain/entities/promotion_type.dart';
import '../../bloc/junkshop_promotions/junkshop_promotions_bloc.dart';
import '../../bloc/junkshop_promotions/junkshop_promotions_event.dart';
import '../../bloc/junkshop_promotions/junkshop_promotions_state.dart';
import '../../widgets/promotion_card.dart';
import 'create_promotion_screen.dart';

class ManagePromotionsScreen extends StatefulWidget {
  const ManagePromotionsScreen({super.key});

  @override
  State<ManagePromotionsScreen> createState() => _ManagePromotionsScreenState();
}

class _ManagePromotionsScreenState extends State<ManagePromotionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late JunkshopPromotionsBloc _bloc;
  Map<String, String> _materialsMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _bloc = getIt<JunkshopPromotionsBloc>();
    _loadMaterialsMap();
    _loadPromotions();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadPromotions();
      }
    });
  }

  Future<void> _loadMaterialsMap() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final rows = await Supabase.instance.client
          .from('junkshop_materials')
          .select('id, name')
          .eq('junkshop_id', user.id);

      final map = <String, String>{};
      for (final data in rows) {
        map[data['id'].toString()] =
            (data['name'] as String?) ?? 'Unknown Material';
      }

      if (mounted) {
        setState(() => _materialsMap = map);
      }
    } catch (e) {
      debugPrint('Error loading materials: $e');
    }
  }

  String _getMaterialName(String materialId) {
    return _materialsMap[materialId] ?? materialId;
  }

  void _loadPromotions() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    PromotionStatus? statusFilter;
    switch (_tabController.index) {
      case 0:
        statusFilter = PromotionStatus.active;
        break;
      case 1:
        statusFilter = PromotionStatus.expired;
        break;
      case 2:
        statusFilter = PromotionStatus.cancelled;
        break;
    }

    _bloc.add(
      LoadJunkshopPromotions(junkshopId: user.id, statusFilter: statusFilter),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Manage Promotions',
            style: AppTextStyles.h5.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.primaryGreen,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Expired'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: BlocConsumer<JunkshopPromotionsBloc, JunkshopPromotionsState>(
          listener: (context, state) {
            if (state is PromotionCancelled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Promotion cancelled successfully'),
                  backgroundColor: Colors.orange,
                ),
              );
              _loadPromotions();
            } else if (state is PromotionDeleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Promotion deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              _loadPromotions();
            } else if (state is PromotionOperationError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is JunkshopPromotionsLoading ||
                state is PromotionCancelling ||
                state is PromotionDeleting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is JunkshopPromotionsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading promotions',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadPromotions,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (state is JunkshopPromotionsLoaded) {
              if (state.promotions.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () async {
                  _loadPromotions();
                  await Future.delayed(const Duration(seconds: 1));
                },
                child: ListView.builder(
                  itemCount: state.promotions.length,
                  itemBuilder: (context, index) {
                    final promotion = state.promotions[index];
                    final promotionWithNames = promotion.copyWith(
                      materials: promotion.materials
                          .map((id) => _getMaterialName(id))
                          .toList(),
                    );
                    return PromotionCard(
                      promotion: promotionWithNames,
                      onTap: () => _showPromotionDetails(promotion),
                      onEdit: () => _editPromotion(promotion),
                      onCancel: promotion.status == PromotionStatus.active
                          ? () => _cancelPromotion(promotion)
                          : null,
                      onDelete:
                          (promotion.status == PromotionStatus.draft ||
                              promotion.status == PromotionStatus.expired ||
                              promotion.status == PromotionStatus.cancelled)
                          ? () => _deletePromotion(promotion)
                          : null,
                    );
                  },
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createPromotion,
          backgroundColor: AppColors.primaryGreen,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'New Promotion',
            style: AppTextStyles.buttonMedium.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String subtitle;
    IconData icon;

    switch (_tabController.index) {
      case 0:
        message = 'No active promotions';
        subtitle = 'Create a promotion to attract more households';
        icon = Icons.campaign;
        break;
      case 1:
        message = 'No expired promotions';
        subtitle = 'Expired promotions will appear here';
        icon = Icons.event_busy;
        break;
      case 2:
        message = 'No cancelled promotions';
        subtitle = 'Cancelled promotions will appear here';
        icon = Icons.cancel;
        break;
      default:
        message = 'No promotions';
        subtitle = '';
        icon = Icons.inbox;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            message,
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_tabController.index == 0) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createPromotion,
              icon: const Icon(Icons.add),
              label: const Text('Create Promotion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _createPromotion() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _bloc,
          child: const CreatePromotionScreen(),
        ),
      ),
    );

    if (result == true) {
      _loadPromotions();
    }
  }

  void _editPromotion(promotion) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _bloc,
          child: CreatePromotionScreen(existingPromotion: promotion),
        ),
      ),
    );

    if (result == true) {
      _loadPromotions();
    }
  }

  void _showPromotionDetails(promotion) {
    final daysRemaining = promotion.endDate.difference(DateTime.now()).inDays;
    final duration = promotion.endDate.difference(promotion.startDate).inDays;

    Color statusColor;
    switch (promotion.status) {
      case PromotionStatus.active:
        statusColor = AppColors.primaryGreen;
        break;
      case PromotionStatus.expired:
        statusColor = const Color(0xFFEF4444);
        break;
      case PromotionStatus.cancelled:
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }
    final statusLabel = promotion.status.displayName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Hero header
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: promotion.imageUrl != null
                        ? Stack(
                            children: [
                              Image.network(
                                promotion.imageUrl!,
                                width: double.infinity,
                                height: 210,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _detailBanner(promotion.title),
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return _detailBanner(promotion.title);
                                    },
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.65),
                                      ],
                                      stops: const [0.4, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 14,
                                child: Text(
                                  promotion.title,
                                  style: AppTextStyles.h4.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : _detailBanner(promotion.title),
                  ),
                  // Drag handle overlaid at top
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status + boost + time row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: AppTextStyles.caption.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+${promotion.priceBoostDetails.boostPercentage.toStringAsFixed(0)}%',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.05,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Text(
                              promotion.type.displayName,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (promotion.status == PromotionStatus.active) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: daysRemaining <= 3
                                    ? const Color(
                                        0xFFEF4444,
                                      ).withValues(alpha: 0.1)
                                    : const Color(
                                        0xFFF59E0B,
                                      ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                daysRemaining <= 0
                                    ? 'Ends today'
                                    : '$daysRemaining days left',
                                style: AppTextStyles.caption.copyWith(
                                  color: daysRemaining <= 3
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 2x2 stat grid
                      Row(
                        children: [
                          Expanded(
                            child: _detailStatTile(
                              Icons.calendar_today_outlined,
                              'Start Date',
                              _formatDate(promotion.startDate),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _detailStatTile(
                              Icons.event_outlined,
                              'End Date',
                              _formatDate(promotion.endDate),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _detailStatTile(
                              Icons.hourglass_bottom_outlined,
                              'Duration',
                              '$duration days',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _detailStatTile(
                              Icons.inventory_2_outlined,
                              'Materials',
                              '${promotion.materials.length} items',
                            ),
                          ),
                        ],
                      ),
                      // Description
                      if (promotion.description.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Description',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          promotion.description,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                      // Materials
                      if (promotion.materials.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'Applicable Materials',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${promotion.materials.length}',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: promotion.materials.map<Widget>((
                            materialId,
                          ) {
                            final materialName = _getMaterialName(materialId);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Text(
                                materialName,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      // Action buttons
                      if (promotion.status == 'active') ...[
                        const SizedBox(height: 24),
                        Divider(color: AppColors.borderLight),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                    context,
                                    '/junkshop/promotions/edit',
                                    arguments: {'promotion': promotion},
                                  );
                                },
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                  side: BorderSide(
                                    color: AppColors.primaryGreen.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _cancelPromotion(promotion);
                                },
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 16,
                                ),
                                label: const Text('Cancel'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: BorderSide(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 24),
                        Divider(color: AppColors.borderLight),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deletePromotion(promotion);
                            },
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Delete Promotion'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: BorderSide(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailBanner(String title) {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withValues(alpha: 0.65),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -15,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                title,
                style: AppTextStyles.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailStatTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _cancelPromotion(promotion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Promotion?'),
        content: const Text(
          'This will immediately stop the promotion. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, keep it'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final user = Supabase.instance.client.auth.currentUser;
              if (user != null) {
                _bloc.add(
                  CancelExistingPromotion(
                    promotionId: promotion.id,
                    junkshopId: user.id,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Yes, cancel it'),
          ),
        ],
      ),
    );
  }

  void _deletePromotion(promotion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Promotion?'),
        content: const Text(
          'This will permanently delete the promotion. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final user = Supabase.instance.client.auth.currentUser;
              if (user != null) {
                _bloc.add(
                  DeleteExistingPromotion(
                    promotionId: promotion.id,
                    junkshopId: user.id,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
