import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfileEvent extends ProfileEvent {
  const LoadProfileEvent();
}

class RefreshProfileEvent extends ProfileEvent {
  const RefreshProfileEvent();
}

class UpdateProfileEvent extends ProfileEvent {
  final Map<String, dynamic> updates;

  const UpdateProfileEvent({required this.updates});

  @override
  List<Object?> get props => [updates];
}
