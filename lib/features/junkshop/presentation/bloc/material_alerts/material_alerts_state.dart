import 'package:equatable/equatable.dart';

abstract class MaterialAlertsState extends Equatable {
  const MaterialAlertsState();

  @override
  List<Object?> get props => [];
}

class MaterialAlertsInitial extends MaterialAlertsState {}

class MaterialAlertsLoading extends MaterialAlertsState {}

class MaterialAlertsLoaded extends MaterialAlertsState {
  final List<MaterialAlert> alerts;
  final int stagnantCount;
  final int slowMovingCount;

  const MaterialAlertsLoaded({
    required this.alerts,
    required this.stagnantCount,
    required this.slowMovingCount,
  });

  @override
  List<Object?> get props => [alerts, stagnantCount, slowMovingCount];
}

class MaterialAlertsError extends MaterialAlertsState {
  final String message;

  const MaterialAlertsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Material alert model
class MaterialAlert {
  final String materialName;
  final String status; // 'Stagnant' or 'Slow'
  final int daysSinceLastSale;
  final double currentStock;
  final String? unit;
  final AlertSeverity severity;

  const MaterialAlert({
    required this.materialName,
    required this.status,
    required this.daysSinceLastSale,
    required this.currentStock,
    this.unit,
    required this.severity,
  });
}

enum AlertSeverity {
  critical, // Stagnant (>30 days)
  warning, // Slow (7-30 days)
  info, // Active but worth monitoring
}
