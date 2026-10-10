import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class MaterialCategoryDropdown extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> materialsGroupedByCategory;
  final List<String> selectedMaterialIds;
  final Function(List<String>) onSelectionChanged;
  final bool isLoading;

  const MaterialCategoryDropdown({
    super.key,
    required this.materialsGroupedByCategory,
    required this.selectedMaterialIds,
    required this.onSelectionChanged,
    this.isLoading = false,
  });

  @override
  State<MaterialCategoryDropdown> createState() =>
      _MaterialCategoryDropdownState();
}

class _MaterialCategoryDropdownState extends State<MaterialCategoryDropdown> {
  String? _expandedCategory;


  String _formatCategoryName(String category) {
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }

  void _toggleMaterial(String materialId) {
    final currentSelection = List<String>.from(widget.selectedMaterialIds);
    if (currentSelection.contains(materialId)) {
      currentSelection.remove(materialId);
    } else {
      currentSelection.add(materialId);
    }
    widget.onSelectionChanged(currentSelection);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (widget.materialsGroupedByCategory.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No materials available',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add materials in your inventory first',
                style: AppTextStyles.caption.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: widget.materialsGroupedByCategory.keys.map((category) {
            final materials = widget.materialsGroupedByCategory[category]!;
            final isExpanded = _expandedCategory == category;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isExpanded
                      ? AppColors.primaryGreen.withValues(alpha: 0.3)
                      : Colors.grey[300]!,
                  width: 1,
                ),
                boxShadow: isExpanded
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _expandedCategory = isExpanded ? null : category;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? AppColors.primaryGreen.withValues(alpha: 0.05)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatCategoryName(category),
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isExpanded
                                    ? AppColors.primaryGreen
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isExpanded
                                  ? AppColors.primaryGreen
                                  : AppColors.primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${materials.length}',
                              style: AppTextStyles.caption.copyWith(
                                color: isExpanded
                                    ? Colors.white
                                    : AppColors.primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: isExpanded
                                ? AppColors.primaryGreen
                                : Colors.grey[600],
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: Column(
                        children: materials.asMap().entries.map((entry) {
                          final index = entry.key;
                          final material = entry.value;
                          final isSelected = widget.selectedMaterialIds
                              .contains(material['id']);
                          final isLastItem = index == materials.length - 1;

                          return InkWell(
                            onTap: () => _toggleMaterial(material['id']),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 8,
                              ),
                              margin: EdgeInsets.only(
                                bottom: isLastItem ? 0 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryGreen.withValues(alpha: 0.05)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primaryGreen
                                          : Colors.white,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primaryGreen
                                            : Colors.grey[400]!,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          material['name'],
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: AppColors.textPrimary,
                                                fontSize: 13,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.inventory_2,
                                              size: 11,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${material['stock'].toStringAsFixed(1)} ${material['unit']}',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    color: Colors.grey[600],
                                                    fontSize: 10,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Selected',
                                        style: AppTextStyles.caption.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        if (widget.selectedMaterialIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Selected Materials (${widget.selectedMaterialIds.length})',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.selectedMaterialIds.map((materialId) {
              final material = widget.materialsGroupedByCategory.values
                  .expand((list) => list)
                  .firstWhere((m) => m['id'] == materialId);

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      material['name'],
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _toggleMaterial(materialId),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
