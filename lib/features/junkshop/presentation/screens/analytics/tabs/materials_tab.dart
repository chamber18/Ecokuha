import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../bloc/material_analytics/material_analytics_bloc.dart';
import '../../../bloc/material_analytics/material_analytics_event.dart';
import '../../../bloc/material_analytics/material_analytics_state.dart';
import '../../../widgets/analytics/analytics_summary_cards.dart';
import '../../../widgets/analytics/material_analytics_table.dart';
import '../../../../data/services/material_export_service.dart';

class MaterialsTab extends StatefulWidget {
  const MaterialsTab({super.key});

  @override
  State<MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<MaterialsTab> {
  final TextEditingController _searchController = TextEditingController();
  final _exportService = MaterialExportService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportToCsv(MaterialAnalyticsLoaded state) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating CSV export...'),
                ],
              ),
            ),
          ),
        ),
      );

      await _exportService.exportMaterialsToCsv(
        materials: state.filteredMaterials,
        junkshopId: user.id,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Export completed! Check your device for the CSV file.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDateFilterMenu() async {
    final state = context.read<MaterialAnalyticsBloc>().state;
    if (state is! MaterialAnalyticsLoaded) return;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        FluentIcons.calendar_ltr_24_regular,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Date Range',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing12,
                  vertical: AppDimensions.spacing8,
                ),
                child: Text(
                  'QUICK FILTERS',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _buildMenuTile(
                'Last 30 Days',
                FluentIcons.clock_24_regular,
                DateRangePreset.last30Days,
                state.selectedPreset,
              ),
              _buildMenuTile(
                'This Month',
                FluentIcons.calendar_ltr_24_regular,
                DateRangePreset.thisMonth,
                state.selectedPreset,
              ),
              _buildMenuTile(
                'Last Month',
                FluentIcons.calendar_ltr_24_regular,
                DateRangePreset.lastMonth,
                state.selectedPreset,
              ),
              _buildMenuTile(
                'Last 3 Months',
                FluentIcons.calendar_ltr_24_regular,
                DateRangePreset.last3Months,
                state.selectedPreset,
              ),
              _buildMenuTile(
                'Last 6 Months',
                FluentIcons.calendar_ltr_24_regular,
                DateRangePreset.last6Months,
                state.selectedPreset,
              ),
              _buildMenuTile(
                'Last 12 Months',
                FluentIcons.calendar_ltr_24_regular,
                DateRangePreset.last12Months,
                state.selectedPreset,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing16,
                ),
                child: Divider(height: 24),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing12,
                  vertical: AppDimensions.spacing8,
                ),
                child: Text(
                  'CUSTOM',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _buildCustomTile(
                'Select Month',
                FluentIcons.calendar_ltr_24_regular,
                () async {
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (mounted) _showMonthPicker();
                },
              ),
              _buildCustomTile(
                'Select Year',
                FluentIcons.calendar_star_24_regular,
                () async {
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (mounted) _showYearPicker();
                },
              ),
              _buildCustomTile(
                'Custom Range',
                FluentIcons.calendar_ltr_24_regular,
                () async {
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (mounted) _showDateRangePicker();
                },
              ),
              const SizedBox(height: AppDimensions.spacing8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    String label,
    IconData icon,
    DateRangePreset preset,
    DateRangePreset selectedPreset,
  ) {
    final isSelected = preset == selectedPreset;
    return InkWell(
      onTap: () {
        final bloc = context.read<MaterialAnalyticsBloc>();
        Navigator.pop(context);
        bloc.add(SelectDatePreset(preset));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : Colors.transparent,
          border: isSelected
              ? Border(
                  left: BorderSide(color: AppColors.primaryGreen, width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                FluentIcons.checkmark_circle_24_filled,
                color: AppColors.primaryGreen,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTile(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryGreen),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              FluentIcons.chevron_right_24_regular,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final state = context.read<MaterialAnalyticsBloc>().state;
    if (state is! MaterialAnalyticsLoaded) return;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: state.startDate,
        end: state.endDate,
      ),
    );

    if (picked != null && mounted) {
      context.read<MaterialAnalyticsBloc>().add(
        FilterByDateRange(startDate: picked.start, endDate: picked.end),
      );
    }
  }

  Future<void> _showMonthPicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Month',
    );

    if (pickedDate != null && mounted) {
      context.read<MaterialAnalyticsBloc>().add(
        SelectDatePreset(DateRangePreset.customMonth, customDate: pickedDate),
      );
    }
  }

  Future<void> _showYearPicker() async {
    final now = DateTime.now();
    final selectedYear = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Year'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: now,
              selectedDate: now,
              onChanged: (DateTime dateTime) {
                Navigator.pop(context, dateTime.year);
              },
            ),
          ),
        );
      },
    );

    if (selectedYear != null && mounted) {
      context.read<MaterialAnalyticsBloc>().add(
        SelectDatePreset(
          DateRangePreset.customYear,
          customDate: DateTime(selectedYear),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MaterialAnalyticsBloc, MaterialAnalyticsState>(
      builder: (context, state) {
        if (state is MaterialAnalyticsLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            ),
          );
        }

        if (state is MaterialAnalyticsError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      FluentIcons.error_circle_24_regular,
                      size: 40,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load data',
                    style: AppTextStyles.h5.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.read<MaterialAnalyticsBloc>().add(
                      const RefreshAnalytics(),
                    ),
                    icon: const Icon(
                      FluentIcons.arrow_clockwise_24_regular,
                      size: 18,
                    ),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is MaterialAnalyticsLoaded) {
          // Show empty state if no materials
          if (state.materials.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        FluentIcons.box_24_regular,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No data available',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Materials data will appear here once\nyou have purchases and sales.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<MaterialAnalyticsBloc>().add(
                const RefreshAnalytics(),
              );
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Material Performance',
                              style: AppTextStyles.h3.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: _showDateFilterMenu,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(alpha: 
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      FluentIcons.calendar_ltr_24_regular,
                                      size: 12,
                                      color: AppColors.primaryGreen,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${DateFormat('MMM d').format(state.startDate)} – ${DateFormat('MMM d, yyyy').format(state.endDate)}',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Icon(
                                      FluentIcons.chevron_down_24_regular,
                                      size: 14,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _exportToCsv(state),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            FluentIcons.arrow_download_24_regular,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacing24),
                  AnalyticsSummaryCards(
                    totalPurchases: state.summaryTotals['totalPurchases'] ?? 0,
                    totalSales: state.summaryTotals['totalSales'] ?? 0,
                    totalInventory: state.summaryTotals['totalInventory'] ?? 0,
                    netProfit: state.summaryTotals['netProfit'] ?? 0,
                  ),
                  const SizedBox(height: AppDimensions.spacing24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search materials...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: Icon(
                          FluentIcons.search_24_regular,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: state.searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  context.read<MaterialAnalyticsBloc>().add(
                                    const SearchMaterials(''),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    FluentIcons.dismiss_circle_24_regular,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (value) {
                        context.read<MaterialAnalyticsBloc>().add(
                          SearchMaterials(value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),
                  MaterialAnalyticsTable(
                    materials: state.filteredMaterials,
                    onSort: (sortBy, ascending) {
                      context.read<MaterialAnalyticsBloc>().add(
                        SortMaterials(sortBy: sortBy, ascending: ascending),
                      );
                    },
                    currentSortBy: state.sortBy,
                    currentSortAscending: state.sortAscending,
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
