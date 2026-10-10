import 'package:equatable/equatable.dart';

abstract class MaterialAlertsEvent extends Equatable {
  const MaterialAlertsEvent();

  @override
  List<Object?> get props => [];
}

/// Load material alerts for stagnant materials
class LoadMaterialAlerts extends MaterialAlertsEvent {
  final String junkshopId;

  const LoadMaterialAlerts(this.junkshopId);

  @override
  List<Object?> get props => [junkshopId];
}

/// Dismiss a specific material alert
class DismissAlert extends MaterialAlertsEvent {
  final String materialName;

  const DismissAlert(this.materialName);

  @override
  List<Object?> get props => [materialName];
}

/// Clear all alerts
class ClearAllAlerts extends MaterialAlertsEvent {
  const ClearAllAlerts();
}
