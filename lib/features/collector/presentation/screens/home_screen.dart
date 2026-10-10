import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/repositories/collector_tasks_repository.dart';
import '../../data/models/collection_task_model.dart';
import '../../data/services/date_validation_service.dart';
import '../bloc/profile/collector_profile_bloc.dart';
import '../bloc/profile/collector_profile_event.dart';
import 'profile/account_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool showBottomNav;
  final ValueChanged<int>?
  onNavSelected; // 0: Home, 1: Collections, 2: Messages, 3: Profile

  const HomeScreen({super.key, this.showBottomNav = true, this.onNavSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Availability toggle state
  bool isAvailable = true;

  // Real data
  List<CollectorTask> _myTasks = [];
  bool _loadingTasks = false;
  String? _errorTasks;
  bool _isInitialLoad = true;
  Position? _currentPosition;
  bool? _hasPartnerJunkshop; // null = still loading
  String _applicationStatus = 'approved'; // tracks collector's current status
  String _partnerJunkshopName = ''; // display name of the partner junkshop
  bool _junkshopDisabled =
      false; // true when partner junkshop is disabled by admin
  StreamSubscription<List<Map<String, dynamic>>>? _collectorStatusSub;

  // Filter state
  String _collectionFilter = 'all'; // 'all' or 'today'

  @override
  void initState() {
    super.initState();
    _fetchMyTasks();
    _startLocationUpdates();
    _listenToCollectorStatus();
  }

  /// Listens to the collector document in real-time so status and partner
  /// junkshop name update immediately after reapplying to a different junkshop.
  void _listenToCollectorStatus() {
    final uid = currentUid;
    if (uid == null) {
      if (mounted) setState(() => _hasPartnerJunkshop = false);
      return;
    }

    _collectorStatusSub = supabase
        .from('collectors')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .listen(
          (rows) async {
            if (rows.isEmpty) {
              if (mounted) setState(() => _hasPartnerJunkshop = false);
              return;
            }
            final data = rowToDoc('collectors', rows.first);
            final cp = data['collector_profile'] as Map<String, dynamic>?;
            final personal = cp?['personal'] as Map<String, dynamic>?;
            final id =
                (personal?['preferred_junkshop_id'] ??
                        cp?['preferred_junkshop_id'] ??
                        data['preferred_junkshop_id'] ??
                        '')
                    .toString()
                    .trim();
            final status =
                (data['application_status'] as String?) ?? 'approved';

            // Fetch junkshop display name and active status
            String junkshopName = '';
            bool junkshopDisabled = false;
            if (id.isNotEmpty) {
              try {
                final jsRow = await supabase
                    .from('junkshops')
                    .select()
                    .eq('id', id)
                    .maybeSingle();
                if (jsRow != null) {
                  final jsData = rowToDoc('junkshops', jsRow);
                  final jp =
                      jsData['junkshop_profile'] as Map<String, dynamic>?;
                  junkshopName =
                      (jp?['business_name'] ??
                              jp?['shop_name'] ??
                              jsData['full_name'] ??
                              '')
                          .toString()
                          .trim();
                  junkshopDisabled = jsData['isActive'] == false;
                }
              } catch (_) {}
            }

            if (mounted) {
              setState(() {
                _hasPartnerJunkshop = id.isNotEmpty;
                _applicationStatus = status;
                _partnerJunkshopName = junkshopName;
                _junkshopDisabled = junkshopDisabled;
              });
            }
          },
          onError: (_) {
            if (mounted) setState(() => _hasPartnerJunkshop = false);
          },
        );
  }

  @override
  void dispose() {
    _collectorStatusSub?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() async {
    // Update distance/ETA every 30 seconds if we have tasks
    final hasPerm = await _ensureLocationPermission();
    if (!hasPerm) return;

    // Get initial position
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted && _myTasks.isNotEmpty) {
        _updateDistancesForCurrentPosition();
      }
    } catch (e) {
      debugPrint('❌ Error getting initial position: $e');
    }

    // Listen to position changes
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // Update every 100 meters
      ),
    ).listen((Position position) {
      if (!mounted) return;
      _currentPosition = position;
      _updateDistancesForCurrentPosition();
    });
  }

  void _updateDistancesForCurrentPosition() {
    if (_currentPosition == null || _myTasks.isEmpty) return;

    bool hasChanges = false;
    for (final t in _myTasks) {
      final lat = t.householdLat;
      final lng = t.householdLng;
      if (lat == null || lng == null) continue;

      final distKm = _haversineKm(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        lat,
        lng,
      );
      final newDistanceKm = double.parse(distKm.toStringAsFixed(2));
      final newEtaMinutes = _estimateEtaMinutes(distKm);

      if (t.distanceKm != newDistanceKm || t.etaMinutes != newEtaMinutes) {
        t.distanceKm = newDistanceKm;
        t.etaMinutes = newEtaMinutes;
        hasChanges = true;
      }
    }

    if (hasChanges && mounted) {
      setState(() {});
      debugPrint('🔄 Updated distances for ${_myTasks.length} tasks');
    }
  }

  Future<void> _fetchMyTasks() async {
    final uid = currentUid;
    if (uid == null) {
      setState(() => _errorTasks = 'Not logged in');
      return;
    }

    setState(() {
      if (_isInitialLoad) {
        _loadingTasks = true;
      }
      _errorTasks = null;
    });

    try {
      final repo = getIt<ICollectorTasksRepository>();
      var tasks = await repo.fetchMyTasks(uid);

      if (!mounted) return;
      // Check each assigned task's collection date; move overdue ones to reschedule
      tasks = await _filterExpiredTasks(
        tasks,
        uid,
        supabase.auth.currentUser?.userMetadata?['full_name']?.toString(),
      );
      if (!mounted) return;
      // After tasks are loaded, compute distance/ETA if we have permission
      await _enrichTasksWithMetrics(tasks);
      if (!mounted) return;
      setState(() {
        _myTasks = tasks;
        _loadingTasks = false;
        _isInitialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorTasks = e.toString();
        _loadingTasks = false;
        _isInitialLoad = false;
      });
    }
  }

  /// Checks each assigned task against its collection date.
  /// Overdue tasks are moved to 'reschedule' status and removed from the active list.
  Future<List<CollectorTask>> _filterExpiredTasks(
    List<CollectorTask> tasks,
    String collectorId,
    String? collectorName,
  ) async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final service = DateValidationService();
    final validTasks = <CollectorTask>[];

    for (final task in tasks) {
      final dateOfCollection = task.dateOfCollection;
      if (task.status == 'assigned' &&
          dateOfCollection != null &&
          DateTime(
            dateOfCollection.year,
            dateOfCollection.month,
            dateOfCollection.day,
          ).isBefore(today)) {
        final wasRescheduled = await service.checkAndResetIfDatePassed(
          householdId: task.householdId,
          postingId: task.id,
          collectorId: collectorId,
          collectorName: collectorName,
        );
        if (wasRescheduled) continue; // remove from active list
      }
      validTasks.add(task);
    }

    return validTasks;
  }

  Future<void> _enrichTasksWithMetrics(List<CollectorTask> tasks) async {
    try {
      // Guard against widget disposal during async operations
      if (!mounted) return;

      // Ensure location permission and services
      final hasPerm = await _ensureLocationPermission();
      if (!hasPerm || !mounted) {
        return; // gracefully skip metrics if no location
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Check mounted after async location call
      if (!mounted) return;

      debugPrint(
        '🎯 ENRICHMENT: Current position: ${pos.latitude}, ${pos.longitude}',
      );

      // Use Google Directions API for accurate distance and ETA
      for (final t in tasks) {
        final lat = t.householdLat;
        final lng = t.householdLng;
        if (lat == null || lng == null) {
          debugPrint('⚠️ ENRICHMENT: Task ${t.id} missing coordinates');
          continue;
        }

        try {
          final result = await _getDirectionsDistance(
            pos.latitude,
            pos.longitude,
            lat,
            lng,
          );

          if (result != null) {
            t.distanceKm = result['distanceKm'];
            t.etaMinutes = result['durationMinutes'];

            debugPrint('✅ ENRICHMENT (Directions API): Task ${t.id}:');
            debugPrint('   - Address: ${t.addressShort}');
            debugPrint('   - Distance: ${t.distanceKm} km');
            debugPrint('   - ETA: ${t.etaMinutes} min');
          } else {
            // Fallback to Haversine if API fails
            final distKm = _haversineKm(pos.latitude, pos.longitude, lat, lng);
            t.distanceKm = double.parse(distKm.toStringAsFixed(2));
            t.etaMinutes = _estimateEtaMinutes(distKm);

            debugPrint('✅ ENRICHMENT (Fallback): Task ${t.id}:');
            debugPrint('   - Distance: ${t.distanceKm} km (straight-line)');
            debugPrint('   - ETA: ${t.etaMinutes} min (estimated)');
          }
        } catch (e) {
          debugPrint('❌ Error getting directions for task ${t.id}: $e');
          // Fallback to Haversine
          final distKm = _haversineKm(pos.latitude, pos.longitude, lat, lng);
          t.distanceKm = double.parse(distKm.toStringAsFixed(2));
          t.etaMinutes = _estimateEtaMinutes(distKm);
        }
      }
    } catch (e) {
      debugPrint('❌ ENRICHMENT ERROR: $e');
      // ignore failures; UI will show placeholders
    }
  }

  Future<Map<String, dynamic>?> _getDirectionsDistance(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      if (apiKey.isEmpty) return null;

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$fromLat,$fromLng&destination=$toLat,$toLng&mode=driving&key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          final distanceMeters = leg['distance']['value'] as int;
          final durationSeconds = leg['duration']['value'] as int;

          return {
            'distanceKm': double.parse(
              (distanceMeters / 1000.0).toStringAsFixed(2),
            ),
            'durationMinutes': (durationSeconds / 60).round(),
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Directions API error: $e');
      return null;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  int _estimateEtaMinutes(double distanceKm, {double speedKmh = 25.0}) {
    // Simple local estimate: avg urban driving/riding speed ~25 km/h
    if (speedKmh <= 0) speedKmh = 25.0;
    final hours = distanceKm / speedKmh;
    final minutes = (hours * 60).clamp(1, 24 * 60); // clamp 1 min .. 24h
    return minutes.round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Header Section
          _buildHeader(),

          // Scrollable Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchMyTasks,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Junkshop disabled by admin
                    if (_junkshopDisabled) _buildJunkshopDisabledState(),
                    // Reapplying full-state view
                    if (!_junkshopDisabled &&
                        _applicationStatus == 'reapplying')
                      _buildReapplyingState(),
                    // Rejected-after-reapply full-state view
                    if (!_junkshopDisabled &&
                        _applicationStatus == 'rejected' &&
                        _hasPartnerJunkshop == true)
                      _buildRejectedState(),
                    // Fired full-state view
                    if (!_junkshopDisabled && _applicationStatus == 'fired')
                      _buildFiredState(),
                    // No-partner banner
                    if (_hasPartnerJunkshop == false &&
                        _applicationStatus != 'reapplying' &&
                        _applicationStatus != 'fired')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.store_outlined,
                                color: Colors.amber.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No Partner Junkshop',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.amber.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'You are not partnered with any junkshop. '
                                      'No collection assignments will be sent to you until you apply.',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () =>
                                          widget.onNavSelected?.call(3),
                                      child: Text(
                                        'Go to Account Settings →',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.collectorPrimary,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Filter + list only while active
                    if (!_junkshopDisabled &&
                        _applicationStatus != 'reapplying' &&
                        _applicationStatus != 'fired' &&
                        !(_applicationStatus == 'rejected' &&
                            _hasPartnerJunkshop == true)) ...[
                      _buildFilterSection(),
                      const SizedBox(height: 20),
                      _buildCollectionsList(),
                    ],

                    // Bottom Padding for Navigation
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav
          ? _buildBottomNavigation()
          : null,
    );
  }

  Widget _buildRejectedState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Icon(Icons.cancel_rounded, size: 52, color: Colors.red.shade500),
          const SizedBox(height: 16),

          // Title
          Text(
            'Application Rejected',
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Your reapplication was not approved. You can reapply to a different junkshop.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 24),

          // Restricted section label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Restricted while rejected',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),

          _buildRestrictionRow(
            icon: Icons.assignment_outlined,
            label: 'Collection assignments',
            detail: 'No tasks will be sent to you',
          ),
          const SizedBox(height: 14),
          _buildRestrictionRow(
            icon: Icons.chat_bubble_outline,
            label: 'Messaging',
            detail: 'Group & direct chats are paused',
          ),

          const SizedBox(height: 28),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 24),

          // What's next label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'What you can do',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),

          _buildNextStep(
            number: '1',
            text: 'Go to Account Settings and select a junkshop to reapply',
          ),
          const SizedBox(height: 12),
          _buildNextStep(
            number: '2',
            text: 'Wait for the junkshop to review your new application',
          ),
          const SizedBox(height: 12),
          _buildNextStep(
            number: '3',
            text:
                'Collections and messaging resume automatically upon approval',
          ),

          const SizedBox(height: 28),

          // Reapply CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) =>
                        getIt<CollectorProfileBloc>()
                          ..add(const LoadCollectorProfileEvent()),
                    child: const AccountSettingsScreen(),
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.collectorPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go to Account Settings to Reapply',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJunkshopDisabledState() {
    final shopLabel = _partnerJunkshopName.isNotEmpty
        ? _partnerJunkshopName
        : 'your junkshop';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.domain_disabled_rounded,
            size: 52,
            color: Colors.red.shade500,
          ),
          const SizedBox(height: 16),

          Text(
            'Junkshop Unavailable',
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            '$shopLabel has been disabled by the administrator. You will not receive new assignments until you reapply to an active junkshop.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 24),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Restricted while junkshop is disabled',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),

          _buildRestrictionRow(
            icon: Icons.assignment_outlined,
            label: 'Collection assignments',
            detail: 'No tasks will be sent to you',
          ),
          const SizedBox(height: 14),
          _buildRestrictionRow(
            icon: Icons.chat_bubble_outline,
            label: 'Messaging',
            detail: 'Group & direct chats are paused',
          ),

          const SizedBox(height: 28),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 24),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'What you can do',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),

          _buildNextStep(
            number: '1',
            text:
                'Go to Account Settings and choose a different active junkshop',
          ),
          const SizedBox(height: 12),
          _buildNextStep(
            number: '2',
            text:
                'Wait for the junkshop to review and approve your application',
          ),
          const SizedBox(height: 12),
          _buildNextStep(
            number: '3',
            text:
                'Collections and messaging resume automatically upon approval',
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) =>
                        getIt<CollectorProfileBloc>()
                          ..add(const LoadCollectorProfileEvent()),
                    child: const AccountSettingsScreen(),
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.collectorPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go to Account Settings to Reapply',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiredState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Icon(
            Icons.person_remove_rounded,
            size: 52,
            color: Colors.red.shade500,
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'You\'ve Been Dismissed',
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Your junkshop has removed you from their team. You can reapply to any junkshop to continue working.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 24),

          // Restricted section label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Restricted while dismissed',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),

          _buildRestrictionRow(
            icon: Icons.assignment_outlined,
            label: 'Collection assignments',
            detail: 'No tasks will be sent to you',
          ),
          const SizedBox(height: 14),
          _buildRestrictionRow(
            icon: Icons.chat_bubble_outline,
            label: 'Messaging',
            detail: 'Group & direct chats are paused',
          ),

          const SizedBox(height: 28),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 24),

          // What you can do label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'What you can do',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),

          _buildNextStep(
            number: '1',
            text:
                'Go to Account Settings and choose a new junkshop to apply to',
          ),
          const SizedBox(height: 12),
          _buildNextStep(
            number: '2',
            text:
                'Wait for the junkshop to review and approve your application',
          ),
          const SizedBox(height: 12),
          _buildNextStep(
            number: '3',
            text:
                'Collections and messaging resume automatically upon approval',
          ),

          const SizedBox(height: 28),

          // Reapply CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) =>
                        getIt<CollectorProfileBloc>()
                          ..add(const LoadCollectorProfileEvent()),
                    child: const AccountSettingsScreen(),
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.collectorPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go to Account Settings to Reapply',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReapplyingState() {
    final junkshopLabel = _partnerJunkshopName.isNotEmpty
        ? _partnerJunkshopName
        : 'your junkshop';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Icon(
            Icons.hourglass_top_rounded,
            size: 52,
            color: Colors.amber.shade600,
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Reapplication Pending',
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Junkshop line
          Text(
            'Submitted to $junkshopLabel • Under review',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 24),

          // Restricted section label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Restricted while pending',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),

          _buildRestrictionRow(
            icon: Icons.assignment_outlined,
            label: 'Collection assignments',
            detail: 'No tasks will be sent to you',
          ),
          const SizedBox(height: 14),
          _buildRestrictionRow(
            icon: Icons.chat_bubble_outline,
            label: 'Messaging',
            detail: 'Group & direct chats are paused',
          ),

          const SizedBox(height: 28),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 24),

          // What's next label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'What happens next',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),

          _buildNextStep(
            number: '1',
            text: '$junkshopLabel reviews your application',
          ),
          const SizedBox(height: 12),
          _buildNextStep(
            number: '2',
            text: 'You\'ll be notified once a decision is made',
          ),
          const SizedBox(height: 12),
          _buildNextStep(
            number: '3',
            text:
                'Collections and messaging resume automatically upon approval',
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictionRow({
    required IconData icon,
    required String label,
    required String detail,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.grey.shade400),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                detail,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.remove_circle_outline,
          size: 18,
          color: Colors.grey.shade400,
        ),
      ],
    );
  }

  Widget _buildNextStep({required String number, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(
        top: 16, // Reduced by 60% from 40 to 16
        left: AppDimensions.spacing24,
        right: AppDimensions.spacing24,
        bottom: 16, // Same as top for equal padding
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen, // Plain green like histories header
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // App Title
            Row(
              children: [
                Image.asset(
                  'assets/images/logos/bbp logo-50px.png',
                  height: 32,
                  width: 32,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Text(
                  'B.B.P. Tracker',
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    // Calculate counts for each filter
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayCount = _myTasks.where((task) {
      if (task.dateOfCollection == null) return false;
      final collectionDate = DateTime(
        task.dateOfCollection!.year,
        task.dateOfCollection!.month,
        task.dateOfCollection!.day,
      );
      return collectionDate == today;
    }).length;

    final allCount = _myTasks.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing24),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight, width: 1),
        ),
        child: Stack(
          children: [
            // Animated sliding background
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: _collectionFilter == 'today'
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            // Tab buttons
            Row(
              children: [
                Expanded(
                  child: _buildCompactFilterChip(
                    label: 'Today',
                    count: todayCount,
                    isSelected: _collectionFilter == 'today',
                    onTap: () {
                      setState(() {
                        _collectionFilter = 'today';
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _buildCompactFilterChip(
                    label: 'All',
                    count: allCount,
                    isSelected: _collectionFilter == 'all',
                    onTap: () {
                      setState(() {
                        _collectionFilter = 'all';
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
              child: Text(label),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isSelected ? Colors.white : AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  child: Text(count.toString()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<CollectorTask> _getFilteredTasks() {
    if (_collectionFilter == 'today') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return _myTasks.where((task) {
        if (task.dateOfCollection == null) return false;

        final collectionDate = DateTime(
          task.dateOfCollection!.year,
          task.dateOfCollection!.month,
          task.dateOfCollection!.day,
        );

        return collectionDate == today;
      }).toList();
    }

    return _myTasks;
  }

  Widget _buildCollectionsList() {
    if (!isAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacing32),
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Column(
            children: [
              Icon(
                Icons.power_settings_new,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              Text(
                'You\'re currently offline',
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Text(
                'Turn on availability to start receiving collection requests',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_loadingTasks) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorTasks != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: AppColors.errorColor),
              const SizedBox(height: 12),
              Text(
                'Failed to load tasks',
                style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _errorTasks!,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Use filtered tasks instead of all tasks
    final filteredTasks = _getFilteredTasks();
    final availableCollections = filteredTasks
        .map((t) => _mapTaskToCardData(t))
        .toList();

    if (!isAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacing32),
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Column(
            children: [
              Icon(
                Icons.power_settings_new,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              Text(
                'You\'re currently offline',
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Text(
                'Turn on availability to start receiving collection requests',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (availableCollections.isEmpty) {
      // Show different message based on filter
      final isFilteringToday = _collectionFilter == 'today';

      // Find nearest collection date if filtering today
      DateTime? nearestDate;
      if (isFilteringToday && _myTasks.isNotEmpty) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final futureDates =
            _myTasks
                .where((task) => task.dateOfCollection != null)
                .map(
                  (task) => DateTime(
                    task.dateOfCollection!.year,
                    task.dateOfCollection!.month,
                    task.dateOfCollection!.day,
                  ),
                )
                .where((date) => date.isAfter(today))
                .toList()
              ..sort();

        if (futureDates.isNotEmpty) {
          nearestDate = futureDates.first;
        }
      }

      String emptyMessage;
      if (isFilteringToday && nearestDate != null) {
        final months = [
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
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final formattedDate =
            '${days[nearestDate.weekday - 1]}, ${months[nearestDate.month - 1]} ${nearestDate.day}';
        emptyMessage =
            'Your next collection is scheduled for $formattedDate. Check \'All\' to see all upcoming collections.';
      } else if (isFilteringToday) {
        emptyMessage =
            'You don\'t have any collections scheduled for today. Check \'All\' to see upcoming collections.';
      } else {
        emptyMessage =
            'Great job! You\'re all caught up with your collections.';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
          vertical: AppDimensions.spacing32,
        ),
        child: Center(
          child: Text(
            emptyMessage,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing24),
      child: Column(
        children: availableCollections.map((collection) {
          return GestureDetector(
            onTap: () async {
              final wasCompleted = await Navigator.pushNamed(
                context,
                '/collector-task-details',
                arguments: {
                  'taskId': collection['id'] ?? '',
                  'householdId': collection['householdId'],
                  'docPath': collection['docPath'],
                },
              );
              // Reload tasks if task was completed
              if (wasCompleted == true && mounted) {
                _fetchMyTasks();
              }
            },
            child: _buildCollectionCard(collection),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> collection) {
    bool isHighPriority = collection['priority'] == 'high';
    final taskId = collection['id'] as String;

    // If this task is active (en_route), subscribe to live data from activeCollections
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('active_collections')
          .stream(primaryKey: ['posting_id'])
          .eq('posting_id', taskId),
      builder: (context, snapshot) {
        // Use live data if available, otherwise use static task data
        Map<String, dynamic> displayData = Map.from(collection);

        debugPrint('🚗 [COLLECTOR] Checking activeCollections for $taskId');
        debugPrint('   - snapshot.hasData: ${snapshot.hasData}');
        debugPrint('   - rows: ${snapshot.data?.length}');

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final liveData = snapshot.data!.first;
          final distanceKm = (liveData['distance_remaining'] as num?)
              ?.toDouble();

          debugPrint('   - distanceRemaining: $distanceKm');

          if (distanceKm != null) {
            // Update distance
            displayData['distance'] = '${distanceKm.toStringAsFixed(2)} km';

            // Calculate ETA using same 20 km/h speed as LocationTrackingService
            final etaMinutes = (distanceKm / 20.0 * 60).round();
            if (etaMinutes < 60) {
              displayData['eta'] = '$etaMinutes min';
            } else {
              final h = etaMinutes ~/ 60;
              final rem = etaMinutes % 60;
              displayData['eta'] = rem > 0 ? '${h}h ${rem}m' : '${h}h';
            }

            debugPrint(
              '   - Updated: ${displayData['distance']}, ${displayData['eta']}',
            );
          }
        } else {
          debugPrint(
            '   - No live data, using static values: ${displayData['distance']}, ${displayData['eta']}',
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: isHighPriority
                  ? AppColors.warningColor
                  : AppColors.borderLight,
              width: isHighPriority ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Priority Banner
              if (isHighPriority)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warningColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppDimensions.radiusLg - 1),
                      topRight: Radius.circular(AppDimensions.radiusLg - 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'HIGH PRIORITY',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.white, width: 2),
                          ),
                        ),
                        child: Text(
                          (displayData['windowTime'] ?? 'Anytime today')
                              .toString(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Card Content
              Padding(
                padding: EdgeInsets.all(
                  isHighPriority
                      ? AppDimensions.spacing16
                      : AppDimensions.spacing16,
                ),
                child: Column(
                  children: [
                    // Header Section
                    Container(
                      padding: const EdgeInsets.only(
                        bottom: AppDimensions.spacing12,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Collection Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (displayData['household'] ?? 'Household')
                                      as String,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  (displayData['address'] ??
                                          'Address not available')
                                      as String,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Price
                          Text(
                            (displayData['price'] ?? '—').toString(),
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.successColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Categories
                    const SizedBox(height: AppDimensions.spacing12),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children:
                                ((displayData['categories'] as List?)
                                            ?.cast<String>() ??
                                        const <String>[])
                                    .map((category) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.backgroundDark,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          category,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                        ),
                                      );
                                    })
                                    .toList(),
                          ),
                        ),
                      ],
                    ),

                    // Details Grid
                    const SizedBox(height: AppDimensions.spacing16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Distance',
                            displayData['distance'],
                          ),
                        ),
                        Expanded(
                          child: _buildDetailItem('ETA', displayData['eta']),
                        ),
                        Expanded(
                          child: _buildDetailItem(
                            'Weight',
                            displayData['estWeight'],
                          ),
                        ),
                      ],
                    ),

                    // Action Button
                    const SizedBox(height: AppDimensions.spacing16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final wasCompleted = await Navigator.pushNamed(
                            context,
                            '/collector/task-details',
                            arguments: {
                              'taskId': displayData['id'],
                              'householdId': displayData['householdId'],
                              'docPath': displayData['docPath'],
                            },
                          );
                          // Reload tasks if task was completed
                          if (wasCompleted == true && mounted) {
                            _fetchMyTasks();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: AppColors.textWhite,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'View Details',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _mapTaskToCardData(CollectorTask task) {
    String? distanceStr;
    if (task.distanceKm != null) {
      distanceStr = '${task.distanceKm!.toStringAsFixed(2)} km';
    }
    String? etaStr;
    if (task.etaMinutes != null) {
      final m = task.etaMinutes!;
      if (m < 60) {
        etaStr = '$m min';
      } else {
        final h = (m / 60).floor();
        final rem = m % 60;
        etaStr = rem > 0 ? '${h}h ${rem}m' : '${h}h';
      }
    }
    String? weightStr;
    if (task.estWeightKg != null) {
      weightStr = '${task.estWeightKg!.toStringAsFixed(1)} kg';
    }

    // Use addressShort or fallback to a generic message
    final address = task.addressShort ?? 'Address not specified';

    return {
      'id': task.id,
      'householdId': task.householdId,
      'docPath': task.docPath,
      'household': task.householdName ?? 'Household',
      'address': address,
      'status': task.status,
      'price': '₱${task.totalValue.toStringAsFixed(2)}',
      'windowTime': _formatWindowTime(task.assignedAt),
      'estWeight': weightStr, // Will show '-' if null
      'categories': task.items,
      'distance': distanceStr, // Will show '-' if null
      'eta': etaStr, // Will show '-' if null
      'priority': _determinePriority(task.totalValue),
    };
  }

  String _formatWindowTime(DateTime? dt) {
    if (dt == null) return 'Anytime today';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:00 $ampm';
  }

  String _determinePriority(double? totalValue) {
    if ((totalValue ?? 0) >= 300) return 'high';
    return 'normal';
  }

  // Greeting message defined at the end of file using _myTasks

  Widget _buildDetailItem(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value ?? '-',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home
              _buildNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                isActive: true,
                onTap: () {
                  if (widget.onNavSelected != null) {
                    widget.onNavSelected!(0);
                  }
                },
              ),

              // Collections
              _buildNavItem(
                icon: Icons.list_alt_outlined,
                label: 'Collections',
                isActive: false,
                onTap: () {
                  if (widget.onNavSelected != null) {
                    widget.onNavSelected!(1);
                  } else {
                    Navigator.pushNamed(context, '/collector/collections');
                  }
                },
              ),

              // Power Button (Availability Toggle)
              _buildPowerButton(),

              // Messages
              _buildNavItem(
                icon: Icons.chat_bubble_outline,
                label: 'Messages',
                isActive: false,
                onTap: () {
                  if (widget.onNavSelected != null) {
                    widget.onNavSelected!(2);
                  } else {
                    // Prefer shell route so bottom nav persists
                    Navigator.pushNamed(context, '/collector/messages');
                  }
                },
              ),

              // Profile
              _buildNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                isActive: false,
                onTap: () {
                  if (widget.onNavSelected != null) {
                    widget.onNavSelected!(3);
                  } else {
                    Navigator.pushNamed(context, '/collector/profile');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? AppColors.primaryBlue : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isActive
                    ? AppColors.primaryBlue
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            isAvailable = !isAvailable;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -35),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppColors.successColor
                      : AppColors.textSecondary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundLight,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.power_settings_new,
                    color: AppColors.textWhite,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
