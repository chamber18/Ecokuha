import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/utils/user_collection_helper.dart';

import 'collector_profile_event.dart';
import 'collector_profile_state.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class CollectorProfileBloc
    extends Bloc<CollectorProfileEvent, CollectorProfileState> {
  final SupabaseClient _supabase;

  CollectorProfileBloc({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client,
      super(const CollectorProfileInitial()) {
    on<LoadCollectorProfileEvent>(_onLoadProfile);
    on<RefreshCollectorProfileEvent>(_onRefreshProfile);
    on<UpdateCollectorProfileEvent>(_onUpdateProfile);
  }

  Future<void> _onLoadProfile(
    LoadCollectorProfileEvent event,
    Emitter<CollectorProfileState> emit,
  ) async {
    emit(const CollectorProfileLoading());
    await _fetchProfile(emit);
  }

  Future<void> _onRefreshProfile(
    RefreshCollectorProfileEvent event,
    Emitter<CollectorProfileState> emit,
  ) async {
    await _fetchProfile(emit);
  }

  Future<void> _onUpdateProfile(
    UpdateCollectorProfileEvent event,
    Emitter<CollectorProfileState> emit,
  ) async {
    try {
      final User? user = _supabase.auth.currentUser;
      if (user == null) {
        emit(
          const CollectorProfileError(
            message: 'No user is currently signed in',
          ),
        );
        return;
      }

      await UserCollectionHelper.getUserDocument(
        user.id,
        'collector',
      ).update(event.updates);
      await _fetchProfile(emit);
    } catch (e) {
      emit(
        CollectorProfileError(
          message: 'Failed to update profile: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _fetchProfile(Emitter<CollectorProfileState> emit) async {
    try {
      final User? user = _supabase.auth.currentUser;
      if (user == null) {
        emit(
          const CollectorProfileError(
            message: 'No user is currently signed in',
          ),
        );
        return;
      }

      final doc = await UserCollectionHelper.getUserDocument(
        user.id,
        'collector',
      ).get();
      if (doc == null) {
        emit(const CollectorProfileError(message: 'User profile not found'));
        return;
      }

      final profileData = Map<String, dynamic>.from(doc);

      // Fetch and calculate stats
      try {
        // Rating is maintained by a DB trigger on the collectors row
        profileData['rating'] =
            (profileData['averageRating'] as num?)?.toDouble() ??
            (profileData['rating'] as num?)?.toDouble() ??
            0.0;
        // Merge assigned junkshop ID so the profile screen can display the partner
        final junkshopId =
            profileData['preferred_junkshop_id']?.toString() ??
            profileData['assigned_junkshop_id']?.toString() ??
            profileData['assignedJunkshopId']?.toString() ??
            '';
        if (junkshopId.isNotEmpty) {
          profileData['assigned_junkshop_id'] = junkshopId;
        }

        // Count total completed collections
        final completedPostings = await _supabase
            .from('postings')
            .select('id, purchased_items, verified_items')
            .eq('status', 'completed')
            .eq('collector_id', user.id);

        profileData['totalCollections'] = completedPostings.length;

        // Calculate total commission earned from completed postings
        // Commission = What junkshop paid (purchasedItems.total) - What collector paid to household (verifiedItems.totalValue)
        double totalCommission = 0.0;
        try {
          if (kDebugMode) {
            print(
              '=== Calculating Total Commission for collector: ${user.id} ===',
            );
          }
          if (kDebugMode) print('Total completed postings: ${completedPostings.length}');

          for (final data in completedPostings) {
            double junkshopPayment = 0.0; // What junkshop paid to collector
            double collectorCost = 0.0; // What collector paid to household

            // Get junkshop payment (purchasedItems.total)
            if (data['purchased_items'] != null &&
                data['purchased_items'] is Map) {
              final purchasedItems =
                  Map<String, dynamic>.from(data['purchased_items'] as Map);
              junkshopPayment =
                  (purchasedItems['total'] as num?)?.toDouble() ?? 0.0;
            }

            // Get collector's cost (verifiedItems.totalValue)
            if (data['verified_items'] != null) {
              if (data['verified_items'] is Map) {
                final verified = Map<String, dynamic>.from(data['verified_items'] as Map);
                collectorCost =
                    (verified['totalValue'] as num?)?.toDouble() ?? 0.0;
              }
            }

            // Calculate commission for this posting
            final postingCommission = junkshopPayment - collectorCost;

            if (postingCommission > 0 ||
                (junkshopPayment > 0 && collectorCost > 0)) {
              if (kDebugMode) {
                print(
                  '  Posting ${data['id']}: Junkshop paid ₱${junkshopPayment.toStringAsFixed(2)} - Collector paid ₱${collectorCost.toStringAsFixed(2)} = Commission ₱${postingCommission.toStringAsFixed(2)}',
                );
              }
              totalCommission += postingCommission;
            }
          }

          if (kDebugMode) {
            print(
              'Total commission earned: ₱${totalCommission.toStringAsFixed(2)}',
            );
          }
        } catch (e) {
          if (kDebugMode) print('Error calculating total commission: $e');
          if (kDebugMode) print('Stack trace: ${StackTrace.current}');
        }
        profileData['totalEarned'] = totalCommission;

        // Count currently assigned tasks
        final assignedPostings = await _supabase
            .from('postings')
            .select('id')
            .eq('collector_id', user.id)
            .inFilter('status', [
              'assigned',
              'in_transit',
              'arrived',
              'collecting',
              'in_progress',
            ]);
        profileData['assignedTasks'] = assignedPostings.length;
      } catch (e) {
        if (kDebugMode) print('Error fetching collector stats: $e');
        // Set defaults if stats fetch fails
        profileData['rating'] = 0.0;
        profileData['totalCollections'] = 0;
        profileData['totalEarned'] = 0.0;
        profileData['assignedTasks'] = 0;
      }

      emit(CollectorProfileLoaded(profileData: profileData));
    } catch (e) {
      emit(
        CollectorProfileError(
          message: 'Failed to load profile: ${e.toString()}',
        ),
      );
    }
  }
}
