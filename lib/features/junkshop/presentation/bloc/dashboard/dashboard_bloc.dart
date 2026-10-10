import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class DashboardEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class DashboardInitialized extends DashboardEvent {}

// States
abstract class DashboardState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoaded extends DashboardState {}

// BLoC
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardInitialized>(_onDashboardInitialized);
  }

  void _onDashboardInitialized(
    DashboardInitialized event,
    Emitter<DashboardState> emit,
  ) {
    emit(DashboardLoaded());
  }
}
