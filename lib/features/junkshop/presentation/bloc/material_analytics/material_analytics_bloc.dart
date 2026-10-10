import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/material_analytics_service.dart';
import 'material_analytics_event.dart';
import 'material_analytics_state.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class MaterialAnalyticsBloc
    extends Bloc<MaterialAnalyticsEvent, MaterialAnalyticsState> {
  final MaterialAnalyticsService _analyticsService;
  final SupabaseClient _db;

  MaterialAnalyticsBloc({
    required MaterialAnalyticsService analyticsService,
    SupabaseClient? supabase,
  }) : _analyticsService = analyticsService,
       _db = supabase ?? Supabase.instance.client,
       super(const MaterialAnalyticsInitial()) {
    on<LoadMaterialAnalytics>(_onLoadMaterialAnalytics);
    on<FilterByDateRange>(_onFilterByDateRange);
    on<SearchMaterials>(_onSearchMaterials);
    on<SortMaterials>(_onSortMaterials);
    on<RefreshAnalytics>(_onRefreshAnalytics);
    on<SelectDatePreset>(_onSelectDatePreset);
  }

  Future<void> _onLoadMaterialAnalytics(
    LoadMaterialAnalytics event,
    Emitter<MaterialAnalyticsState> emit,
  ) async {
    try {
      emit(const MaterialAnalyticsLoading());

      final user = _db.auth.currentUser;
      if (user == null) {
        emit(const MaterialAnalyticsError('User not authenticated'));
        return;
      }

      final now = DateTime.now();
      // Default to last 30 days
      final startDate =
          event.startDate ?? now.subtract(const Duration(days: 30));
      final endDate = event.endDate ?? now;

      if (kDebugMode) print('📅 Using date range: $startDate to $endDate');

      final materials = await _analyticsService.getMaterialAnalytics(
        junkshopId: user.id,
        startDate: startDate,
        endDate: endDate,
        // Force fresh data on initial load (no date filter) so cached
        // data from the old 30-day default doesn't shadow the 12-month range
        forceRefresh: event.startDate == null,
      );

      final summaryTotals = await _analyticsService.getSummaryTotals(
        junkshopId: user.id,
        startDate: startDate,
        endDate: endDate,
      );

      emit(
        MaterialAnalyticsLoaded(
          materials: materials,
          filteredMaterials: materials,
          summaryTotals: summaryTotals,
          startDate: startDate,
          endDate: endDate,
        ),
      );
    } catch (e) {
      emit(MaterialAnalyticsError('Failed to load analytics: $e'));
    }
  }

  Future<void> _onFilterByDateRange(
    FilterByDateRange event,
    Emitter<MaterialAnalyticsState> emit,
  ) async {
    try {
      emit(const MaterialAnalyticsLoading());

      final user = _db.auth.currentUser;
      if (user == null) {
        emit(const MaterialAnalyticsError('User not authenticated'));
        return;
      }

      final materials = await _analyticsService.getMaterialAnalytics(
        junkshopId: user.id,
        startDate: event.startDate,
        endDate: event.endDate,
        forceRefresh: true,
      );

      final summaryTotals = await _analyticsService.getSummaryTotals(
        junkshopId: user.id,
        startDate: event.startDate,
        endDate: event.endDate,
      );

      emit(
        MaterialAnalyticsLoaded(
          materials: materials,
          filteredMaterials: materials,
          summaryTotals: summaryTotals,
          startDate: event.startDate,
          endDate: event.endDate,
        ),
      );
    } catch (e) {
      emit(MaterialAnalyticsError('Failed to filter by date range: $e'));
    }
  }

  void _onSearchMaterials(
    SearchMaterials event,
    Emitter<MaterialAnalyticsState> emit,
  ) {
    final currentState = state;
    if (currentState is! MaterialAnalyticsLoaded) return;

    final query = event.query.toLowerCase();

    if (query.isEmpty) {
      emit(
        currentState.copyWith(
          filteredMaterials: currentState.materials,
          searchQuery: '',
        ),
      );
      return;
    }

    final filtered = currentState.materials.where((material) {
      return material.materialName.toLowerCase().contains(query);
    }).toList();

    emit(
      currentState.copyWith(
        filteredMaterials: filtered,
        searchQuery: event.query,
      ),
    );
  }

  void _onSortMaterials(
    SortMaterials event,
    Emitter<MaterialAnalyticsState> emit,
  ) {
    final currentState = state;
    if (currentState is! MaterialAnalyticsLoaded) return;

    final sorted = List<MaterialMetrics>.from(currentState.filteredMaterials);

    sorted.sort((a, b) {
      int comparison;

      switch (event.sortBy) {
        case 'materialName':
          comparison = a.materialName.compareTo(b.materialName);
          break;
        case 'currentStock':
          comparison = a.currentStock.compareTo(b.currentStock);
          break;
        case 'purchases':
          comparison = a.purchaseData.totalWeight.compareTo(
            b.purchaseData.totalWeight,
          );
          break;
        case 'sales':
          comparison = a.salesData.totalWeight.compareTo(
            b.salesData.totalWeight,
          );
          break;
        case 'profit':
          comparison = a.netProfit.compareTo(b.netProfit);
          break;
        case 'margin':
          comparison = a.profitMargin.compareTo(b.profitMargin);
          break;
        case 'stockValue':
          comparison = a.stockValue.compareTo(b.stockValue);
          break;
        case 'status':
          comparison = a.status.compareTo(b.status);
          break;
        default:
          comparison = 0;
      }

      return event.ascending ? comparison : -comparison;
    });

    emit(
      currentState.copyWith(
        filteredMaterials: sorted,
        sortBy: event.sortBy,
        sortAscending: event.ascending,
      ),
    );
  }

  Future<void> _onRefreshAnalytics(
    RefreshAnalytics event,
    Emitter<MaterialAnalyticsState> emit,
  ) async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) {
        emit(const MaterialAnalyticsError('User not authenticated'));
        return;
      }

      final currentState = state;
      DateTime startDate;
      DateTime endDate;

      if (currentState is MaterialAnalyticsLoaded) {
        startDate = currentState.startDate;
        endDate = currentState.endDate;
      } else {
        final now = DateTime.now();
        startDate = DateTime(now.year - 1, now.month, now.day);
        endDate = now;
      }

      // Force refresh from the database, bypassing cache
      final materials = await _analyticsService.getMaterialAnalytics(
        junkshopId: user.id,
        startDate: startDate,
        endDate: endDate,
        forceRefresh: true,
      );

      final summaryTotals = await _analyticsService.getSummaryTotals(
        junkshopId: user.id,
        startDate: startDate,
        endDate: endDate,
      );

      emit(
        MaterialAnalyticsLoaded(
          materials: materials,
          filteredMaterials: materials,
          summaryTotals: summaryTotals,
          startDate: startDate,
          endDate: endDate,
        ),
      );
    } catch (e) {
      emit(MaterialAnalyticsError('Failed to refresh analytics: $e'));
    }
  }

  Future<void> _onSelectDatePreset(
    SelectDatePreset event,
    Emitter<MaterialAnalyticsState> emit,
  ) async {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (event.preset) {
      case DateRangePreset.last30Days:
        startDate = now.subtract(const Duration(days: 30));
        break;
      case DateRangePreset.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case DateRangePreset.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = lastMonth;
        endDate = DateTime(
          now.year,
          now.month,
          1,
        ).subtract(const Duration(days: 1));
        break;
      case DateRangePreset.last3Months:
        startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case DateRangePreset.last6Months:
        startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case DateRangePreset.last12Months:
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case DateRangePreset.customMonth:
        if (event.customDate != null) {
          startDate = DateTime(
            event.customDate!.year,
            event.customDate!.month,
            1,
          );
          endDate = DateTime(
            event.customDate!.year,
            event.customDate!.month + 1,
            1,
          ).subtract(const Duration(days: 1));
        } else {
          return;
        }
        break;
      case DateRangePreset.customYear:
        if (event.customDate != null) {
          startDate = DateTime(event.customDate!.year, 1, 1);
          endDate = DateTime(event.customDate!.year, 12, 31);
        } else {
          return;
        }
        break;
      case DateRangePreset.custom:
        return;
    }

    try {
      emit(const MaterialAnalyticsLoading());

      final user = _db.auth.currentUser;
      if (user == null) {
        emit(const MaterialAnalyticsError('User not authenticated'));
        return;
      }

      final materials = await _analyticsService.getMaterialAnalytics(
        junkshopId: user.id,
        startDate: startDate,
        endDate: endDate,
        forceRefresh: true,
      );

      final summaryTotals = await _analyticsService.getSummaryTotals(
        junkshopId: user.id,
        startDate: startDate,
        endDate: endDate,
      );

      emit(
        MaterialAnalyticsLoaded(
          materials: materials,
          filteredMaterials: materials,
          summaryTotals: summaryTotals,
          startDate: startDate,
          endDate: endDate,
          selectedPreset: event.preset,
        ),
      );
    } catch (e) {
      emit(MaterialAnalyticsError('Failed to load analytics: $e'));
    }
  }
}
