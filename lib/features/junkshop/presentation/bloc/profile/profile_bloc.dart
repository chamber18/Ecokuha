import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/utils/user_collection_helper.dart';

import 'profile_event.dart';
import 'profile_state.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

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
        if (kDebugMode) print('ProfileBloc: No user signed in');
        emit(const ProfileError(message: 'No user is currently signed in'));
        return;
      }

      if (kDebugMode) print('ProfileBloc: Updating profile for user ${user.id}');
      if (kDebugMode) print('ProfileBloc: Update data: ${event.profileData}');

      // Deep-merge so nested jsonb updates (junkshop_profile, settings) keep
      // their other keys, like Firestore set(merge: true) did.
      await UserCollectionHelper.getUserDocument(
        user.id,
        'junkshop',
      ).set(event.profileData, merge: true);

      if (kDebugMode) print('ProfileBloc: Update successful');

      await _fetchProfile(emit);
    } catch (e, stackTrace) {
      if (kDebugMode) print('ProfileBloc: Update failed: $e');
      if (kDebugMode) print('Stack trace: $stackTrace');
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
        'junkshop',
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
