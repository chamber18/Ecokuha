import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class MaterialMultiSelector extends StatefulWidget {
  final List<String> availableMaterials;
  final List<String> selectedMaterials;
  final Function(List<String>) onSelectionChanged;
  final String? title;

  const MaterialMultiSelector({
    super.key,
    required this.availableMaterials,
    required this.selectedMaterials,
    required this.onSelectionChanged,
    this.title,
  });

  @override
  State<MaterialMultiSelector> createState() => _MaterialMultiSelectorState();
}

class _MaterialMultiSelectorState extends State<MaterialMultiSelector> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedMaterials);
  }

  void _toggleMaterial(String material) {
    setState(() {
      if (_selected.contains(material)) {
        _selected.remove(material);
      } else {
        _selected.add(material);
      }
      widget.onSelectionChanged(_selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
        ],
        if (_selected.isNotEmpty) ...[
          Text(
            '${_selected.length} selected',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.availableMaterials.map((material) {
            final isSelected = _selected.contains(material);
            return FilterChip(
              label: Text(material),
              selected: isSelected,
              onSelected: (_) => _toggleMaterial(material),
              selectedColor: AppColors.primaryGreen.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primaryGreen,
              labelStyle: AppTextStyles.bodyMedium.copyWith(
                color: isSelected
                    ? AppColors.primaryGreen
                    : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppColors.primaryGreen
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
