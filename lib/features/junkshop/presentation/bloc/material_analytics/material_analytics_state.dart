import 'package:equatable/equatable.dart';
import '../../../data/services/material_analytics_service.dart';

enum DateRangePreset {
  last30Days,
  thisMonth,
  lastMonth,
  last3Months,
  last6Months,
  last12Months,
  customMonth,
  customYear,
  custom,
}

extension DateRangePresetExtension on DateRangePreset {
  String get label {
    switch (this) {
      case DateRangePreset.last30Days:
        return 'Last 30 Days';
      case DateRangePreset.thisMonth:
        return 'This Month';
      case DateRangePreset.lastMonth:
        return 'Last Month';
      case DateRangePreset.last3Months:
        return 'Last 3 Months';
      case DateRangePreset.last6Months:
        return 'Last 6 Months';
      case DateRangePreset.last12Months:
        return 'Last 12 Months';
      case DateRangePreset.customMonth:
        return 'Select Month';
      case DateRangePreset.customYear:
        return 'Select Year';
      case DateRangePreset.custom:
        return 'Custom Range';
    }
  }
}

abstract class MaterialAnalyticsState extends Equatable {
  const MaterialAnalyticsState();

  @override
  List<Object?> get props => [];
}

class MaterialAnalyticsInitial extends MaterialAnalyticsState {
  const MaterialAnalyticsInitial();
}

class MaterialAnalyticsLoading extends MaterialAnalyticsState {
  const MaterialAnalyticsLoading();
}

class MaterialAnalyticsLoaded extends MaterialAnalyticsState {
  final List<MaterialMetrics> materials;
  final List<MaterialMetrics> filteredMaterials;
  final Map<String, double> summaryTotals;
  final DateTime startDate;
  final DateTime endDate;
  final DateRangePreset selectedPreset;
  final String searchQuery;
  final String sortBy;
  final bool sortAscending;

  const MaterialAnalyticsLoaded({
    required this.materials,
    required this.filteredMaterials,
    required this.summaryTotals,
    required this.startDate,
    required this.endDate,
    this.selectedPreset = DateRangePreset.last30Days,
    this.searchQuery = '',
    this.sortBy = 'materialName',
    this.sortAscending = true,
  });

  @override
  List<Object?> get props => [
    materials,
    filteredMaterials,
    summaryTotals,
    startDate,
    endDate,
    selectedPreset,
    searchQuery,
    sortBy,
    sortAscending,
  ];

  MaterialAnalyticsLoaded copyWith({
    List<MaterialMetrics>? materials,
    List<MaterialMetrics>? filteredMaterials,
    Map<String, double>? summaryTotals,
    DateTime? startDate,
    DateTime? endDate,
    DateRangePreset? selectedPreset,
    String? searchQuery,
    String? sortBy,
    bool? sortAscending,
  }) {
    return MaterialAnalyticsLoaded(
      materials: materials ?? this.materials,
      filteredMaterials: filteredMaterials ?? this.filteredMaterials,
      summaryTotals: summaryTotals ?? this.summaryTotals,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      selectedPreset: selectedPreset ?? this.selectedPreset,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

class MaterialAnalyticsError extends MaterialAnalyticsState {
  final String message;

  const MaterialAnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}
