import 'package:equatable/equatable.dart';

abstract class CollectorProfileState extends Equatable {
  const CollectorProfileState();

  @override
  List<Object?> get props => [];
}

class CollectorProfileInitial extends CollectorProfileState {
  const CollectorProfileInitial();
}

class CollectorProfileLoading extends CollectorProfileState {
  const CollectorProfileLoading();
}

class CollectorProfileLoaded extends CollectorProfileState {
  final Map<String, dynamic> profileData;

  const CollectorProfileLoaded({required this.profileData});

  @override
  List<Object?> get props => [profileData];
}

class CollectorProfileError extends CollectorProfileState {
  final String message;

  const CollectorProfileError({required this.message});

  @override
  List<Object?> get props => [message];
}
