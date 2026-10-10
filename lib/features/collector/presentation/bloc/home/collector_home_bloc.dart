import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class CollectorHomeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CollectorHomeInitialized extends CollectorHomeEvent {}

// States
abstract class CollectorHomeState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CollectorHomeInitial extends CollectorHomeState {}

class CollectorHomeLoaded extends CollectorHomeState {}

// BLoC
class CollectorHomeBloc extends Bloc<CollectorHomeEvent, CollectorHomeState> {
  CollectorHomeBloc() : super(CollectorHomeInitial()) {
    on<CollectorHomeInitialized>(_onCollectorHomeInitialized);
  }

  void _onCollectorHomeInitialized(
    CollectorHomeInitialized event,
    Emitter<CollectorHomeState> emit,
  ) {
    emit(CollectorHomeLoaded());
  }
}
