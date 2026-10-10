import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Service for real-time location tracking during active collections
/// (writes to the `active_collections` table, keyed by posting id).
class LocationTrackingService {
  final SupabaseClient _db;
  StreamSubscription<Position>? _locationSubscription;
  String? _activePostingId;

  LocationTrackingService({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  /// Start tracking when collector accepts/starts collection
  Future<void> startTracking({
    required String postingId,
    required String collectorId,
    required String collectorName,
    required String collectorPhoto,
    required String householdId,
    required double destinationLat,
    required double destinationLng,
    required String destinationAddress,
  }) async {
    _activePostingId = postingId;

    if (kDebugMode) {
      print('📍 [TRACKING] Starting tracking for posting: $postingId');
    }

    // Get current position immediately before creating document
    Position? initialPosition;
    try {
      if (kDebugMode) print('📍 [TRACKING] Getting initial GPS position...');
      initialPosition =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              if (kDebugMode) {
                print('⚠️ GPS timeout - will retry with last known position');
              }
              throw TimeoutException('GPS timeout');
            },
          );
      if (kDebugMode) {
        print(
          '✅ [TRACKING] Got initial position: ${initialPosition.latitude}, ${initialPosition.longitude}',
        );
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to get initial GPS position: $e');
      // Try last known position as fallback
      try {
        initialPosition = await Geolocator.getLastKnownPosition();
        if (initialPosition != null) {
          if (kDebugMode) {
            print(
              '✅ [TRACKING] Using last known position: ${initialPosition.latitude}, ${initialPosition.longitude}',
            );
          }
        }
      } catch (e2) {
        if (kDebugMode) print('❌ Failed to get last known position: $e2');
      }
    }

    // Calculate initial distance and ETA if we have position
    double? initialDistance;
    String? initialETA;
    Map<String, dynamic>? initialLocation;

    if (initialPosition != null) {
      initialDistance =
          Geolocator.distanceBetween(
            initialPosition.latitude,
            initialPosition.longitude,
            destinationLat,
            destinationLng,
          ) /
          1000; // Convert to km

      final etaMinutes = (initialDistance / 20 * 60).round();
      initialETA = DateTime.now()
          .add(Duration(minutes: etaMinutes))
          .toUtc()
          .toIso8601String();

      initialLocation = {
        'lat': initialPosition.latitude,
        'lng': initialPosition.longitude,
        'accuracy': initialPosition.accuracy,
        'timestamp': _nowIso(),
      };

      if (kDebugMode) {
        print(
          '📍 [TRACKING] Initial distance: ${initialDistance.toStringAsFixed(2)} km, ETA: $etaMinutes min',
        );
      }
    } else {
      if (kDebugMode) {
        print(
          '⚠️ [TRACKING] No initial position available - household will see loading state until GPS updates',
        );
      }
    }

    // Create initial tracking document with currentLocation if available
    final docData = <String, dynamic>{
      'posting_id': postingId,
      'collector_id': collectorId,
      'collector_name': collectorName,
      'collector_photo': collectorPhoto,
      'household_id': householdId,
      'status': 'en_route',
      'destination': {
        'lat': destinationLat,
        'lng': destinationLng,
        'address': destinationAddress,
      },
      'started_at': _nowIso(),
      'updated_at': _nowIso(),
      'is_active': true,
    };

    if (initialLocation != null) {
      docData['current_location'] = initialLocation;
      if (initialDistance != null) {
        docData['distance_remaining'] = initialDistance;
      }
      if (initialETA != null) {
        docData['estimated_arrival'] = initialETA;
      }
      if (kDebugMode) {
        print(
          '✅ [TRACKING] Creating activeCollections doc WITH initial location',
        );
      }
    } else {
      if (kDebugMode) {
        print(
          '⚠️ [TRACKING] Creating activeCollections doc WITHOUT initial location',
        );
      }
    }

    await _db.from('active_collections').upsert(docData);
    if (kDebugMode) {
      print('✅ [TRACKING] activeCollections document created for $postingId');
    }

    // Start listening to location updates
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _updateLocation(position, destinationLat, destinationLng);
          },
        );
  }

  /// Update location in Firestore
  Future<void> _updateLocation(
    Position position,
    double destLat,
    double destLng,
  ) async {
    if (_activePostingId == null) return;

    // Calculate distance to destination
    final distanceRemaining =
        Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destLat,
          destLng,
        ) /
        1000; // Convert to km

    // Calculate ETA (assume 20 km/h average speed in urban areas)
    final etaMinutes = (distanceRemaining / 20 * 60).round();
    final estimatedArrival = DateTime.now().add(Duration(minutes: etaMinutes));

    try {
      await _db
          .from('active_collections')
          .update({
            'current_location': {
              'lat': position.latitude,
              'lng': position.longitude,
              'accuracy': position.accuracy,
              'timestamp': _nowIso(),
            },
            'distance_remaining': distanceRemaining,
            'estimated_arrival': estimatedArrival.toUtc().toIso8601String(),
            'updated_at': _nowIso(),
          })
          .eq('posting_id', _activePostingId!);
    } catch (e) {
      if (kDebugMode) print('Error updating location: $e');
    }
  }

  /// Update status (arrived, collecting, etc.)
  Future<void> updateStatus(String status) async {
    if (_activePostingId == null) return;

    try {
      await _db
          .from('active_collections')
          .update({'status': status, 'updated_at': _nowIso()})
          .eq('posting_id', _activePostingId!);
    } catch (e) {
      if (kDebugMode) print('Error updating status: $e');
    }
  }

  /// Stop tracking when collection is complete
  Future<void> stopTracking() async {
    await _locationSubscription?.cancel();

    if (_activePostingId != null) {
      try {
        // Delete the activeCollections document immediately since collection is completed
        await _db
            .from('active_collections')
            .delete()
            .eq('posting_id', _activePostingId!);

        if (kDebugMode) {
          print('✅ Deleted activeCollections document: $_activePostingId');
        }
      } catch (e) {
        if (kDebugMode) print('Error deleting tracking document: $e');
      }
    }

    _activePostingId = null;
  }

  /// Check if currently tracking
  bool get isTracking => _activePostingId != null;

  /// Get current tracking posting ID
  String? get activePostingId => _activePostingId;

  void dispose() {
    _locationSubscription?.cancel();
  }
}
