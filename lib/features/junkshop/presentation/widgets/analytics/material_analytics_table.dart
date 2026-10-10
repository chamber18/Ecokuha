import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../../data/services/material_analytics_service.dart';
import '../../bloc/material_analytics/material_analytics_bloc.dart';

class MaterialAnalyticsTable extends StatefulWidget {
  final List<MaterialMetrics> materials;
  final Function(String sortBy, bool ascending) onSort;
  final String currentSortBy;
  final bool currentSortAscending;

  const MaterialAnalyticsTable({
    super.key,
    required this.materials,
    required this.onSort,
    required this.currentSortBy,
    required this.currentSortAscending,
  });

  @override
  State<MaterialAnalyticsTable> createState() => _MaterialAnalyticsTableState();
}

class _MaterialAnalyticsTableState extends State<MaterialAnalyticsTable> {
  String? _expandedMaterialId;
  int _currentPage = 0;
  static const int _itemsPerPage = 20;

  int get _totalPages => (widget.materials.length / _itemsPerPage).ceil();

  List<MaterialMetrics> get _paginatedMaterials {
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, widget.materials.length);
    return widget.materials.sublist(start, end);
  }

  @override
  void didUpdateWidget(MaterialAnalyticsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset to first page if materials list changed
    if (oldWidget.materials.length != widget.materials.length) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.materials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppDimensions.spacing16),
              Text(
                'No materials found',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Sort options
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sort, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Sort by',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSortChip('Material', 'materialName'),
                    const SizedBox(width: 8),
                    _buildSortChip('Stock', 'currentStock'),
                    const SizedBox(width: 8),
                    _buildSortChip('Profit', 'profit'),
                    const SizedBox(width: 8),
                    _buildSortChip('Status', 'status'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        // Materials list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _paginatedMaterials.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppDimensions.spacing8),
          itemBuilder: (context, index) {
            final material = _paginatedMaterials[index];
            final isExpanded = _expandedMaterialId == material.materialName;

            return _buildMaterialCard(material, isExpanded);
          },
        ),
        if (_totalPages > 1) ...[
          const SizedBox(height: AppDimensions.spacing16),
          _buildPaginationControls(),
        ],
      ],
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${_currentPage * _itemsPerPage + 1}-${((_currentPage + 1) * _itemsPerPage).clamp(0, widget.materials.length)} of ${widget.materials.length}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
              ),
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: AppTextStyles.bodySmall,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages - 1
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String sortBy) {
    final isSelected = widget.currentSortBy == sortBy;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 4),
            Icon(
              widget.currentSortAscending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 14,
              color: Colors.white,
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        widget.onSort(sortBy, isSelected ? !widget.currentSortAscending : true);
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: AppColors.primaryGreen,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildMaterialCard(MaterialMetrics material, bool isExpanded) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to detail screen with BLoC instance
            Navigator.pushNamed(
              context,
              '/junkshop/analytics/material-detail',
              arguments: {
                'materialName': material.materialName,
                'bloc': context.read<MaterialAnalyticsBloc>(),
              },
            );
          },
          onLongPress: () {
            // Long press to expand/collapse
            setState(() {
              _expandedMaterialId = isExpanded ? null : material.materialName;
            });
          },
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.materialName,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stock: ${Formatters.formatWeight(material.currentStock, unit: material.unit ?? 'kg')}  •  ${Formatters.formatCurrency(material.stockValue)}',
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
                        Text(
                          Formatters.formatCurrency(material.netProfit),
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: material.netProfit >= 0
                                ? AppColors.primaryGreen
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Net Profit',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Expanded details
                if (isExpanded) ...[
                  const SizedBox(height: AppDimensions.spacing16),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: AppDimensions.spacing16),
                  _buildDetailRow(
                    'Purchases',
                    '${Formatters.formatWeight(material.purchaseData.totalWeight, unit: material.unit ?? 'kg')} • ${Formatters.formatCurrency(material.purchaseData.totalCost)}',
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  _buildDetailRow(
                    'Sales',
                    '${Formatters.formatWeight(material.salesData.totalWeight, unit: material.unit ?? 'kg')} • ${Formatters.formatCurrency(material.salesData.totalRevenue)}',
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  _buildDetailRow(
                    'Profit Margin',
                    '${material.profitMargin.toStringAsFixed(1)}%',
                    valueColor: material.profitMargin >= 0
                        ? AppColors.primaryGreen
                        : Colors.red,
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  _buildDetailRow(
                    'Stock Value',
                    Formatters.formatCurrency(material.stockValue),
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  _buildDetailRow(
                    'Last Sale',
                    material.lastSaleDate != null
                        ? Formatters.formatDate(material.lastSaleDate!)
                        : 'Never',
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricBox(
                          'Avg Purchase',
                          Formatters.formatCurrency(
                            material.purchaseData.avgPricePerUnit,
                          ),
                          Icons.shopping_cart,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricBox(
                          'Avg Sales',
                          Formatters.formatCurrency(
                            material.salesData.avgPricePerUnit,
                          ),
                          Icons.point_of_sale,
                          AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'Active':
        color = AppColors.primaryGreen;
        icon = Icons.check_circle;
        break;
      case 'Slow':
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case 'Stagnant':
        color = Colors.red;
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
