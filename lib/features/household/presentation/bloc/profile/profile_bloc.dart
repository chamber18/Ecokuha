import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/utils/user_collection_helper.dart';

import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final SupabaseClient _supabase;

  ProfileBloc({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client,
      super(const ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<RefreshProfileEvent>(_onRefreshProfile);
    on<UpdateProfileEvent>(_onUpdateProfile);
  }

  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    await _fetchProfile(emit);
  }

  Future<void> _onRefreshProfile(
    RefreshProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    await _fetchProfile(emit);
  }

  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final User? user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const ProfileError(message: 'No user is currently signed in'));
        return;
      }

      await UserCollectionHelper.getUserDocument(
        user.id,
        'household',
      ).update(event.updates);
      await _fetchProfile(emit);
    } catch (e) {
      emit(ProfileError(message: 'Failed to update profile: ${e.toString()}'));
    }
  }

  Future<void> _fetchProfile(Emitter<ProfileState> emit) async {
    try {
      final User? user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const ProfileError(message: 'No user is currently signed in'));
        return;
      }

      final profileData = await UserCollectionHelper.getUserDocument(
        user.id,
        'household',
      ).get();
      if (profileData == null) {
        emit(const ProfileError(message: 'User profile not found'));
        return;
      }

      emit(ProfileLoaded(profileData: profileData));
    } catch (e) {
      emit(ProfileError(message: 'Failed to load profile: ${e.toString()}'));
    }
  }
}
