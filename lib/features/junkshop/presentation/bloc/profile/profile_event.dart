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
  final Map<String, dynamic> profileData;

  const UpdateProfileEvent(this.profileData);

  @override
  List<Object?> get props => [profileData];
}
