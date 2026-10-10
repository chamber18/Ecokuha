import 'package:equatable/equatable.dart';

abstract class CollectorProfileEvent extends Equatable {
  const CollectorProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadCollectorProfileEvent extends CollectorProfileEvent {
  const LoadCollectorProfileEvent();
}

class RefreshCollectorProfileEvent extends CollectorProfileEvent {
  const RefreshCollectorProfileEvent();
}

class UpdateCollectorProfileEvent extends CollectorProfileEvent {
  final Map<String, dynamic> updates;

  const UpdateCollectorProfileEvent(this.updates);

  @override
  List<Object?> get props => [updates];
}
