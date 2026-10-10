import 'package:equatable/equatable.dart';
import 'material_analytics_state.dart';

abstract class MaterialAnalyticsEvent extends Equatable {
  const MaterialAnalyticsEvent();

  @override
  List<Object?> get props => [];
}

class LoadMaterialAnalytics extends MaterialAnalyticsEvent {
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadMaterialAnalytics({this.startDate, this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

class FilterByDateRange extends MaterialAnalyticsEvent {
  final DateTime startDate;
  final DateTime endDate;

  const FilterByDateRange({required this.startDate, required this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

class SearchMaterials extends MaterialAnalyticsEvent {
  final String query;

  const SearchMaterials(this.query);

  @override
  List<Object?> get props => [query];
}

class SortMaterials extends MaterialAnalyticsEvent {
  final String sortBy;
  final bool ascending;

  const SortMaterials({required this.sortBy, required this.ascending});

  @override
  List<Object?> get props => [sortBy, ascending];
}

class RefreshAnalytics extends MaterialAnalyticsEvent {
  const RefreshAnalytics();
}

class SelectDatePreset extends MaterialAnalyticsEvent {
  final DateRangePreset preset;
  final DateTime? customDate;

  const SelectDatePreset(this.preset, {this.customDate});

  @override
  List<Object?> get props => [preset, customDate];
}
