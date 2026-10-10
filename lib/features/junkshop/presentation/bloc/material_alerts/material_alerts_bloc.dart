import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/material_analytics_service.dart';
import 'material_alerts_event.dart';
import 'material_alerts_state.dart';

class MaterialAlertsBloc
    extends Bloc<MaterialAlertsEvent, MaterialAlertsState> {
  final MaterialAnalyticsService _analyticsService;
  final Set<String> _dismissedAlerts = {};

  MaterialAlertsBloc({required MaterialAnalyticsService analyticsService})
    : _analyticsService = analyticsService,
      super(MaterialAlertsInitial()) {
    on<LoadMaterialAlerts>(_onLoadMaterialAlerts);
    on<DismissAlert>(_onDismissAlert);
    on<ClearAllAlerts>(_onClearAllAlerts);
  }

  Future<void> _onLoadMaterialAlerts(
    LoadMaterialAlerts event,
    Emitter<MaterialAlertsState> emit,
  ) async {
    emit(MaterialAlertsLoading());

    try {
      final materials = await _analyticsService.getMaterialAnalytics(
        junkshopId: event.junkshopId,
      );

      final alerts = <MaterialAlert>[];
      int stagnantCount = 0;
      int slowMovingCount = 0;

      for (final material in materials) {
        // Skip dismissed alerts
        if (_dismissedAlerts.contains(material.materialName)) continue;

        // Only create alerts for materials with issues
        if (material.status == 'Stagnant' || material.status == 'Slow') {
          final daysSinceLastSale = material.lastSaleDate != null
              ? DateTime.now().difference(material.lastSaleDate!).inDays
              : 999;

          AlertSeverity severity;
          if (material.status == 'Stagnant') {
            severity = AlertSeverity.critical;
            stagnantCount++;
          } else {
            severity = AlertSeverity.warning;
            slowMovingCount++;
          }

          alerts.add(
            MaterialAlert(
              materialName: material.materialName,
              status: material.status,
              daysSinceLastSale: daysSinceLastSale,
              currentStock: material.currentStock,
              unit: material.unit,
              severity: severity,
            ),
          );
        }
      }

      // Sort by severity (critical first) then by days since last sale
      alerts.sort((a, b) {
        if (a.severity != b.severity) {
          return a.severity.index.compareTo(b.severity.index);
        }
        return b.daysSinceLastSale.compareTo(a.daysSinceLastSale);
      });

      emit(
        MaterialAlertsLoaded(
          alerts: alerts,
          stagnantCount: stagnantCount,
          slowMovingCount: slowMovingCount,
        ),
      );
    } catch (e) {
      emit(MaterialAlertsError(e.toString()));
    }
  }

  void _onDismissAlert(DismissAlert event, Emitter<MaterialAlertsState> emit) {
    _dismissedAlerts.add(event.materialName);

    if (state is MaterialAlertsLoaded) {
      final currentState = state as MaterialAlertsLoaded;
      final updatedAlerts = currentState.alerts
          .where((alert) => alert.materialName != event.materialName)
          .toList();

      emit(
        MaterialAlertsLoaded(
          alerts: updatedAlerts,
          stagnantCount: updatedAlerts
              .where((a) => a.severity == AlertSeverity.critical)
              .length,
          slowMovingCount: updatedAlerts
              .where((a) => a.severity == AlertSeverity.warning)
              .length,
        ),
      );
    }
  }

  void _onClearAllAlerts(
    ClearAllAlerts event,
    Emitter<MaterialAlertsState> emit,
  ) {
    _dismissedAlerts.clear();
    emit(MaterialAlertsInitial());
  }
}
