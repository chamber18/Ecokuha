import 'dart:math' show pi, sin, cos, asin, sqrt;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/utils/app_image_provider.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_helpers.dart' hide supabase;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/posting_upload_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/repositories/household_posting_repository.dart';
import '../../../messaging/data/repositories/chat_repository.dart';
import '../../../messaging/data/models/conversation_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'household_dashboard.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final SupabaseClient _db = Supabase.instance.client;

  Map<String, dynamic>? _activePosting;
  bool _isLoading = true;
  List<LatLng> _routePoints = [];
  GoogleMapController? _mapController;
  LatLng? _lastFetchedCollectorPos;
  DateTime? _lastRouteFetch;

  @override
  void initState() {
    super.initState();
    debugPrint('[TrackScreen] ========== INIT CALLED ==========');
    _loadActivePosting();
    // Reload when a background posting upload completes successfully
    if (getIt.isRegistered<PostingUploadService>()) {
      getIt<PostingUploadService>().addListener(_onUploadStatusChanged);
    }
  }

  void _onUploadStatusChanged() {
    final service = getIt<PostingUploadService>();
    if (service.status == PostingUploadStatus.success) {
      debugPrint(
        '[TrackScreen] 🔄 Upload succeeded — reloading active posting',
      );
      _loadActivePosting();
    }
  }

  @override
  void dispose() {
    if (getIt.isRegistered<PostingUploadService>()) {
      getIt<PostingUploadService>().removeListener(_onUploadStatusChanged);
    }
    super.dispose();
  }

  Future<void> _fetchRoute(LatLng origin, LatLng destination) async {
    // Debounce: Don't fetch if we fetched less than 10 seconds ago
    if (_lastRouteFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastRouteFetch!);
      if (timeSinceLastFetch.inSeconds < 10) {
        return;
      }
    }

    _lastRouteFetch = DateTime.now();

    try {
      final polylinePoints = PolylinePoints();

      // Use the same Google Maps API key as in AndroidManifest.xml
      // Note: Ensure Directions API is enabled in Google Cloud Console
      const String googleApiKey = 'AIzaSyAq0X8O2q1AvfUW1kFYgU5tRBcpbnxX0ZE';

      final result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: googleApiKey,
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        setState(() {
          _routePoints = result.points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
          _lastFetchedCollectorPos = origin;
        });
      } else {
        // Fallback to straight line if no route found
        setState(() {
          _routePoints = [origin, destination];
        });
      }
    } catch (e) {
      debugPrint('[TrackScreen] Error fetching route: $e');
      // Fallback to straight line
      setState(() {
        _routePoints = [origin, destination];
      });
    }
  }

  double _calculateDistance(LatLng pos1, LatLng pos2) {
    // Haversine formula for distance between two coordinates
    const double earthRadius = 6371; // km
    final lat1Rad = pos1.latitude * (pi / 180);
    final lat2Rad = pos2.latitude * (pi / 180);
    final deltaLat = (pos2.latitude - pos1.latitude) * (pi / 180);
    final deltaLon = (pos2.longitude - pos1.longitude) * (pi / 180);

    final a =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * asin(sqrt(a));

    return earthRadius * c; // Returns distance in kilometers
  }

  Future<void> _loadActivePosting() async {
    debugPrint(
      '[TrackScreen] ========== _loadActivePosting STARTED ==========',
    );
    setState(() => _isLoading = true);

    try {
      final user = _db.auth.currentUser;
      debugPrint('[TrackScreen] Current user: ${user?.id ?? "NULL"}');
      debugPrint('[TrackScreen] User email: ${user?.email ?? "NULL"}');

      if (user == null) {
        debugPrint('[TrackScreen] ❌ No authenticated user - STOPPING');
        setState(() {
          _activePosting = null;
          _isLoading = false;
        });
        return;
      }

      debugPrint(
        '[TrackScreen] Querying postings for household ${user.id}',
      );

      // First, get ALL postings to see what we have
      final allPostings = rowsToDocs(
        'postings',
        await _db.from('postings').select().eq('household_id', user.id),
      );

      debugPrint(
        '[TrackScreen] 📦 Total postings found: ${allPostings.length}',
      );

      if (allPostings.isEmpty) {
        debugPrint('[TrackScreen] ❌ No documents in collection!');
        debugPrint(
          '[TrackScreen] Make sure posting was saved for household ${user.id}',
        );
        setState(() {
          _activePosting = null;
          _isLoading = false;
        });
        return;
      }

      // Log all postings
      for (final docData in allPostings) {
        debugPrint('[TrackScreen] Doc ID: ${docData['id']}');
        debugPrint('[TrackScreen]    - status: ${docData['status']}');
        debugPrint('[TrackScreen]    - createdAt: ${docData['createdAt']}');
        // Check both new nested and old flat structure
        final itemsData = docData['items'];
        if (itemsData is Map) {
          debugPrint(
            '[TrackScreen]    - items (nested): ${itemsData['list']?.length ?? 0}',
          );
          debugPrint(
            '[TrackScreen]    - totalValue (nested): ${itemsData['totalEstimatedValue']}',
          );
        } else if (itemsData is List) {
          debugPrint('[TrackScreen]    - items (legacy): ${itemsData.length}');
        }
      }

      // Sort by createdAt
      final sortedDocs = allPostings.toList();
      sortedDocs.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // descending
      });

      // Find the first posting that's NOT completed or declined (but include cancelled for tracking)
      Map<String, dynamic>? activeDoc;

      try {
        activeDoc = sortedDocs.firstWhere((doc) {
          final status = doc['status']?.toString().toLowerCase() ?? '';
          final isActive = status != 'completed' && status != 'declined';
          debugPrint(
            '[TrackScreen] Checking ${doc['id']}: status="$status", isActive=$isActive',
          );
          return isActive;
        });
      } catch (e) {
        debugPrint('[TrackScreen] ⚠️ No active posting found, using first one');
        activeDoc = sortedDocs.first;
      }

      final data = Map<String, dynamic>.from(activeDoc);
      data['householdId'] = user.id; // Add household ID for updates

      // Flatten nested cancellation data if it exists
      if (data['cancellation'] is Map<String, dynamic>) {
        final cancellationData = data['cancellation'] as Map<String, dynamic>;
        debugPrint(
          '[TrackScreen] 🔍 Found nested cancellation data: $cancellationData',
        );

        // Flatten cancellation fields to root level for easier access
        data['selectedReasons'] = cancellationData['selectedReasons'];
        data['cancellationReason'] = cancellationData['cancellationReason'];
        data['cancellationDetail'] = cancellationData['cancellationDetail'];
        data['cancelledAt'] = cancellationData['cancelledAt'];
        data['cancelledBy'] = cancellationData['cancelledBy'];
        data['cancelledByRole'] = cancellationData['cancelledByRole'];
        data['cancellationProofPhoto'] =
            cancellationData['cancellationProofPhoto'];

        debugPrint('[TrackScreen] ✅ Flattened cancellation data to root level');
        debugPrint(
          '[TrackScreen]    - cancellationReason: ${data['cancellationReason']}',
        );
        debugPrint(
          '[TrackScreen]    - cancellationProofPhoto: ${data['cancellationProofPhoto']}',
        );
      }

      debugPrint('[TrackScreen] ✅ Selected posting: ${activeDoc['id']}');
      debugPrint('[TrackScreen]    - status: ${data['status']}');
      // Check both new nested and old flat structure
      final itemsData = data['items'];
      if (itemsData is Map) {
        debugPrint(
          '[TrackScreen]    - items (nested): ${itemsData['list']?.length ?? 0}',
        );
        debugPrint(
          '[TrackScreen]    - totalValue (nested): ${itemsData['totalEstimatedValue']}',
        );
        debugPrint(
          '[TrackScreen]    - weight (nested): ${itemsData['estimatedTotalWeight']}',
        );
      } else if (itemsData is List) {
        debugPrint('[TrackScreen]    - items (legacy): ${itemsData.length}');
        debugPrint(
          '[TrackScreen]    - totalValue (legacy): ${data['totalEstimatedValue']}',
        );
      }

      setState(() {
        _activePosting = data;
        _isLoading = false;
      });

      debugPrint(
        '[TrackScreen] ✅ State updated, _activePosting is ${_activePosting != null ? "NOT NULL" : "NULL"}',
      );

      // Fetch real-time ratings for junkshop and collector
      await _fetchRealTimeRatings();
    } catch (e, stackTrace) {
      debugPrint('[TrackScreen] ❌ ERROR: $e');
      debugPrint('[TrackScreen] StackTrace: $stackTrace');
      setState(() {
        _activePosting = null;
        _isLoading = false;
      });
    }
  }

  /// Fetch real-time ratings from Supabase for junkshop and collector
  Future<void> _fetchRealTimeRatings() async {
    if (_activePosting == null) return;

    try {
      // Fetch junkshop rating
      final junkshopId = _activePosting!['assignedJunkshopId'] as String?;
      if (junkshopId != null && junkshopId.isNotEmpty) {
        final junkshopRow = await _db
            .from('junkshops')
            .select('average_rating')
            .eq('id', junkshopId)
            .maybeSingle();

        if (junkshopRow != null) {
          final rating = junkshopRow['average_rating'];

          setState(() {
            // Update nested junkshop data if it exists
            if (_activePosting!['junkshop'] is Map<String, dynamic>) {
              (_activePosting!['junkshop'] as Map<String, dynamic>)['rating'] =
                  rating ?? 0.0;
            } else {
              // Create nested structure if it doesn't exist
              _activePosting!['junkshop'] = {'rating': rating ?? 0.0};
            }
          });
          debugPrint('[TrackScreen] ✅ Fetched junkshop rating: $rating');
        }
      }

      // Fetch collector rating
      final collectorId = _activePosting!['assignedCollectorId'] as String?;
      if (collectorId != null && collectorId.isNotEmpty) {
        final collectorRow = await _db
            .from('collectors')
            .select('average_rating')
            .eq('id', collectorId)
            .maybeSingle();

        if (collectorRow != null) {
          final rating = collectorRow['average_rating'];

          setState(() {
            // Update nested collector data if it exists
            if (_activePosting!['collector'] is Map<String, dynamic>) {
              (_activePosting!['collector'] as Map<String, dynamic>)['rating'] =
                  rating ?? 0.0;
            } else {
              // Create nested structure if it doesn't exist
              _activePosting!['collector'] = {'rating': rating ?? 0.0};
            }
          });
          debugPrint('[TrackScreen] ✅ Fetched collector rating: $rating');
        }
      }
    } catch (e) {
      debugPrint('[TrackScreen] ⚠️ Error fetching real-time ratings: $e');
    }
  }

  // Convert Firestore data to display format
  Map<String, dynamic>? get _currentCollection {
    if (_activePosting == null) return null;

    debugPrint('[TrackScreen] ========== _currentCollection getter ==========');
    debugPrint(
      '[TrackScreen] _activePosting[status]: "${_activePosting!['status']}"',
    );
    debugPrint(
      '[TrackScreen] _activePosting keys: ${_activePosting!.keys.toList()}',
    );

    // Extract nested household data
    final household = _activePosting!['household'] is Map<String, dynamic>
        ? _activePosting!['household'] as Map<String, dynamic>
        : null;
    final householdName =
        household?['full_name'] ??
        _activePosting!['householdName'] ?? // Legacy fallback
        'Unknown';
    final householdAddress =
        household?['address'] ??
        _activePosting!['pickupLocation'] ?? // Legacy
        _activePosting!['addressShort'] ?? // Legacy
        'No address';
    final householdNote = household?['note']; // Pickup note/instructions
    final householdLat =
        household?['lat']; // Latitude for distance calculations
    final householdLng =
        household?['lng']; // Longitude for distance calculations

    // Extract nested junkshop data
    final junkshop = _activePosting!['junkshop'] is Map<String, dynamic>
        ? _activePosting!['junkshop'] as Map<String, dynamic>
        : null;
    final junkshopName =
        junkshop?['full_name'] ??
        _activePosting!['assignedJunkshopName'] ?? // Legacy
        'Not Yet Assigned';
    final junkshopAddress =
        junkshop?['address'] ??
        _activePosting!['assignedJunkshopAddress'] ?? // Legacy
        'Address not available';
    final junkshopPhone =
        junkshop?['phone'] ??
        _activePosting!['assignedJunkshopPhone'] ?? // Legacy
        'N/A';
    final junkshopRating =
        junkshop?['rating'] ??
        _activePosting!['assignedJunkshopRating'] ?? // Legacy
        0.0;
    final junkshopLat = junkshop?['lat']; // Latitude for distance calculations
    final junkshopLng = junkshop?['lng']; // Longitude for distance calculations

    // Extract nested collector data
    final collector = _activePosting!['collector'] is Map<String, dynamic>
        ? _activePosting!['collector'] as Map<String, dynamic>
        : null;
    final collectorName =
        collector?['full_name'] ??
        _activePosting!['assignedCollectorName'] ?? // Legacy
        'Pending Assignment';
    final collectorId =
        collector?['id'] ?? _activePosting!['assignedCollectorId']; // Legacy
    final collectorPhone =
        collector?['phone'] ??
        _activePosting!['assignedCollectorPhone']; // Legacy
    final collectorProfileImage =
        collector?['profile_image_url'] ??
        _activePosting!['assignedCollectorProfileImage'] ?? // Legacy
        _activePosting!['assignedCollectorPhoto']; // Legacy
    final collectorRating =
        collector?['rating'] ??
        _activePosting!['assignedCollectorRating'] ?? // Legacy
        0.0;
    final collectorTrips =
        collector?['trips'] ??
        _activePosting!['assignedCollectorTrips'] ?? // Legacy
        0;

    debugPrint('[TrackScreen] Household: $householdName');
    debugPrint('[TrackScreen] Household address: $householdAddress');
    debugPrint('[TrackScreen] Household note: $householdNote');
    debugPrint(
      '[TrackScreen] Household coords: lat=$householdLat, lng=$householdLng',
    );
    debugPrint('[TrackScreen] Junkshop: $junkshopName');
    debugPrint(
      '[TrackScreen] Junkshop coords: lat=$junkshopLat, lng=$junkshopLng',
    );
    debugPrint('[TrackScreen] Collector: $collectorName');

    // Safely extract status as String
    final statusValue = _activePosting!['status'];
    final statusString = statusValue is String
        ? statusValue
        : (statusValue?.toString() ?? 'pending');

    return {
      'id': _activePosting!['id'] ?? 'N/A',
      'householdId':
          _activePosting!['householdId'] ??
          _db.auth.currentUser?.id, // For updates
      'status': _formatStatus(statusString),
      'rawStatus': statusString, // Keep raw status for progress tracking
      'conversationId': _activePosting!['conversationId'],
      'junkshopId': _activePosting!['junkshopId'],
      'junkshopName': junkshopName,
      'declines': _activePosting!['declines'],
      'selectedReasons': _activePosting!['selectedReasons'],
      'cancellationReason': _activePosting!['cancellationReason'],
      'cancellationDetail': _activePosting!['cancellationDetail'],
      'cancelledAt': _activePosting!['cancelledAt'],
      'cancelledBy': _activePosting!['cancelledBy'],
      'cancelledByRole': _activePosting!['cancelledByRole'],
      'cancellationProofPhoto': _activePosting!['cancellationProofPhoto'],
      'post_attempt': _activePosting!['post_attempt'] ?? 0,
      'assignedCollector': collectorId,
      'collector': {
        'name': collectorName,
        'id': collectorId,
        'photo': collectorProfileImage,
        'rating': collectorRating,
        'trips': collectorTrips,
        'phone': collectorPhone,
      },
      'collectorId': collectorId,
      'collectorProfileImage': collectorProfileImage,
      'collectorRating': collectorRating,
      'collectorTrips': collectorTrips,
      'phone': collectorPhone,
      'scheduledDate': _activePosting!['scheduledDate'],
      'estimatedTime': _formatScheduledTime(
        _activePosting!['scheduledDate'],
        _activePosting!['scheduledTime'],
      ),
      'weight': _formatWeight(_extractWeight(_activePosting!)),
      'earnings': _formatEarnings(_extractTotalValue(_activePosting!)),
      'household': householdName,
      'address': householdAddress,
      'householdNote': householdNote, // Pickup instructions/note
      'householdLat': householdLat, // For distance calculations
      'householdLng': householdLng, // For distance calculations
      'junkshop': {
        'name': junkshopName,
        'address': junkshopAddress,
        'phone': junkshopPhone,
        'rating': junkshopRating,
        'lat': junkshopLat, // For distance calculations
        'lng': junkshopLng, // For distance calculations
      },
      'items': _formatItems(_extractItemsList(_activePosting!)),
      'verifiedItems': _extractVerifiedItemsList(
        _activePosting!,
      ), // Extracted verifiedItems list
      'notes': _activePosting!['notes'],
      'specialInstructions': _activePosting!['specialInstructions'],
      'unavailableDates':
          _activePosting!['unavailableDates'], // Dates household is NOT available
      'scheduledTime': _activePosting!['scheduledTime'], // Preferred timeframe
      'createdAt': _activePosting!['createdAt'],
      'assignedAt': _activePosting!['assignedAt'],
      'completedAt': _activePosting!['completedAt'],
      'verifiedAt': _activePosting!['verifiedItems']?['verifiedAt'],
    };
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'queued':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_transit':
        return 'En Route';
      case 'arrived':
      case 'collecting':
        return 'Collecting';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  String _formatScheduledTime(dynamic scheduledDate, String? scheduledTime) {
    if (scheduledDate == null) return 'Not scheduled';

    try {
      DateTime date;
      final parsed = toDateTime(scheduledDate);
      if (parsed == null) return 'Not scheduled';
      date = parsed;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final schedDate = DateTime(date.year, date.month, date.day);

      if (schedDate == today) {
        return scheduledTime ?? 'Today';
      } else if (schedDate == today.add(const Duration(days: 1))) {
        return scheduledTime != null ? 'Tomorrow $scheduledTime' : 'Tomorrow';
      } else {
        final formattedDate = '${date.month}/${date.day}/${date.year}';
        return scheduledTime != null
            ? '$formattedDate $scheduledTime'
            : formattedDate;
      }
    } catch (e) {
      return 'Not scheduled';
    }
  }

  String _formatTimestampDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime date;
      final parsed = toDateTime(timestamp);
      if (parsed == null) return 'N/A';
      date = parsed;

      return DateFormat('MMM dd, yyyy • h:mm a').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  List<Map<String, dynamic>> _buildCollectionHistory(
    Map<String, dynamic> collection,
  ) {
    final history = <Map<String, dynamic>>[];
    final postAttempt = collection['post_attempt'] ?? 0;

    if (collection['createdAt'] != null) {
      history.add({
        'event': 'Collection Created',
        'timestamp': collection['createdAt'],
        'icon': Icons.add_circle_outline,
        'color': AppColors.primaryGreen,
      });
    }

    if (postAttempt > 1) {
      history.add({
        'event': 'Reposted (Attempt $postAttempt)',
        'timestamp': collection['createdAt'],
        'icon': Icons.refresh,
        'color': Colors.orange,
        'detail': 'Previous attempt was cancelled or declined',
      });
    }

    if (collection['cancelledAt'] != null) {
      final role = collection['cancelledByRole']?.toString() ?? 'Unknown';
      final reason =
          collection['cancellationReason']?.toString() ?? 'No reason provided';
      history.add({
        'event': 'Collection Cancelled',
        'timestamp': collection['cancelledAt'],
        'icon': Icons.cancel_outlined,
        'color': Colors.red,
        'detail': 'Cancelled by $role: $reason',
      });
    }

    if (collection['assignedAt'] != null) {
      history.add({
        'event': 'Collector Assigned',
        'timestamp': collection['assignedAt'],
        'icon': Icons.person_add_outlined,
        'color': AppColors.primaryGreen,
        'detail': collection['collector']?['name'],
      });
    }

    if (collection['verifiedAt'] != null) {
      history.add({
        'event': 'Items Verified',
        'timestamp': collection['verifiedAt'],
        'icon': Icons.check_circle_outline,
        'color': AppColors.primaryGreen,
      });
    }

    if (collection['completedAt'] != null) {
      history.add({
        'event': 'Collection Completed',
        'timestamp': collection['completedAt'],
        'icon': Icons.check_circle,
        'color': AppColors.primaryGreen,
      });
    }

    history.sort((a, b) {
      final aTime = a['timestamp'];
      final bTime = b['timestamp'];
      if (aTime == null || bTime == null) return 0;

      final aDate = toDateTime(aTime) ?? DateTime.now();
      final bDate = toDateTime(bTime) ?? DateTime.now();
      return aDate.compareTo(bDate);
    });

    return history;
  }

  void _navigateToEditPost(Map<String, dynamic> collection) async {
    debugPrint('[TrackScreen] Navigating to edit post with data: $collection');

    // Navigate to household dashboard post tab (index 1) with edit data
    final result = await Navigator.pushNamed(
      context,
      '/household-home',
      arguments: {
        'initialIndex': 1, // Post tab
        'mode': 'edit',
        'postingId': _activePosting?['id'],
        'postingData': _activePosting,
      },
    );

    // Refresh the posting data after editing
    if (result == true) {
      debugPrint('[TrackScreen] Post was edited, refreshing...');
      await _loadActivePosting();
    }
  }

  void _showCancelConfirmation(Map<String, dynamic> collection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Warning icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                size: 48,
                color: AppColors.errorColor,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'Delete Collection Request?',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              'This will permanently delete the collection request and all related messages from your inbox. This action cannot be undone.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Keep',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelRequest(collection);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.errorColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Yes, Delete',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelRequest(Map<String, dynamic> collection) async {
    final postingId = collection['id']?.toString();
    if (postingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete: Posting ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting request and conversation...'),
          duration: Duration(seconds: 3),
        ),
      );

      final repo = getIt<IHouseholdPostingRepository>();
      final chatRepo = ChatRepository();

      // Delete the posting and get conversation ID if it exists
      final conversationId = await repo.cancelPosting(postingId);

      // Delete the conversation if it exists
      if (conversationId != null) {
        debugPrint('[TrackScreen] Deleting conversation: $conversationId');
        await chatRepo.deleteConversation(conversationId);
        debugPrint('[TrackScreen] Conversation deleted successfully');
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Collection request and messages deleted successfully',
          ),
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh the posting data (will show no active posting)
      await _loadActivePosting();

      // Force refresh of the entire household dashboard to update post screen
      if (mounted) {
        // Navigate to dashboard and then back to track to trigger full refresh
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/household-home',
          (route) => false,
          arguments: {'initialIndex': 2}, // Stay on Track tab
        );
      }
    } catch (e) {
      debugPrint('[TrackScreen] Error deleting request: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openConversation() async {
    if (_activePosting == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active collection found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final postingId = _activePosting!['id']?.toString();
    if (postingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid collection ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final chatRepo = ChatRepository();
      final conversation = await chatRepo.getConversationByPostingId(postingId);

      if (!mounted) return;

      if (conversation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation not found. Please try again later.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      Navigator.pushNamed(
        context,
        '/household/conversation',
        arguments: {'conversation': conversation},
      );
    } catch (e) {
      debugPrint('[TrackScreen] Error opening conversation: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open conversation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty || phoneNumber == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch phone dialer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('[TrackScreen] Error making phone call: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to make call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatWeight(dynamic weight) {
    if (weight == null) return '0 kg';
    return '${weight.toStringAsFixed(1)} kg';
  }

  String _formatEarnings(dynamic value) {
    if (value == null) return AppFormatters.currency(0.0);
    return AppFormatters.currency(value.toDouble());
  }

  List<Map<String, dynamic>> _formatItems(List<dynamic> items) {
    debugPrint('[TrackScreen] Formatting ${items.length} items...');
    return items.map((item) {
      final itemMap = item as Map<String, dynamic>;
      final quantity = itemMap['quantity'] ?? 0;
      final unit = itemMap['unit'] ?? 'pcs';

      // Handle both estimatedValue (from items) and totalPrice (from verifiedItems)
      final totalPrice =
          itemMap['totalPrice'] ?? itemMap['estimatedValue'] ?? 0.0;

      final category = itemMap['category'] ?? 'other';
      final imagePaths = (itemMap['imagePaths'] as List<dynamic>?)
          ?.cast<String>();

      // Extract promotion boost percentage if available
      final promotionBoostPercentage = itemMap['promotionBoostPercentage'];

      return {
        'name': itemMap['name'] ?? 'Unknown Item',
        'quantity': '$quantity $unit',
        'weight': '',
        'price': '',
        'totalPrice': _formatEarnings(totalPrice),
        'image': _getCategoryIcon(category),
        'imagePaths': imagePaths, // Actual photos
        'condition': itemMap['condition'] ?? '',
        'promotionBoostPercentage': promotionBoostPercentage,
      };
    }).toList();
  }

  /// Safely extracts items list from posting data, handling both nested and legacy structures
  /// For completed status, prioritizes verifiedItems over items
  List<dynamic> _extractItemsList(Map<String, dynamic> posting) {
    final status = posting['status']?.toString() ?? '';
    final isCompleted = status == 'completed';

    // For completed collections, try verifiedItems first
    if (isCompleted) {
      final verifiedItems = posting['verifiedItems'];
      if (verifiedItems != null) {
        if (verifiedItems is List) return verifiedItems;
        if (verifiedItems is Map<String, dynamic>) {
          final verifiedList = verifiedItems['list'];
          if (verifiedList is List) return verifiedList;
        }
      }
    }

    // Fall back to items field
    final itemsData = posting['items'];

    // If items is null, return empty list
    if (itemsData == null) return [];

    // If items is already a List (legacy structure), return it
    if (itemsData is List) return itemsData;

    // If items is a Map (new nested structure), extract the 'list' field
    if (itemsData is Map<String, dynamic>) {
      final itemsList = itemsData['list'];
      if (itemsList is List) return itemsList;
      return []; // items Map exists but no 'list' field
    }

    // Fallback for unexpected types
    return [];
  }

  /// Safely extracts verifiedItems list from posting data
  List<dynamic> _extractVerifiedItemsList(Map<String, dynamic> posting) {
    final verifiedItems = posting['verifiedItems'];

    // If verifiedItems is null, return empty list
    if (verifiedItems == null) return [];

    // If verifiedItems is a Map (expected structure), extract the 'items' field
    if (verifiedItems is Map<String, dynamic>) {
      final itemsList = verifiedItems['items'];
      if (itemsList is List) return itemsList;
      return []; // verifiedItems Map exists but no 'items' field
    }

    // If verifiedItems is already a List (legacy structure), return it
    if (verifiedItems is List) return verifiedItems;

    // Fallback for unexpected types
    return [];
  }

  /// Safely extracts total weight from posting data, handling both nested and legacy structures
  double _extractWeight(Map<String, dynamic> posting) {
    final itemsData = posting['items'];

    // If items is null, try legacy field
    if (itemsData == null) {
      return (posting['estimatedTotalWeight'] as num?)?.toDouble() ?? 0.0;
    }

    // If items is a Map (nested structure), extract from items.estimatedTotalWeight
    if (itemsData is Map<String, dynamic>) {
      final weight = itemsData['estimatedTotalWeight'];
      if (weight != null) return (weight as num).toDouble();
    }

    // Fallback to legacy field
    return (posting['estimatedTotalWeight'] as num?)?.toDouble() ?? 0.0;
  }

  /// Safely extracts total value from posting data, handling both nested and legacy structures
  double _extractTotalValue(Map<String, dynamic> posting) {
    final itemsData = posting['items'];

    // If items is null, try legacy field
    if (itemsData == null) {
      return (posting['totalEstimatedValue'] as num?)?.toDouble() ?? 0.0;
    }

    // If items is a Map (nested structure), extract from items.totalEstimatedValue
    if (itemsData is Map<String, dynamic>) {
      final value = itemsData['totalEstimatedValue'];
      if (value != null) return (value as num).toDouble();
    }

    // Fallback to legacy field
    return (posting['totalEstimatedValue'] as num?)?.toDouble() ?? 0.0;
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plastic':
        return 'plastic_bottles';
      case 'paper':
      case 'cardboard':
        return 'cardboard';
      case 'metal':
      case 'aluminum':
        return 'metal_cans';
      case 'glass':
        return 'glass_bottles';
      default:
        return 'other';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'En Route':
        return AppColors.successColor; // Green for en route
      case 'Pending':
        return Colors.orange;
      case 'Assigned':
        return AppColors.successColor; // Green for assigned
      case 'Completed':
        return AppColors.successColor;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
          title: const Text(
            'Track Collection',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          automaticallyImplyLeading: false,
          centerTitle: false,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.successColor),
          ),
        ),
      );
    }

    final collection = _currentCollection;

    if (collection == null || _activePosting == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
          title: const Text(
            'Track Collection',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          automaticallyImplyLeading: false,
          centerTitle: false,
        ),
        body: _buildEmptyState(),
      );
    }

    // Get posting ID for real-time listener
    final postingId = _activePosting!['id']?.toString();
    final user = _db.auth.currentUser;

    if (postingId == null || user == null) {
      // Fallback to static view if no ID
      return _buildStaticView(collection);
    }

    // Wrap with StreamBuilder for real-time updates
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db
          .from('postings')
          .stream(primaryKey: ['id'])
          .eq('id', postingId),
      builder: (context, snapshot) {
        // Update local state when new data arrives
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final updatedData = rowToDoc('postings', snapshot.data!.first);

          // Only update if data actually changed to avoid rebuild loops
          final oldStatus = _activePosting?['status'];
          final newStatus = updatedData['status'];

          if (oldStatus != newStatus) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              debugPrint(
                '[TrackScreen] 🔄 Real-time update: status changed from "$oldStatus" to "$newStatus"',
              );
              setState(() {
                _activePosting = updatedData;
              });
            });
          }
        }

        // Get fresh collection data after potential update
        final freshCollection = _currentCollection;
        if (freshCollection == null) {
          return _buildEmptyState();
        }

        return _buildStaticView(freshCollection);
      },
    );
  }

  Widget _buildStaticView(Map<String, dynamic> collection) {
    // Safely extract status - handle both String and potential Map from real-time updates
    final statusValue = collection['status'];
    final status = statusValue is String
        ? statusValue
        : (statusValue?.toString() ?? 'Pending');
    final isEnRoute = status == 'En Route';

    // For En Route: Full-screen map with draggable bottom sheet (Grab-style)
    if (isEnRoute) {
      return Scaffold(
        body: Stack(
          children: [
            // Full-screen Map
            _buildFullScreenMap(collection),

            // Draggable Bottom Sheet
            DraggableScrollableSheet(
              initialChildSize: 0.38,
              minChildSize: 0.18,
              maxChildSize: 0.85,
              shouldCloseOnMinExtent: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle Bar
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: _buildDraggableSheetContentInline(collection),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // For other statuses: Standard scrollable layout
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Track Collection',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: false,
        actions: [const SizedBox(width: 8)],
      ),
      body: _buildStandardLayout(collection),
    );
  }

  Widget _buildFullScreenMap(Map<String, dynamic> collection) {
    final postingId = collection['id']?.toString() ?? '';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db
          .from('active_collections')
          .stream(primaryKey: ['posting_id'])
          .eq('posting_id', postingId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Show loading state while waiting for tracking to start
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.successColor.withValues(alpha: 0.1),
                      Colors.grey.shade100,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.successColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Waiting for collector GPS...',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Top ETA Card even without tracking data
              _buildTopETACard(collection['estimatedTime'], 'N/A'),
            ],
          );
        }

        final data = rowToDoc('active_collections', snapshot.data!.first);
        final currentLoc = data['currentLocation'] as Map<String, dynamic>?;
        final destination = data['destination'] as Map<String, dynamic>?;

        if (currentLoc == null || destination == null) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.successColor.withValues(alpha: 0.1),
                      Colors.grey.shade100,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.successColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading GPS location...',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildTopETACard(collection['estimatedTime'], 'N/A'),
            ],
          );
        }

        final collectorPos = LatLng(
          (currentLoc['lat'] is num ? currentLoc['lat'].toDouble() : 0.0),
          (currentLoc['lng'] is num ? currentLoc['lng'].toDouble() : 0.0),
        );
        final destinationPos = LatLng(
          (destination['lat'] is num ? destination['lat'].toDouble() : 0.0),
          (destination['lng'] is num ? destination['lng'].toDouble() : 0.0),
        );

        // Fetch route when collector position changes significantly (>50 meters)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_lastFetchedCollectorPos == null) {
            // First time - fetch route
            _fetchRoute(collectorPos, destinationPos);
          } else {
            // Calculate distance moved
            final distance = _calculateDistance(
              _lastFetchedCollectorPos!,
              collectorPos,
            );
            // Only fetch if collector moved more than 200 meters
            if (distance > 0.2) {
              // 200 meters in km
              _fetchRoute(collectorPos, destinationPos);
            }
          }
        });

        // Calculate ETA text and distance
        // Use the values calculated by LocationTrackingService if available
        final distanceValue = data['distanceRemaining'];
        double distanceKm = distanceValue is num
            ? distanceValue.toDouble()
            : 0.0;
        String distanceText = 'Calculating...';
        String etaText = 'Calculating...';

        debugPrint('📍 [HOUSEHOLD] Reading from activeCollections:');
        debugPrint('   - distanceRemaining from Firestore: $distanceKm km');

        // If distanceRemaining is not available, calculate it ourselves
        if (distanceKm == 0.0) {
          final distanceMeters = Geolocator.distanceBetween(
            collectorPos.latitude,
            collectorPos.longitude,
            destinationPos.latitude,
            destinationPos.longitude,
          );
          distanceKm = distanceMeters / 1000;
          debugPrint(
            '   - distanceRemaining was 0, calculated: $distanceKm km',
          );
        }

        // Format distance text
        if (distanceKm < 1) {
          distanceText = '${(distanceKm * 1000).toStringAsFixed(0)} m';
        } else {
          distanceText = '${distanceKm.toStringAsFixed(1)} km';
        }

        // Calculate ETA using same speed as LocationTrackingService: 20 km/h
        const double speedKmh = 20.0;
        final etaMinutes = (distanceKm / speedKmh * 60).round();

        debugPrint('   - Calculated ETA: $etaMinutes min (at $speedKmh km/h)');
        debugPrint('   - Distance display: $distanceText');

        // Show "Arriving now" only when distance is less than 100 meters
        if (distanceKm < 0.1) {
          etaText = 'Arriving now';
        } else if (etaMinutes < 60) {
          etaText = '$etaMinutes min';
        } else {
          final h = etaMinutes ~/ 60;
          final rem = etaMinutes % 60;
          etaText = rem > 0 ? '${h}h ${rem}m' : '${h}h';
        }

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: collectorPos,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('collector'),
                  position: collectorPos,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor
                        .hueAzure, // Blue color to represent vehicle in transit
                  ),
                  infoWindow: const InfoWindow(title: 'Collector (En Route)'),
                ),
                Marker(
                  markerId: const MarkerId('destination'),
                  position: destinationPos,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                  infoWindow: const InfoWindow(title: 'My Location'),
                ),
              },
              polylines: _routePoints.isNotEmpty
                  ? {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: _routePoints,
                        color: AppColors.successColor,
                        width: 5,
                        patterns: const [],
                      ),
                    }
                  : {},
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                // Fit bounds to show both markers
                Future.delayed(const Duration(milliseconds: 500), () {
                  _fitBothMarkersHousehold(collectorPos, destinationPos);
                });
              },
            ),

            // Map control buttons (right side)
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).size.height * 0.19,
              child: Column(
                children: [
                  // Fit both markers button
                  IconButton(
                    icon: const Icon(
                      Icons.zoom_out_map,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () =>
                        _fitBothMarkersHousehold(collectorPos, destinationPos),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Center on household (your location) button
                  IconButton(
                    icon: const Icon(
                      Icons.gps_fixed,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => _centerOnHouseholdLocation(destinationPos),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Center on collector button
                  IconButton(
                    icon: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => _centerOnCollectorLocation(collectorPos),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),

            // Top ETA Card with live data
            _buildTopETACard(etaText, distanceText),
          ],
        );
      },
    );
  }

  // Household map control methods
  void _fitBothMarkersHousehold(LatLng collectorPos, LatLng destinationPos) {
    debugPrint('[TrackScreen] 🗺️ Fit both markers button pressed');
    debugPrint(
      '[TrackScreen] Collector: ${collectorPos.latitude}, ${collectorPos.longitude}',
    );
    debugPrint(
      '[TrackScreen] Household: ${destinationPos.latitude}, ${destinationPos.longitude}',
    );
    debugPrint('[TrackScreen] Map controller: ${_mapController != null}');

    if (_mapController == null) {
      debugPrint('[TrackScreen] ❌ Map controller is null');
      return;
    }

    try {
      final bounds = LatLngBounds(
        southwest: LatLng(
          collectorPos.latitude < destinationPos.latitude
              ? collectorPos.latitude
              : destinationPos.latitude,
          collectorPos.longitude < destinationPos.longitude
              ? collectorPos.longitude
              : destinationPos.longitude,
        ),
        northeast: LatLng(
          collectorPos.latitude > destinationPos.latitude
              ? collectorPos.latitude
              : destinationPos.latitude,
          collectorPos.longitude > destinationPos.longitude
              ? collectorPos.longitude
              : destinationPos.longitude,
        ),
      );
      debugPrint('[TrackScreen] ✅ Animating to fit both markers');
      _mapController!
          .animateCamera(CameraUpdate.newLatLngBounds(bounds, 100))
          .then((_) {
            // Apply custom zoom level to ensure markers aren't hidden by UI overlays
            if (_mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(
                      (bounds.northeast.latitude + bounds.southwest.latitude) /
                          2,
                      (bounds.northeast.longitude +
                              bounds.southwest.longitude) /
                          2,
                    ),
                    zoom: 14.5,
                  ),
                ),
              );
            }
          });
    } catch (e) {
      debugPrint('[TrackScreen] ❌ Error fitting bounds: $e');
    }
  }

  void _centerOnHouseholdLocation(LatLng destinationPos) {
    debugPrint('[TrackScreen] 🏠 Center on household button pressed');
    debugPrint(
      '[TrackScreen] Household position: ${destinationPos.latitude}, ${destinationPos.longitude}',
    );
    debugPrint('[TrackScreen] Map controller: ${_mapController != null}');

    if (_mapController == null) {
      debugPrint('[TrackScreen] ❌ Map controller is null');
      return;
    }

    try {
      debugPrint('[TrackScreen] ✅ Animating to household location');
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(destinationPos, 16),
      );
    } catch (e) {
      debugPrint('[TrackScreen] ❌ Error centering on household: $e');
    }
  }

  void _centerOnCollectorLocation(LatLng collectorPos) {
    debugPrint('[TrackScreen] 🚚 Center on collector button pressed');
    debugPrint(
      '[TrackScreen] Collector position: ${collectorPos.latitude}, ${collectorPos.longitude}',
    );
    debugPrint('[TrackScreen] Map controller: ${_mapController != null}');

    if (_mapController == null) {
      debugPrint('[TrackScreen] ❌ Map controller is null');
      return;
    }

    try {
      debugPrint('[TrackScreen] ✅ Animating to collector location');
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(collectorPos, 16),
      );
    } catch (e) {
      debugPrint('[TrackScreen] ❌ Error centering on collector: $e');
    }
  }

  Widget _buildTopETACard(String etaText, String distanceText) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ETA Section
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: AppColors.successColor,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ETA',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    etaText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Divider
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              const SizedBox(width: 12),
              // Distance Section
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Distance',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      distanceText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Live Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableSheetContentInline(Map<String, dynamic> collection) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collection ID & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                collection['id']?.toString() ?? 'N/A',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'En Route',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _openConversation(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.message_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Message',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () =>
                        _makePhoneCall(collection['phone'] as String?),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.successColor,
                      side: const BorderSide(
                        color: AppColors.successColor,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.phone_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Collector Card
          _buildCompactCollectorCard(collection),

          const SizedBox(height: 20),

          // Collection Items
          _buildCompactItemsList(collection),

          const SizedBox(height: 16),

          // Collection Details
          _buildCompactDetailsCard(collection),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPickupProgress() {
    final rawStatusValue = _currentCollection?['rawStatus'];
    final rawStatus =
        (rawStatusValue is String
                ? rawStatusValue
                : rawStatusValue?.toString() ?? 'pending')
            .toLowerCase();

    debugPrint('[TrackScreen] ========== _buildPickupProgress ==========');
    debugPrint('[TrackScreen] rawStatus from _currentCollection: "$rawStatus"');
    debugPrint(
      '[TrackScreen] _activePosting status: "${_activePosting?['status']}"',
    );
    debugPrint(
      '[TrackScreen] _currentCollection rawStatus: "${_currentCollection?['rawStatus']}"',
    );

    // Determine which steps are done based on actual status
    final steps = [
      {
        'label': 'Collector assigned',
        'icon': Icons.check_circle,
        'done': [
          'assigned',
          'in_transit',
          'arrived',
          'collecting',
          'completed',
        ].contains(rawStatus),
      },
      {
        'label': 'On the way',
        'icon': Icons.local_shipping_rounded,
        'done': [
          'in_transit',
          'arrived',
          'collecting',
          'completed',
        ].contains(rawStatus),
      },
      {
        'label': 'Arriving soon',
        'icon': Icons.location_on_rounded,
        'done': ['arrived', 'collecting', 'completed'].contains(rawStatus),
      },
      {
        'label': 'Collecting items',
        'icon': Icons.inventory_rounded,
        'done': ['collecting', 'completed'].contains(rawStatus),
      },
      {
        'label': 'Completed',
        'icon': Icons.task_alt_rounded,
        'done': rawStatus == 'completed',
      },
    ];

    // Debug: Log which steps are done
    debugPrint('[TrackScreen] Progress steps:');
    for (var i = 0; i < steps.length; i++) {
      debugPrint(
        '[TrackScreen]   ${i + 1}. ${steps[i]['label']}: ${steps[i]['done']}',
      );
    }

    final currentIndex = steps.indexWhere((s) => !(s['done'] as bool));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_rounded,
                size: 18,
                color: AppColors.successColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Pickup Progress',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final s = steps[i];
            final isDone = s['done'] as bool;
            final isCurrent = i == currentIndex;
            final isLast = i == steps.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline indicator
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.successColor
                              : (isCurrent
                                    ? AppColors.successColor.withValues(alpha: 0.2)
                                    : Colors.grey.shade200),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone || isCurrent
                                ? AppColors.successColor
                                : Colors.grey.shade300,
                            width: isDone ? 0 : 2,
                          ),
                        ),
                        child: Icon(
                          s['icon'] as IconData,
                          size: 14,
                          color: isDone
                              ? Colors.white
                              : (isCurrent
                                    ? AppColors.successColor
                                    : Colors.grey.shade400),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 1,
                          height: 20,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isDone
                              ? AppColors.successColor.withValues(alpha: 0.3)
                              : Colors.grey.shade200,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s['label'] as String,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isDone || isCurrent
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactCollectorCard(Map<String, dynamic> collection) {
    final collector = collection['collector'] as Map<String, dynamic>?;
    final collectorName = (collector?['name'] ?? 'Pending Assignment')
        .toString();
    final dynamic photoVal = collector?['photo'];
    final String? profileImage = (photoVal is String && photoVal.isNotEmpty)
        ? photoVal
        : null;
    final rating = (collector?['rating'] ?? 0.0) is num
        ? (collector?['rating'] ?? 0.0).toDouble()
        : 0.0;
    final trips = (collector?['trips'] ?? 0) is num
        ? (collector?['trips'] ?? 0).toInt()
        : 0;
    final phone = (collector?['phone'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: profileImage == null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.successColor,
                        AppColors.successColor.withValues(alpha: 0.7),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(10),
              image: profileImage != null
                  ? DecorationImage(
                      image: AppImageProvider(profileImage),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: profileImage == null
                ? const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collectorName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    rating.toStringAsFixed(1),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$trips trips',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailsCard(Map<String, dynamic> collection) {
    final junkshop = collection['junkshop'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Junkshop Info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  size: 16,
                  color: AppColors.successColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      junkshop['name'],
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.amber.shade700),
                    const SizedBox(width: 3),
                    Text(
                      junkshop['rating'].toString(),
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.amber.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Divider
          Container(
            height: 1,
            color: AppColors.borderLight.withValues(alpha: 0.5),
          ),

          const SizedBox(height: 10),

          // Address
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: AppColors.successColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (collection['address'] ?? '').toString(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactItemsList(Map<String, dynamic> collection) {
    // For completed collections, use verifiedItems (with collector prices)
    // For other statuses, use items (estimated values)
    final status =
        collection['rawStatus']?.toString() ??
        collection['status']?.toString() ??
        '';
    final isCompleted = status.toLowerCase() == 'completed';

    List<dynamic> items;
    if (isCompleted &&
        collection['verifiedItems'] != null &&
        (collection['verifiedItems'] as List).isNotEmpty) {
      // Format verifiedItems for display
      items = _formatItems(collection['verifiedItems'] as List<dynamic>);
    } else {
      // Use already formatted items
      items = collection['items'] as List<dynamic>? ?? [];
    }

    final totalEarnings =
        double.tryParse(
          (collection['earnings'] ?? '₱0.00')
              .toString()
              .replaceAll('₱', '')
              .replaceAll(',', ''),
        ) ??
        0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 16,
                  color: AppColors.successColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Items to Collect',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} items',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.borderLight.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          ...items.map((item) {
            final itemMap = item as Map<String, dynamic>;
            final quantityStr = itemMap['quantity'] ?? 'N/A';
            final priceStr = itemMap['totalPrice'] ?? '₱0.00';
            final price =
                double.tryParse(
                  priceStr.toString().replaceAll('₱', '').replaceAll(',', ''),
                ) ??
                0.0;
            final promotionBoostPercentage =
                itemMap['promotionBoostPercentage'];
            final hasBoost =
                promotionBoostPercentage != null &&
                promotionBoostPercentage > 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                itemMap['name'] ?? 'Unknown Item',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (hasBoost) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF10B981),
                                      Color(0xFF059669),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.trending_up,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '+${promotionBoostPercentage.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quantityStr.toString(),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormatters.currency(price),
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.successColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          Container(height: 1, color: AppColors.borderLight.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Earnings',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                AppFormatters.currency(totalEarnings),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.successColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(Map<String, dynamic> collection) {
    final status = collection['status']?.toString() ?? 'Pending';

    return RefreshIndicator(
      onRefresh: _loadActivePosting,
      color: AppColors.primaryGreen,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card (merged with decline/cancel info if declined/cancelled)
            if (status.toLowerCase() == 'declined')
              _buildDeclinedStatusCard(collection)
            else if (status.toLowerCase() == 'cancelled' ||
                status.toLowerCase() == 'cancelled_by_collector')
              _buildCancelledStatusCard(collection)
            else
              _buildStatusCard(collection),

            const SizedBox(height: 16),

            // Pending Message (for Pending status)
            if (status == 'Pending') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warningColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warningColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: AppColors.warningColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Waiting for Collector Assignment',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'We\'re finding the best collector for your pickup',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Pickup Progress (for Assigned status)
            if (status == 'Assigned') ...[
              _buildPickupProgress(),
              const SizedBox(height: 16),
            ],

            // Collector Info Card (only if assigned)
            if (status == 'Assigned') ...[
              _buildCollectorCard(collection),
              const SizedBox(height: 16),
            ],

            // Collection Details Card
            _buildCollectionDetailsCard(collection),

            const SizedBox(height: 16),

            // Action Buttons
            _buildActionButtons(collection),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> collection) {
    final status = collection['status']?.toString() ?? 'Pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(status).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getStatusIcon(status), color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection['id']?.toString() ?? 'N/A',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getStatusMessage(status),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Collections',
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new collection post to\nstart tracking your waste pickup',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const HouseholdDashboard(initialIndex: 1),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Create New Post',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectorCard(Map<String, dynamic> collection) {
    final rawProfileImage = collection['collectorProfileImage'];
    final String? profileImage =
        (rawProfileImage is String && rawProfileImage.isNotEmpty)
        ? rawProfileImage
        : null;
    final double rating = (collection['collectorRating'] ?? 0.0) is num
        ? (collection['collectorRating'] ?? 0.0).toDouble()
        : 0.0;
    final int trips = (collection['collectorTrips'] ?? 0) is num
        ? (collection['collectorTrips'] ?? 0).toInt()
        : 0;
    final dynamic collectorField = collection['collector'];
    final String collectorName = collectorField is Map<String, dynamic>
        ? (collectorField['name'] ?? 'Pending Assignment').toString()
        : (collectorField?.toString() ?? 'Pending Assignment');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Collector',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Collector Avatar or Profile Image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: profileImage == null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.successColor,
                            AppColors.successColor.withValues(alpha: 0.7),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.successColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  image: profileImage != null
                      ? DecorationImage(
                          image: AppImageProvider(profileImage),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profileImage == null
                    ? const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collectorName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '• $trips trips',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: () {
                    final collectorData = _currentCollection?['collector'];
                    final phone = collectorData is Map<String, dynamic>
                        ? collectorData['phone'] as String?
                        : _currentCollection?['phone'] as String?;
                    _makePhoneCall(phone);
                  },
                  icon: const Icon(Icons.phone_rounded),
                  color: AppColors.successColor,
                  iconSize: 20,
                  tooltip: 'Call',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: () => _openConversation(),
                  icon: const Icon(Icons.message_rounded),
                  color: AppColors.successColor,
                  iconSize: 20,
                  tooltip: 'Message',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionDetailsCard(Map<String, dynamic> collection) {
    final junkshop = collection['junkshop'] as Map<String, dynamic>? ?? {};

    // For completed collections, use verifiedItems (with collector prices)
    // For other statuses, use items (estimated values)
    final status =
        collection['rawStatus']?.toString() ??
        collection['status']?.toString() ??
        '';
    final isCompleted = status.toLowerCase() == 'completed';

    List<dynamic> items;
    if (isCompleted &&
        collection['verifiedItems'] != null &&
        (collection['verifiedItems'] as List).isNotEmpty) {
      // Format verifiedItems for display
      items = _formatItems(collection['verifiedItems'] as List<dynamic>);
    } else {
      // Use already formatted items
      items = collection['items'] as List<dynamic>? ?? [];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Junkshop Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  size: 20,
                  color: AppColors.successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Junkshop',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      junkshop['name'],
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // Junkshop Rating
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text(
                      junkshop['rating'].toString(),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Junkshop Address
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    junkshop['address'],
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Divider
          Container(height: 1, color: AppColors.borderLight),

          const SizedBox(height: 16),

          // Scheduled Collection Date - show for 'assigned' status
          if (collection['rawStatus']?.toString().toLowerCase() == 'assigned' &&
              collection['scheduledDate'] != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.event_available,
                    size: 20,
                    color: AppColors.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduled Collection Date',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        () {
                          final raw = collection['scheduledDate'];
                          final rawDate = toDateTime(raw);
                          if (rawDate != null) {
                            return DateFormat(
                              'EEEE, MMMM d, yyyy',
                            ).format(rawDate);
                          }
                          return 'Not scheduled';
                        }(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 16),
          ],

          // Collection Date - Only show for completed status
          if (collection['rawStatus']?.toString().toLowerCase() ==
                  'completed' &&
              collection['completedAt'] != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.event_available,
                    size: 20,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Collection Date',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestampDate(collection['completedAt']),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 16),
          ],

          // Collector Details Section - Only show for completed status
          if (collection['rawStatus']?.toString().toLowerCase() ==
                  'completed' &&
              collection['collector'] != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 20,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Collector',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        collection['collector']['name'] ?? 'Unknown Collector',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Collector Rating
                if (collection['collector']['rating'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          collection['collector']['rating'].toString(),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Collector Phone (if available)
            if (collection['collector']['phone'] != null)
              Padding(
                padding: const EdgeInsets.only(left: 44, top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      collection['collector']['phone'],
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 16),
          ],

          // Collection History - Only show for completed status
          if (collection['rawStatus']?.toString().toLowerCase() ==
              'completed') ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.history,
                    size: 20,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Collection History',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Timeline
            ...() {
              final history = _buildCollectionHistory(collection);
              return history.asMap().entries.map((entry) {
                final index = entry.key;
                final event = entry.value;
                final isLast = index == history.length - 1;

                return Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline line
                      SizedBox(
                        width: 32,
                        child: Column(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: event['color'].withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: event['color'],
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                event['icon'],
                                size: 12,
                                color: event['color'],
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 40,
                                color: AppColors.borderLight,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Event details
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['event'],
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTimestampDate(event['timestamp']),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (event['detail'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  event['detail'],
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            }(),

            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 16),
          ],

          // Unavailable Dates Section (for pending/assigned status)
          if (collection['unavailableDates'] != null &&
              (collection['rawStatus'] == 'pending' ||
                  collection['rawStatus'] == 'assigned')) ...[
            Text(
              'UNAVAILABLE DATES (BLOCKED)',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  (collection['unavailableDates'] as List<dynamic>?)?.map((
                    timestamp,
                  ) {
                    final date = toDateTime(timestamp) ?? DateTime.now();
                    final dayMonth = '${date.day} ${_getMonthName(date.month)}';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.successColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppColors.successColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dayMonth,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList() ??
                  [],
            ),

            // Preferred Time
            if (collection['scheduledTime'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Preferred Time: ',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      collection['scheduledTime'],
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 16),
          ],

          // Add More Dates Button (only for assigned status)
          if (collection['rawStatus'] == 'assigned') ...[
            OutlinedButton.icon(
              onPressed: () => _showAddDatesDialog(collection),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Change Blocked Dates'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 16),
          ],

          // Collection Notes Section - Only show for non-completed status
          if (collection['rawStatus']?.toString().toLowerCase() !=
              'completed') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'COLLECTION NOTES',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 13,
                  ),
                ),
                if (collection['rawStatus'] == 'assigned')
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _showEditNotesDialog(collection),
                    color: AppColors.primaryGreen,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                collection['notes']?.toString().isNotEmpty == true
                    ? collection['notes'].toString()
                    : 'No special instructions for the collector.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: collection['notes']?.toString().isNotEmpty == true
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontStyle: collection['notes']?.toString().isNotEmpty == true
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 16),
          ],

          // Collection Items Header
          Text(
            'COLLECTION ITEMS',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),

          // Items List
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            // Extract boost percentage
            final boostPercentage = (item['promotionBoostPercentage'] as num?)?.toDouble();
            final hasBoost = boostPercentage != null && boostPercentage > 0;

            return Column(
              children: [
                if (index > 0) const Divider(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item['name'],
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Promotion Boost Badge
                              if (hasBoost) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.successColor,
                                        AppColors.successColor.withValues(alpha: 0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.successColor
                                            .withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.trending_up,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '+${boostPercentage.toStringAsFixed(0)}%',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Quantity badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['quantity'],
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item['totalPrice'],
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          }),
          // Total row at the bottom
          const Divider(height: 16),
          Row(
            children: [
              Text(
                'Total Amount:',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              Text(
                collection['earnings']?.toString() ?? '₱0.00',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          // Total Weight
          Row(
            children: [
              Text(
                'Total Weight:',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              Text(
                (collection['weight'] ?? '').toString(),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Show dialog to change unavailable/blocked dates
  Future<void> _showAddDatesDialog(Map<String, dynamic> collection) async {
    // Initialize with ALL current blocked dates so the user can edit them
    final List<DateTime> blockedDates = List<DateTime>.from(
      (collection['unavailableDates'] as List<dynamic>?)
              ?.map((ts) => toDateTime(ts) ?? DateTime.now())
              .toList() ??
          [],
    );

    // Get the scheduled collection date so it cannot be blocked
    final rawScheduledDate = _activePosting?['scheduledDate'];
    DateTime? scheduledDate;
    scheduledDate = toDateTime(rawScheduledDate);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Blocked Dates'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select dates when you are NOT available for pickup. The collector will schedule outside these dates.',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    // Current blocked dates with delete chips
                    if (blockedDates.isNotEmpty) ...[
                      Text(
                        'Blocked dates:',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: blockedDates.map((date) {
                          return Chip(
                            label: Text(
                              '${date.day} ${_getMonthName(date.month)} ${date.year}',
                              style: AppTextStyles.bodySmall,
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setDialogState(() {
                                blockedDates.removeWhere(
                                  (d) =>
                                      d.year == date.year &&
                                      d.month == date.month &&
                                      d.day == date.day,
                                );
                              });
                            },
                            backgroundColor: AppColors.primaryGreen.withValues(alpha: 
                              0.1,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Text(
                          'No blocked dates set',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    ElevatedButton.icon(
                      onPressed: () async {
                        // Find a valid initial date (not already blocked, not scheduledDate)
                        DateTime initialDate = DateTime.now().add(
                          const Duration(days: 1),
                        );
                        int daysToAdd = 1;
                        while (daysToAdd < 62) {
                          final isBlocked = blockedDates.any(
                            (d) =>
                                d.year == initialDate.year &&
                                d.month == initialDate.month &&
                                d.day == initialDate.day,
                          );
                          final isScheduled =
                              scheduledDate != null &&
                              initialDate.year == scheduledDate.year &&
                              initialDate.month == scheduledDate.month &&
                              initialDate.day == scheduledDate.day;
                          if (!isBlocked && !isScheduled) break;
                          daysToAdd++;
                          initialDate = DateTime.now().add(
                            Duration(days: daysToAdd),
                          );
                        }

                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 60),
                          ),
                          selectableDayPredicate: (DateTime date) {
                            // Disable already-blocked dates
                            final alreadyBlocked = blockedDates.any(
                              (d) =>
                                  d.year == date.year &&
                                  d.month == date.month &&
                                  d.day == date.day,
                            );
                            // Disable the scheduled collection date
                            final isScheduledDate =
                                scheduledDate != null &&
                                date.year == scheduledDate.year &&
                                date.month == scheduledDate.month &&
                                date.day == scheduledDate.day;
                            return !alreadyBlocked && !isScheduledDate;
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            blockedDates.add(picked);
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Blocked Date'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),

                    if (scheduledDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Note: ${DateFormat('MMM d, yyyy').format(scheduledDate)} is your scheduled collection date and cannot be blocked.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _saveBlockedDates(collection, blockedDates);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Save blocked pickup dates
  Future<void> _saveBlockedDates(
    Map<String, dynamic> collection,
    List<DateTime> dates,
  ) async {
    try {
      final postingId = collection['id'];
      final householdId = collection['householdId'];

      if (postingId == null || householdId == null) {
        throw Exception('Missing posting or household ID');
      }

      final sortedDates = [...dates]..sort();

      await _db
          .from('postings')
          .update({
            'unavailable_dates': sortedDates
                .map((date) => date.toUtc().toIso8601String())
                .toList(),
          })
          .eq('id', postingId)
          .eq('household_id', householdId);

      await _loadActivePosting();

      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Blocked dates updated successfully'),
                backgroundColor: AppColors.successColor,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update dates: $e'),
                backgroundColor: AppColors.errorColor,
              ),
            );
          }
        });
      }
    }
  }

  // Show dialog to edit collection notes
  Future<void> _showEditNotesDialog(Map<String, dynamic> collection) async {
    String? result;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController notesController = TextEditingController(
          text: collection['notes']?.toString() ?? '',
        );

        return AlertDialog(
          title: const Text('Edit Collection Notes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add special instructions or notes for the collector:',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText:
                        'e.g., Please ring doorbell, items are in the garage, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundLight,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                result = notesController.text.trim();
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Notes'),
            ),
          ],
        );
      },
    );

    // Update notes if user didn't cancel
    if (result != null) {
      await _updateCollectionNotes(collection, result!);
    }
  }

  // Update collection notes in Firestore
  Future<void> _updateCollectionNotes(
    Map<String, dynamic> collection,
    String notes,
  ) async {
    try {
      final postingId = collection['id'];
      final householdId = collection['householdId'];

      if (postingId == null || householdId == null) {
        throw Exception('Missing posting or household ID');
      }

      // Update posting
      await _db
          .from('postings')
          .update({'notes': notes, 'special_instructions': notes})
          .eq('id', postingId)
          .eq('household_id', householdId);

      // Refresh the data first
      await _loadActivePosting();

      // Show success message after a slight delay to ensure dialog is fully closed
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Collection notes updated successfully'),
                backgroundColor: AppColors.successColor,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update notes: $e'),
                backgroundColor: AppColors.errorColor,
              ),
            );
          }
        });
      }
    }
  }

  // Helper method to get appropriate icon for item type
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'En Route':
        return Icons.local_shipping_rounded;
      case 'Pending':
        return Icons.schedule_rounded;
      case 'Assigned':
        return Icons.assignment_turned_in_rounded;
      case 'Completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'en route':
      case 'in_transit':
        return 'Collector is on the way';
      case 'pending':
      case 'queued':
        return 'Waiting for collector';
      case 'assigned':
        return 'Collector assigned';
      case 'completed':
        return 'Collection completed';
      case 'declined':
        return 'Request was declined';
      default:
        return 'Status unknown';
    }
  }

  Widget _buildDeclinedStatusCard(Map<String, dynamic> collection) {
    final status = collection['status']?.toString() ?? 'Declined';
    final postAttempt = (collection['post_attempt'] ?? 0) as int;

    // Get the latest decline data from nested structure
    final declines = (collection['declines'] as Map?)?.cast<String, dynamic>();
    String declineCount = '1st';
    if (postAttempt == 2) {
      declineCount = '2nd';
    } else if (postAttempt == 3) {
      declineCount = '3rd';
    } else if (postAttempt > 3) {
      declineCount = '${postAttempt}th';
    }

    final latestDecline = (declines?[declineCount] as Map?)
        ?.cast<String, dynamic>();
    final declineReason =
        latestDecline?['declineReason']?.toString() ??
        collection['declineReason']?.toString() ??
        'No reason provided';
    final declinedAt = latestDecline?['declinedAt'] ?? collection['declinedAt'];

    String declinedDate = 'Recently';
    if (declinedAt != null) {
      try {
        DateTime date;
        date = toDateTime(declinedAt) ?? DateTime.now();

        final now = DateTime.now();
        final difference = now.difference(date);

        if (difference.inMinutes < 60) {
          declinedDate = '${difference.inMinutes} minutes ago';
        } else if (difference.inHours < 24) {
          declinedDate = '${difference.inHours} hours ago';
        } else {
          declinedDate = '${date.month}/${date.day}/${date.year}';
        }
      } catch (e) {
        declinedDate = 'Recently';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.errorColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection['id']?.toString() ?? 'N/A',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Request was declined',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      declinedDate,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            postAttempt > 1
                                ? 'Latest Decline Reason:'
                                : 'Reason:',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            declineReason,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (postAttempt > 1 && declines != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Decline History:',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 1; i <= postAttempt; i++) ...[
                    _buildDeclineHistoryItem(i, declines),
                    if (i < postAttempt) const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'We understand this may be disappointing. If you believe your materials are still valuable for recycling, please feel free to repost your request with updated details or reach out to the junkshop directly for further clarification.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _navigateToConversation(collection),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(
                'Open Conversation',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: BorderSide(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclineHistoryItem(
    int attemptNumber,
    Map<String, dynamic> declines,
  ) {
    String declineKey = '1st';
    if (attemptNumber == 2) {
      declineKey = '2nd';
    } else if (attemptNumber == 3) {
      declineKey = '3rd';
    } else if (attemptNumber > 3) {
      declineKey = '${attemptNumber}th';
    }

    final decline = (declines[declineKey] as Map?)?.cast<String, dynamic>();
    if (decline == null) return const SizedBox.shrink();

    final reason = decline['declineReason']?.toString() ?? 'No reason provided';
    final declinedAt = decline['declinedAt'];

    String dateStr = 'Unknown';
    if (declinedAt != null) {
      try {
        DateTime date;
        date = toDateTime(declinedAt) ?? DateTime.now();
        dateStr =
            '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        dateStr = 'Unknown';
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.errorColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  declineKey,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.errorColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dateStr,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledStatusCard(Map<String, dynamic> collection) {
    debugPrint(
      '[TrackScreen] ========== Building cancelled status card ==========',
    );
    debugPrint('[TrackScreen] Collection keys: ${collection.keys.toList()}');

    // First check root level for cancellation data (most common case)
    String? cancellationReason = collection['cancellationReason']?.toString();
    String? cancellationDetail = collection['cancellationDetail']?.toString();
    String? cancellationProofPhoto = collection['cancellationProofPhoto']
        ?.toString();
    String? cancelledByRole = collection['cancelledByRole']?.toString();
    dynamic cancelledAt = collection['cancelledAt'];
    List<String> selectedReasons = [];

    // If root level has selectedReasons
    if (collection['selectedReasons'] is List) {
      selectedReasons = List<String>.from(collection['selectedReasons']);
    }

    // Check nested cancellation object if root level is empty
    if (collection['cancellation'] is Map) {
      final cancellationData =
          collection['cancellation'] as Map<String, dynamic>;
      cancellationReason ??= cancellationData['cancellationReason']?.toString();
      cancellationDetail ??= cancellationData['cancellationDetail']?.toString();
      cancellationProofPhoto ??= cancellationData['cancellationProofPhoto']
          ?.toString();
      cancelledByRole ??= cancellationData['cancelledByRole']?.toString();
      cancelledAt ??= cancellationData['cancelledAt'];

      if (selectedReasons.isEmpty &&
          cancellationData['selectedReasons'] is List) {
        selectedReasons = List<String>.from(
          cancellationData['selectedReasons'],
        );
      }
    }

    debugPrint('[TrackScreen] cancellationReason: $cancellationReason');
    debugPrint('[TrackScreen] cancellationDetail: $cancellationDetail');
    debugPrint('[TrackScreen] cancellationProofPhoto: $cancellationProofPhoto');
    debugPrint('[TrackScreen] selectedReasons: $selectedReasons');

    // Determine who cancelled
    final String cancelledByText = cancelledByRole == 'junkshop'
        ? 'Junkshop cancelled your request'
        : 'Collector cancelled your request';

    // Parse selectedReasons from comma-separated string if needed
    if (selectedReasons.isEmpty &&
        cancellationReason != null &&
        cancellationReason.isNotEmpty) {
      selectedReasons = cancellationReason
          .split(',')
          .map((r) => r.trim())
          .toList();
      debugPrint('[TrackScreen] Parsed reasons from string: $selectedReasons');
    }

    String cancelledDate = 'Recently';
    if (cancelledAt != null) {
      try {
        DateTime date;
        date = toDateTime(cancelledAt) ?? DateTime.now();

        final now = DateTime.now();
        final difference = now.difference(date);

        if (difference.inMinutes < 60) {
          cancelledDate = '${difference.inMinutes} minutes ago';
        } else if (difference.inHours < 24) {
          cancelledDate = '${difference.inHours} hours ago';
        } else {
          cancelledDate = '${date.month}/${date.day}/${date.year}';
        }
      } catch (e) {
        cancelledDate = 'Recently';
      }
    }

    // Format reasons for display
    String reasonsText = 'No reason provided';
    if (selectedReasons.isNotEmpty) {
      final Map<String, String> reasonLabels = {
        'household_not_home': 'Household not home',
        'items_mismatch': 'Items do not match posting',
        'items_not_recyclable': 'Items not recyclable',
        'incorrect_address': 'Incorrect or unclear address',
        'unsafe_location': 'Unsafe location',
        'items_already_collected': 'Already collected',
        'items_too_contaminated': 'Items too contaminated',
        'household_changed_mind': 'Household cancelled',
        'duplicate_posting': 'Duplicate posting',
        'vehicle_breakdown': 'Vehicle breakdown',
        'items_too_heavy': 'Items too heavy to collect',
        'weather_conditions': 'Bad weather conditions',
        'personal_emergency': 'Personal emergency',
        'other': 'Other reason',
      };

      reasonsText = selectedReasons.map((r) => reasonLabels[r] ?? r).join(', ');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.errorColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      collection['id']?.toString() ?? 'N/A',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Cancelled',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cancelledByText,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            cancelledDate,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason:',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reasonsText,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      if (cancellationDetail != null &&
                          cancellationDetail.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Additional details:',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cancellationDetail,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (cancellationProofPhoto != null &&
                          cancellationProofPhoto.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Proof Photo:',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            cancellationProofPhoto,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Could not load image',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "We apologize for the inconvenience. If you'd like to reschedule your collection or need more information about the cancellation, please don't hesitate to contact the collector or junkshop through the conversation below.",
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _navigateToConversation(collection),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(
                'Open Conversation',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: BorderSide(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _repostCollection(Map<String, dynamic> collection) async {
    final postingId = collection['id']?.toString();
    if (postingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to repost: Posting ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to edit post screen to allow household to make changes
    debugPrint(
      '[TrackScreen] Navigating to edit post for reposting: $postingId',
    );

    final result = await Navigator.pushNamed(
      context,
      '/household-home',
      arguments: {
        'initialIndex': 1, // Post tab
        'mode': 'edit',
        'postingId': postingId,
        'postingData': _activePosting,
        'isRepost': true, // Flag to indicate this is a repost
      },
    );

    // Refresh the posting data after editing
    if (result == true) {
      debugPrint('[TrackScreen] Post was reposted/edited, refreshing...');
      await _loadActivePosting();
    }
  }

  Future<void> _navigateToConversation(Map<String, dynamic> collection) async {
    debugPrint('[TrackScreen] _navigateToConversation called');
    debugPrint('[TrackScreen] Collection keys: ${collection.keys.toList()}');
    debugPrint('[TrackScreen] conversationId: ${collection['conversationId']}');
    debugPrint('[TrackScreen] posting id: ${collection['id']}');

    // Get conversation ID from collection or construct it from posting ID
    String? conversationId = collection['conversationId']?.toString();

    // If conversationId is null or empty, construct it from posting ID
    if (conversationId == null || conversationId.isEmpty) {
      final postingId = collection['id']?.toString();
      if (postingId != null && postingId.isNotEmpty) {
        conversationId = 'posting_$postingId';
        debugPrint(
          '[TrackScreen] Constructed conversationId from posting ID: $conversationId',
        );
      }
    }

    if (conversationId == null || conversationId.isEmpty) {
      debugPrint('[TrackScreen] Cannot determine conversation ID');
      debugPrint('[TrackScreen] Full collection data: $collection');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Conversation not found'),
            ],
          ),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    debugPrint('[TrackScreen] Navigating to conversation: $conversationId');

    try {
      // Fetch the conversation
      final conversationRow = await _db
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .maybeSingle();

      if (conversationRow == null) {
        throw Exception('Conversation not found in database');
      }

      // Create conversation model from the row
      final conversation = ConversationModel.fromMap(conversationRow);

      // Navigate to household chat screen with conversation object
      if (mounted) {
        await Navigator.pushNamed(
          context,
          '/household/conversation',
          arguments: {'conversation': conversation},
        );
      }
    } catch (e) {
      debugPrint('[TrackScreen] Error navigating to conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Unable to open conversation. Please try again.'),
                ),
              ],
            ),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  /// Removes a file from Supabase Storage given its public URL (best effort).
  Future<void> _deleteStorageUrl(String url) async {
    try {
      final match = RegExp(r'/object/public/([^/]+)/(.+?)(?:\?.*)?$').firstMatch(url);
      if (match == null) return;
      await deleteStorageObject(
        match.group(1)!,
        Uri.decodeComponent(match.group(2)!),
      );
    } catch (e) {
      debugPrint('[TrackScreen] Failed to delete file $url: $e');
    }
  }

  Future<void> _deleteCollection(Map<String, dynamic> collection) async {
    final postingId = collection['id']?.toString();
    if (postingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete: Posting ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: AppColors.errorColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('Delete Request?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to permanently delete this collection request?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.errorColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Delete',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint(
        '[TrackScreen] Deleting posting and all related data: $postingId',
      );

      // 1. Get posting data to find conversation ID and image URLs
      final postingRow = await _db
          .from('postings')
          .select()
          .eq('id', postingId)
          .eq('household_id', userId)
          .maybeSingle();

      if (postingRow == null) {
        throw Exception('Posting not found');
      }

      final postingData = rowToDoc('postings', postingRow);
      final conversationId = postingData['conversationId'] as String?;
      final imageUrls = postingData['imageUrls'] as List<dynamic>?;
      final cancellationMap = postingData['cancellation'];
      final cancellationProofPhoto =
          (cancellationMap is Map
                  ? cancellationMap['cancellationProofPhoto']
                  : null)
              as String? ??
          postingData['cancellationProofPhoto'] as String?;

      // 2. Delete all images from Storage
      if (imageUrls != null && imageUrls.isNotEmpty) {
        debugPrint(
          '[TrackScreen] Deleting ${imageUrls.length} posting images from Storage',
        );
        for (final imageUrl in imageUrls) {
          if (imageUrl is String && imageUrl.isNotEmpty) {
            await _deleteStorageUrl(imageUrl);
          }
        }
      }

      // 3. Delete cancellation proof photo if exists
      if (cancellationProofPhoto != null && cancellationProofPhoto.isNotEmpty) {
        await _deleteStorageUrl(cancellationProofPhoto);
      }

      // 4. Delete conversation if exists (messages cascade)
      if (conversationId != null && conversationId.isNotEmpty) {
        debugPrint('[TrackScreen] Deleting conversation: $conversationId');
        try {
          await _db.from('conversations').delete().eq('id', conversationId);
          debugPrint('[TrackScreen] Conversation deleted successfully');
        } catch (e) {
          debugPrint('[TrackScreen] Failed to delete conversation: $e');
          // Continue with posting deletion even if conversation deletion fails
        }
      }

      // 5. Delete the posting row
      await _db
          .from('postings')
          .delete()
          .eq('id', postingId)
          .eq('household_id', userId);
      debugPrint(
        '[TrackScreen] Posting and all related data deleted successfully',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('Collection request deleted successfully'),
              ],
            ),
            backgroundColor: AppColors.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Navigate back to home screen
        Navigator.pushReplacementNamed(
          context,
          '/household-home',
          arguments: {'initialIndex': 0},
        );
      }
    } catch (e) {
      debugPrint('[TrackScreen] Error deleting posting: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to delete request. Please try again.'),
                ),
              ],
            ),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildActionButtons(Map<String, dynamic> collection) {
    final status = collection['status']?.toString() ?? 'Pending';
    final postAttempt = (collection['post_attempt'] ?? 0) as int;

    return Column(
      children: [
        if (status.toLowerCase() == 'declined' ||
            status.toLowerCase() == 'cancelled' ||
            status.toLowerCase() == 'cancelled_by_collector') ...[
          if (postAttempt < 3) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => _repostCollection(collection),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Repost Collection Request',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => _deleteCollection(collection),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorColor,
                  side: BorderSide(
                    color: AppColors.errorColor.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_outline_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Delete Request',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.warningColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Repost attempts: $postAttempt/3',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.errorColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.block_rounded,
                    color: AppColors.errorColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maximum Repost Limit Reached',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please create a new collection request',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ] else if (status == 'Pending') ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _navigateToEditPost(collection),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Collection Post',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => _showCancelConfirmation(collection),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.errorColor,
                side: BorderSide(color: AppColors.errorColor.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Cancel Request',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.errorColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else if (status == 'Assigned') ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                final collectorData = collection['collector'];
                final phone = collectorData is Map<String, dynamic>
                    ? collectorData['phone'] as String?
                    : collection['phone'] as String?;
                _makePhoneCall(phone);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Contact Collector',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
