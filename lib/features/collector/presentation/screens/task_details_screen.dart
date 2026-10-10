import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/utils/app_image_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../widgets/customer_info_card.dart';
import '../widgets/waste_items_list.dart';
import '../widgets/photo_verification_section.dart';
import '../widgets/status_action_bar.dart';
import '../widgets/editable_waste_items_list.dart';
import '../widgets/cancel_pickup_dialog.dart';
import '../widgets/reschedule_pickup_dialog.dart';
import '../../../messaging/data/repositories/chat_repository.dart';
import '../../../messaging/data/services/conversation_sync_service.dart';
import '../../data/services/location_tracking_service.dart';
import '../../data/services/date_validation_service.dart';
import '../../../../core/utils/phone_launcher.dart';

String _fmtAmt(double v, {int decimals = 2}) => NumberFormat(
  '#,##0${decimals > 0 ? '.' + '0' * decimals : ''}',
  'en_US',
).format(v);

/// Server-side timestamp substitute (the DB has no per-field server timestamps
/// for these jsonb/timeline fields; use the device clock in UTC).
Timestamp _serverTs() => Timestamp.now();

/// Thin handle for one row of the `postings` table that exposes the
/// document-style `get()` / `update()` / `set()` calls this screen relies on.
/// Legacy-shaped document maps are converted with `docToRow`; unknown keys are
/// merged into the `extra` jsonb column instead of overwriting it.
class _PostingRef {
  _PostingRef(this.id);
  final String id;

  String get path => 'postings/$id';

  Future<Map<String, dynamic>?> get() async {
    final row = await supabase
        .from('postings')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : rowToDoc('postings', row);
  }

  Future<void> update(Map<String, dynamic> doc) async {
    final row = docToRow('postings', doc);
    final unknownNullKeys = <String>[
      for (final e in doc.entries)
        if (e.value == null && docToRow('postings', {e.key: null}).isEmpty)
          e.key,
    ];
    if (row.containsKey('extra') || unknownNullKeys.isNotEmpty) {
      final current = await supabase
          .from('postings')
          .select('extra')
          .eq('id', id)
          .maybeSingle();
      final merged = Map<String, dynamic>.from(
        (current?['extra'] as Map?) ?? const {},
      );
      final incoming = row['extra'];
      if (incoming is Map) {
        merged.addAll(Map<String, dynamic>.from(incoming));
      }
      for (final k in unknownNullKeys) {
        merged.remove(k);
      }
      row['extra'] = merged;
    }
    if (row.isEmpty) return;
    await supabase.from('postings').update(row).eq('id', id);
  }

  /// `set(data, merge: true)` equivalent.
  Future<void> set(Map<String, dynamic> doc) => update(doc);
}

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;
  final String? householdId; // Prefer direct document fetch when available
  final String? docPath; // Legacy (ignored): postings are fetched by taskId

  const TaskDetailsScreen({
    super.key,
    required this.taskId,
    this.householdId,
    this.docPath,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  // Firestore handle for this posting document
  _PostingRef? _taskDocRef;

  // UI/state data mapped from Firestore
  final Map<String, dynamic> _taskData = {
    'id': '',
    'postingId': '',
    'title': 'Collection Task',
    'customerName': '',
    'customerPhone': '',
    'address': 'Address not available',
    'fullAddress': '',
    'latitude': null,
    'longitude': null,
    'scheduledTime': '',
    'estimatedEarnings': 0.0,
    'estimatedWeight': 0.0,
    'priority': 'normal',
    'specialInstructions': '',
    'notes': '',
    'postingImages': <String>[],
    'wasteItems': <Map<String, dynamic>>[],
    'photos': <String, List<String>>{
      'arrival': <String>[],
      'collection': <String>[],
      'payment': <String>[],
    },
    'assignedJunkshopId': null,
    // Travel cost data (TEST VALUES - replace with actual Firestore data)
    'distance': 5.2, // km from household to junkshop
    'baseFee': 50.0, // Base collection fee in pesos
    'distanceFee': 10.0, // Fee per km in pesos
    'collectionFee': 0.0, // Collection Fee deducted from household payout
    'householdPayment': 0.0, // Amount paid to household (total - collectionFee)
  };

  String _currentStatus = 'assigned';
  final ScrollController _scrollController = ScrollController();
  GoogleMapController? _mapController;
  Position? _collectorPosition;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Navigation/Directions state
  Set<Polyline> _polylines = {};
  String _routeDistance = '';
  String _routeDuration = '';
  LatLng? _lastFetchedPosition;
  DateTime? _lastRouteFetch;

  // Real-time location tracking
  final LocationTrackingService _trackingService = LocationTrackingService();
  final DateValidationService _dateValidationService = DateValidationService();
  final ConversationSyncService _conversationSyncService =
      ConversationSyncService();
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _createCustomMarkers();
    _initializeAndLoad();
  }

  // Initialize location and load task data before restoring navigation
  Future<void> _initializeAndLoad() async {
    // Load task data first to ensure coordinates are available
    await _loadTask();
    // Then initialize location and restore navigation state
    await _initializeLocation();
  }

  // Initialize location and then restore navigation state
  Future<void> _initializeLocation() async {
    await _getCurrentLocation();
    // Only restore navigation after location is available
    await _loadNavigationState();
    // Start listening to position updates
    _startPositionTracking();
  }

  // Start real-time position tracking
  void _startPositionTracking() {
    debugPrint('📍 [POSITION TRACKING] Starting real-time updates...');

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update every 10 meters
          ),
        ).listen((Position position) {
          if (!mounted) return;

          setState(() {
            _collectorPosition = position;
          });

          debugPrint(
            '📍 [POSITION UPDATE] New position: ${position.latitude}, ${position.longitude}',
          );

          // Auto-update route if directions are active and collector moved significantly
          if (_polylines.isNotEmpty) {
            _updateRouteIfNeeded(position);
          }
        });
  }

  // Update route if collector has moved significantly and enough time has passed
  void _updateRouteIfNeeded(Position newPosition) {
    final lat = _taskData['latitude'] as double?;
    final lng = _taskData['longitude'] as double?;

    if (lat == null || lng == null) return;

    final newLatLng = LatLng(newPosition.latitude, newPosition.longitude);

    // Check if we should update (time-based debouncing)
    final now = DateTime.now();
    if (_lastRouteFetch != null) {
      final timeSinceLastFetch = now.difference(_lastRouteFetch!);
      if (timeSinceLastFetch.inSeconds < 30) {
        debugPrint(
          '📍 [ROUTE UPDATE] Skipped - too soon (${timeSinceLastFetch.inSeconds}s)',
        );
        return;
      }
    }

    // Check if collector moved significantly (distance-based)
    if (_lastFetchedPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastFetchedPosition!.latitude,
        _lastFetchedPosition!.longitude,
        newLatLng.latitude,
        newLatLng.longitude,
      );

      if (distance < 200) {
        // Less than 200 meters
        debugPrint(
          '📍 [ROUTE UPDATE] Skipped - distance too small (${distance.toStringAsFixed(1)}m)',
        );
        return;
      }
    }

    debugPrint('📍 [ROUTE UPDATE] Fetching new route...');
    _fetchDirections();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _scrollController.dispose();
    _sheetController.dispose();
    _mapController?.dispose();
    // Cancel conversation sync when leaving the screen
    final conversationId =
        _taskData['conversationId'] as String? ?? 'posting_${widget.taskId}';
    _conversationSyncService.cancelSync(conversationId);
    super.dispose();
  }

  // Load persisted navigation state for this task
  Future<void> _loadNavigationState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'navigation_${widget.taskId}';
    final isNavigating = prefs.getBool(key) ?? false;

    debugPrint(
      '📍 [NAVIGATION STATE] Loaded for ${widget.taskId}: $isNavigating',
    );

    if (isNavigating && mounted) {
      if (_collectorPosition != null) {
        // Restore directions if they were previously enabled and location is available
        debugPrint('📍 [NAVIGATION STATE] Restoring directions...');
        _fetchDirections();
      } else {
        // Wait for position with timeout (up to 5 seconds)
        debugPrint('📍 [NAVIGATION STATE] Waiting for collector position...');
        int attempts = 0;
        while (_collectorPosition == null && attempts < 10 && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
        }

        if (_collectorPosition != null && mounted) {
          debugPrint(
            '📍 [NAVIGATION STATE] Position acquired, restoring directions...',
          );
          _fetchDirections();
        } else {
          debugPrint(
            '📍 [NAVIGATION STATE] Timeout - collector position not available',
          );
        }
      }
    }
  }

  // Save navigation state for this task
  Future<void> _saveNavigationState(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'navigation_${widget.taskId}';
    await prefs.setBool(key, enabled);

    debugPrint('📍 [NAVIGATION STATE] Saved for ${widget.taskId}: $enabled');
  }

  Future<void> _loadTask() async {
    try {
      // First, check if the collection date has passed and reset if needed
      final user = supabase.auth.currentUser;
      if (user != null && widget.householdId != null) {
        try {
          final wasReset = await _dateValidationService
              .checkAndResetIfDatePassed(
                householdId: widget.householdId!,
                postingId: widget.taskId,
                collectorId: user.id,
                collectorName: null, // Will be fetched from Firestore if needed
              );

          if (wasReset) {
            // Show message and go back
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This collection was reset to pending because the scheduled date has passed.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
              Navigator.of(context).pop();
            }
            return;
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Error checking collection date: $e');
          // Continue loading even if check fails
        }
      }

      Map<String, dynamic>? loadedData;

      final postingRow = await supabase
          .from('postings')
          .select()
          .eq('id', widget.taskId)
          .maybeSingle();
      if (postingRow != null) {
        _taskDocRef = _PostingRef(widget.taskId);
        loadedData = rowToDoc('postings', postingRow);
      }

      // If not found, show error
      if (loadedData == null) {
        if (kDebugMode) {
          print(
            '[TaskDetails] ERROR: Task not found for taskId=${widget.taskId} householdId=${widget.householdId}',
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Task not found')));
        }
        return;
      }
      final data = loadedData;


      // Map Firestore fields to UI state (nested-safe)
      setState(() {
        _taskData['id'] = widget.taskId;
        _taskData['postingId'] = data['id']?.toString() ?? widget.taskId;

        // Nested household support
        final household = data[PostingFields.household];
        String? hhName = data[PostingFields.householdName]?.toString();
        String? hhPhone = data[PostingFields.householdPhone]?.toString();
        String? shortAddr = data[PostingFields.addressShort]?.toString();
        String? fullAddr = data[UserFields.address]?.toString();
        if (household is Map<String, dynamic>) {
          hhName ??=
              household[UserFields.fullName]?.toString() ??
              household[UserFields.name]?.toString();
          hhPhone ??=
              household[UserFields.phone]?.toString() ??
              household[UserFields.phoneNumber]?.toString();
          final hLoc = household[UserFields.location];
          if (hLoc is Map<String, dynamic>) {
            fullAddr ??= hLoc[UserFields.address]?.toString();
          }
          fullAddr ??= household[UserFields.address]?.toString();
        }
        _taskData['customerName'] = hhName ?? '';
        _taskData['customerPhone'] = hhPhone ?? '';
        _taskData['address'] = shortAddr ?? fullAddr ?? 'Address not available';
        _taskData['fullAddress'] = fullAddr ?? shortAddr ?? '';

        // Coordinates (if available)
        double? lat;
        double? lng;

        if (kDebugMode) {
          print('[TaskDetails] 🗺️ Extracting household location:');
        }
        if (kDebugMode) {
          print('[TaskDetails]    Full data keys: ${data.keys.toList()}');
        }

        if (household is Map<String, dynamic>) {
          if (kDebugMode) {
            print(
              '[TaskDetails]    household keys: ${household.keys.toList()}',
            );
          }

          // First, try to get from household.location
          final hLoc = household[UserFields.location];
          if (kDebugMode) {
            print('[TaskDetails]    location type: ${hLoc.runtimeType}');
          }
          if (hLoc is Map<String, dynamic>) {
            if (kDebugMode) {
              print('[TaskDetails]    location keys: ${hLoc.keys.toList()}');
            }
            final la = hLoc['lat'] ?? hLoc['latitude'];
            final lo = hLoc['lng'] ?? hLoc['lon'] ?? hLoc['longitude'];
            if (kDebugMode) {
              print('[TaskDetails]    location.lat: $la (${la.runtimeType})');
            }
            if (kDebugMode) {
              print('[TaskDetails]    location.lng: $lo (${lo.runtimeType})');
            }
            if (la is num) lat = la.toDouble();
            if (lo is num) lng = lo.toDouble();
          }

          // If not found in location, try directly in household object
          if (lat == null || lng == null) {
            final la = household['lat'] ?? household['latitude'];
            final lo =
                household['lng'] ?? household['lon'] ?? household['longitude'];
            if (kDebugMode) {
              print('[TaskDetails]    household.lat: $la (${la.runtimeType})');
            }
            if (kDebugMode) {
              print('[TaskDetails]    household.lng: $lo (${lo.runtimeType})');
            }
            if (la is num) lat = la.toDouble();
            if (lo is num) lng = lo.toDouble();
          }
        }

        // Fallback: try root-level coordinates (legacy data)
        if (lat == null || lng == null) {
          if (kDebugMode) {
            print('[TaskDetails]    Trying root-level coordinates...');
          }
          final rootLat = data['latitude'] ?? data['lat'];
          final rootLng = data['longitude'] ?? data['lng'] ?? data['lon'];
          if (kDebugMode) {
            print(
              '[TaskDetails]    root lat: $rootLat (${rootLat.runtimeType})',
            );
          }
          if (kDebugMode) {
            print(
              '[TaskDetails]    root lng: $rootLng (${rootLng.runtimeType})',
            );
          }
          if (rootLat is num) lat = rootLat.toDouble();
          if (rootLng is num) lng = rootLng.toDouble();
        }

        // Final fallback: try pickupLocation object
        if (lat == null || lng == null) {
          final pickupLoc = data['pickupLocation'];
          if (pickupLoc is Map<String, dynamic>) {
            if (kDebugMode) {
              print(
                '[TaskDetails]    Trying pickupLocation: ${pickupLoc.keys.toList()}',
              );
            }
            final la = pickupLoc['lat'] ?? pickupLoc['latitude'];
            final lo =
                pickupLoc['lng'] ?? pickupLoc['lon'] ?? pickupLoc['longitude'];
            if (la is num) lat = la.toDouble();
            if (lo is num) lng = lo.toDouble();
          }
        }

        if (kDebugMode) {
          print('[TaskDetails] 📍 Final coordinates: lat=$lat, lng=$lng');
        }
        _taskData['latitude'] = lat;
        _taskData['longitude'] = lng;

        _taskData['scheduledTime'] = _formatScheduledTime(data);

        // Items container can be a List or a Map { list: [...], totalEstimatedValue, estimatedTotalWeight }
        final itemsContainer = data[PostingFields.items];
        List<dynamic> itemsList = const [];
        num? nestedTotalValue;
        num? nestedTotalWeight;
        if (itemsContainer is List) {
          itemsList = itemsContainer;
        } else if (itemsContainer is Map<String, dynamic>) {
          final l = itemsContainer[PostingFields.itemsList];
          if (l is List) itemsList = l;
          final t = itemsContainer[PostingFields.totalEstimatedValue];
          if (t is num) nestedTotalValue = t;
          final w = itemsContainer[PostingFields.estimatedTotalWeight];
          if (w is num) nestedTotalWeight = w;
        }

        double estEarnings = (data[PostingFields.totalEstimatedValue] is num)
            ? (data[PostingFields.totalEstimatedValue] as num).toDouble()
            : (nestedTotalValue?.toDouble() ?? 0.0);

        // Weight: prefer field, fallback to nested, else compute from items if unit==kg
        double estWeight = (data[PostingFields.estimatedTotalWeight] is num)
            ? (data[PostingFields.estimatedTotalWeight] as num).toDouble()
            : (nestedTotalWeight?.toDouble() ?? 0.0);
        if (estWeight == 0.0 && itemsList.isNotEmpty) {
          double accum = 0.0;
          for (final it in itemsList) {
            if (it is Map<String, dynamic>) {
              final unit = it[PostingFields.itemUnit]?.toString() ?? '';
              final qty = it[PostingFields.itemQuantity];
              final qtyNum = qty is num
                  ? qty.toDouble()
                  : double.tryParse(qty?.toString() ?? '');
              final weightExplicit = it[PostingFields.itemWeightKg];
              if (weightExplicit is num) {
                accum += weightExplicit.toDouble();
              } else if (unit.toLowerCase() == 'kg' && qtyNum != null) {
                accum += qtyNum;
              }
            }
          }
          estWeight = accum;
        }

        _taskData['estimatedEarnings'] =
            data[PostingFields.totalVerifiedValue] is num
            ? (data[PostingFields.totalVerifiedValue] as num).toDouble()
            : estEarnings;
        _taskData['estimatedWeight'] = estWeight;

        _currentStatus = data[PostingFields.status]?.toString() ?? 'assigned';

        // Extract junkshop ID for fetching materials
        _taskData['assignedJunkshopId'] =
            data[PostingFields.assignedJunkshopId]?.toString() ??
            (data[PostingFields.junkshop] as Map?)?['id']?.toString();

        _taskData['specialInstructions'] =
            data[PostingFields.specialInstructions]?.toString() ?? '';
        _taskData['notes'] = data[PostingFields.notes]?.toString() ?? '';

        // Date fields
        final createdTs = data[PostingFields.createdAt];
        if (createdTs is Timestamp) {
          _taskData['createdAt'] = createdTs.toDate();
        }

        final collectionTs = data[PostingFields.dateOfCollection];
        if (collectionTs is Timestamp) {
          _taskData['dateOfCollection'] = collectionTs.toDate();
        }

        // Collection Fee (set by junkshop when assigning collector)
        final collectionFeeVal = data['collectionFee'];
        if (collectionFeeVal is num) {
          _taskData['collectionFee'] = collectionFeeVal.toDouble();
        }

        // Unavailable dates (dates household is NOT available)
        final unavailableDatesData = data[PostingFields.unavailableDates];
        if (unavailableDatesData is List) {
          _taskData['unavailableDates'] = unavailableDatesData
              .whereType<Timestamp>()
              .map((ts) => ts.toDate())
              .toList();
        }

        // Items mapping with detailed information
        final rawItems = (itemsContainer is Map<String, dynamic>)
            ? itemsContainer[PostingFields.itemsList]
            : itemsContainer;
        final items = <Map<String, dynamic>>[];
        final imageUrls = <String>[];
        if (rawItems is List) {
          for (final it in rawItems) {
            if (it is Map<String, dynamic>) {
              // Get quantity - stored as int in Firestore
              final quantity = (it[PostingFields.itemQuantity] is num)
                  ? (it[PostingFields.itemQuantity] as num).toDouble()
                  : (double.tryParse(
                          it[PostingFields.itemQuantity]?.toString() ?? '1',
                        ) ??
                        1.0);

              // estimatedValue is the TOTAL value for the item (quantity × price per unit)
              final totalEstimatedValue =
                  (it[PostingFields.itemEstimatedValue] is num)
                  ? (it[PostingFields.itemEstimatedValue] as num).toDouble()
                  : 0.0;

              // Calculate price per unit from total estimated value
              final pricePerUnit = quantity > 0
                  ? (totalEstimatedValue / quantity)
                  : 0.0;

              items.add({
                'type': it[PostingFields.itemName]?.toString() ?? 'Item',
                'category':
                    it[PostingFields.itemCategory]?.toString() ?? 'Mixed',
                'condition': it[PostingFields.itemCondition]?.toString() ?? '',
                'weight': _formatWeight(
                  it[PostingFields.itemQuantity],
                  it[PostingFields.itemUnit],
                ),
                'quantity': quantity,
                'unit': it[PostingFields.itemUnit]?.toString() ?? '',
                'price': totalEstimatedValue,
                'pricePerUnit': pricePerUnit,
                'priceMin': it['priceMin'], // Household's base price min
                'priceMax': it['priceMax'], // Household's base price max
                'householdPriceMin':
                    it['priceMin'], // For display in info banner
                'householdPriceMax':
                    it['priceMax'], // For display in info banner
                'promotionBoostPercentage': it['promotionBoostPercentage'],
                'promotionId': it['promotionId'],
              });

              // Extract images from each item
              final itemImages = it[PostingFields.itemImagePaths];
              if (itemImages is List) {
                for (final img in itemImages) {
                  if (img is String && img.isNotEmpty) {
                    imageUrls.add(img);
                  }
                }
              }
            }
          }
        }
        _taskData['wasteItems'] = items;

        // Extract verifiedItems - handle both Map structure (from Firestore) and List structure
        final rawVerifiedItems = data[PostingFields.verifiedItems];
        if (rawVerifiedItems is Map<String, dynamic>) {
          // Firestore structure: {items: [...], totalValue: X, verifiedAt: T, verifiedBy: U}
          final verifiedItemsList = rawVerifiedItems['items'];
          _taskData['verifiedItems'] = verifiedItemsList is List
              ? verifiedItemsList
              : items;
          debugPrint(
            '[TaskDetails] Loaded verifiedItems from Map structure: ${(verifiedItemsList as List?)?.length ?? 0} items',
          );
        } else if (rawVerifiedItems is List) {
          // Direct list structure
          _taskData['verifiedItems'] = rawVerifiedItems;
          debugPrint(
            '[TaskDetails] Loaded verifiedItems from List structure: ${rawVerifiedItems.length} items',
          );
        } else {
          // No verifiedItems - will be auto-created by _ensureVerifiedItemsExist
          _taskData['verifiedItems'] = null;
          debugPrint('[TaskDetails] No verifiedItems found, will auto-create');
        }

        _taskData['postingImages'] = imageUrls;

        // Photos
        final photos = <String, List<String>>{
          'arrival': <String>[],
          'collection': <String>[],
          'payment': <String>[],
        };
        final rawPhotos = data['photos'];
        if (rawPhotos is Map<String, dynamic>) {
          for (final k in photos.keys) {
            final arr = rawPhotos[k];
            if (arr is List) {
              photos[k] = arr.map((e) => e.toString()).toList();
            }
          }
        }
        _taskData['photos'] = photos;
      });

      // Start conversation sync service to keep conversation status in sync with posting
      if (widget.householdId != null && _taskDocRef != null) {
        final conversationId =
            data['conversationId'] as String? ?? 'posting_${widget.taskId}';
        _conversationSyncService.syncConversationWithPosting(
          widget.householdId!,
          widget.taskId,
          conversationId,
        );
        debugPrint('✅ Started conversation sync for posting ${widget.taskId}');
      }

      // Auto-populate verifiedItems if they don't exist
      // This ensures collector sees items immediately without manual reload
      await _ensureVerifiedItemsExist();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load task: $e')));
    }
  }

  String _formatScheduledTime(Map<String, dynamic>? data) {
    // If you store windows, adapt here; fallback empty string
    return '';
  }

  String _formatWeight(dynamic quantity, dynamic unit) {
    final q = (quantity == null) ? '' : quantity.toString();
    final u = (unit == null) ? '' : unit.toString();
    if (q.isEmpty && u.isEmpty) return '';
    return '$q $u'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Stack(
          children: [
            // Full-screen map background
            _buildFullScreenMap(),

            // Top status bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopStatusBar(context),
            ),

            // Draggable bottom sheet with all details
            _buildDraggableDetailsSheet(),
          ],
        ),
      ),
    );
  }

  // Get current collector location
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) print('[TaskDetails] Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) print('[TaskDetails] Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('[TaskDetails] Location permission denied forever');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _collectorPosition = position;
        });
        if (kDebugMode) {
          print(
            '[TaskDetails] Got collector position: ${position.latitude}, ${position.longitude}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('[TaskDetails] Error getting location: $e');
    }
  }

  // Build full-screen map
  Widget _buildFullScreenMap() {
    final lat = _taskData['latitude'] as double?;
    final lng = _taskData['longitude'] as double?;

    if (lat == null || lng == null) {
      return Container(
        color: Colors.grey[300],
        child: const Center(child: Text('Map not available')),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng),
            zoom: 14,
          ),
          markers: _buildMarkers(),
          polylines: _polylines,
          onMapCreated: (controller) {
            _mapController = controller;
            _fitBothMarkers();
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),

        // Map control buttons (right side)
        Positioned(
          right: 16,
          bottom: MediaQuery.of(context).size.height * 0.19,
          child: Column(
            children: [
              // Navigation/Directions button
              IconButton(
                icon: Icon(
                  _polylines.isEmpty ? Icons.directions : Icons.clear_all,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  if (_polylines.isEmpty) {
                    _fetchDirections();
                    _saveNavigationState(true);
                  } else {
                    setState(() {
                      _polylines = {};
                      _routeDistance = '';
                      _routeDuration = '';
                    });
                    _saveNavigationState(false);
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: _polylines.isEmpty
                      ? const Color(0xFF10B981)
                      : Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(
                  Icons.zoom_out_map_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _fitBothMarkers,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _centerOnHousehold,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _centerOnCollector,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ),

        // Route info card (distance & duration) - Shows Directions API data
        if (_routeDistance.isNotEmpty && _routeDuration.isNotEmpty)
          Positioned(
            left: 16,
            bottom: MediaQuery.of(context).size.height * 0.19,
            child: Builder(
              builder: (context) {
                debugPrint(
                  '🚗 [CARD] Displaying: $_routeDistance • $_routeDuration',
                );
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_routeDistance • $_routeDuration',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final lat = _taskData['latitude'] as double?;
    final lng = _taskData['longitude'] as double?;

    if (lat != null && lng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('household'),
          position: LatLng(lat, lng),
          icon:
              _householdMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Household'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (_collectorPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('collector'),
          position: LatLng(
            _collectorPosition!.latitude,
            _collectorPosition!.longitude,
          ),
          icon:
              _collectorMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'My Location'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    return markers;
  }

  BitmapDescriptor? _householdMarker;
  BitmapDescriptor? _collectorMarker;

  Future<void> _createCustomMarkers() async {
    _householdMarker = await _createMarkerIcon(Icons.home_rounded, Colors.red);
    _collectorMarker = await _createMarkerIcon(
      Icons.local_shipping_rounded,
      AppColors.primaryGreen,
    );
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createMarkerIcon(IconData icon, Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = 100.0;
    const circleRadius = 40.0;
    const circleCenter = Offset(size / 2, size / 2);

    // Draw white border circle
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(circleCenter, circleRadius + 4, whitePaint);

    // Draw colored circle
    final colorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(circleCenter, circleRadius, colorPaint);

    // Draw icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 42,
        fontFamily: icon.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        circleCenter.dx - textPainter.width / 2,
        circleCenter.dy - textPainter.height / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: 2.5,
    );
  }

  void _fitBothMarkers() {
    final lat = _taskData['latitude'] as double?;
    final lng = _taskData['longitude'] as double?;

    if (_mapController == null || lat == null || lng == null) {
      debugPrint(
        '[TaskDetails] Cannot fit markers - controller or coordinates null',
      );
      return;
    }

    if (_collectorPosition == null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14),
      );
      return;
    }

    try {
      final bounds = LatLngBounds(
        southwest: LatLng(
          lat < _collectorPosition!.latitude
              ? lat
              : _collectorPosition!.latitude,
          lng < _collectorPosition!.longitude
              ? lng
              : _collectorPosition!.longitude,
        ),
        northeast: LatLng(
          lat > _collectorPosition!.latitude
              ? lat
              : _collectorPosition!.latitude,
          lng > _collectorPosition!.longitude
              ? lng
              : _collectorPosition!.longitude,
        ),
      );

      // Use slightly zoomed out view to account for header and bottom sheet
      _mapController!
          .animateCamera(CameraUpdate.newLatLngBounds(bounds, 100))
          .then((_) {
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
          })
          .catchError((error) {
            debugPrint('[TaskDetails] Error animating camera: $error');
          });
    } catch (e) {
      debugPrint('[TaskDetails] Error fitting bounds: $e');
    }
  }

  void _centerOnHousehold() {
    final lat = _taskData['latitude'] as double?;
    final lng = _taskData['longitude'] as double?;

    debugPrint('[TaskDetails] 🏠 Center on household button pressed');
    debugPrint(
      '[TaskDetails] Coordinates: lat=$lat, lng=$lng, controller=${_mapController != null}',
    );

    if (_mapController == null) {
      debugPrint('[TaskDetails] ❌ Map controller is null');
      return;
    }

    if (lat == null || lng == null) {
      debugPrint('[TaskDetails] ❌ Coordinates are null');
      return;
    }

    try {
      debugPrint('[TaskDetails] ✅ Animating to household location');
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
      );
    } catch (e) {
      debugPrint('[TaskDetails] ❌ Error centering on household: $e');
    }
  }

  void _centerOnCollector() {
    debugPrint('[TaskDetails] 📍 Center on collector button pressed');
    debugPrint(
      '[TaskDetails] Collector position: ${_collectorPosition?.latitude}, ${_collectorPosition?.longitude}',
    );
    debugPrint('[TaskDetails] Map controller: ${_mapController != null}');

    if (_mapController == null) {
      debugPrint('[TaskDetails] ❌ Map controller is null');
      return;
    }

    if (_collectorPosition == null) {
      debugPrint('[TaskDetails] ❌ Collector position not available');
      return;
    }

    try {
      debugPrint('[TaskDetails] ✅ Animating to collector location');
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_collectorPosition!.latitude, _collectorPosition!.longitude),
          16,
        ),
      );
    } catch (e) {
      debugPrint('[TaskDetails] ❌ Error centering on collector: $e');
    }
  }

  // Fetch and display directions from collector to household
  Future<void> _fetchDirections() async {
    final lat = _taskData['latitude'] as double?;
    final lng = _taskData['longitude'] as double?;

    if (_collectorPosition == null) {
      debugPrint('📍 [DIRECTIONS] Cannot fetch - collector position is null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Getting your location... Please wait.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        // Try to get location again
        await _getCurrentLocation();
        // If still null after retry, show error
        if (_collectorPosition == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to get your location. Please check GPS settings.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    if (lat == null || lng == null) {
      debugPrint(
        '📍 [DIRECTIONS] Cannot fetch - destination coordinates missing',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Destination location not available.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Track when we last fetched and from where
    _lastRouteFetch = DateTime.now();
    _lastFetchedPosition = LatLng(
      _collectorPosition!.latitude,
      _collectorPosition!.longitude,
    );

    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      final origin =
          '${_collectorPosition!.latitude},${_collectorPosition!.longitude}';
      final destination = '$lat,$lng';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin&destination=$destination&mode=driving&key=$apiKey',
      );

      // ignore: avoid_print
      if (kDebugMode) print('[Directions] Fetching: $url');

      final response = await http.get(url);

      // ignore: avoid_print
      if (kDebugMode) {
        print('[Directions] Response status: ${response.statusCode}');
      }
      // ignore: avoid_print
      if (kDebugMode) print('[Directions] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polylinePoints = route['overview_polyline']['points'];
          final leg = route['legs'][0];

          // Decode polyline
          final coordinates = _decodePolyline(polylinePoints);

          if (mounted) {
            setState(() {
              _polylines = {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: coordinates,
                  color: const Color(0xFF10B981),
                  width: 5,
                  geodesic: true,
                ),
              };
              _routeDistance = leg['distance']['text'];
              _routeDuration = leg['duration']['text'];

              debugPrint(
                '🗺️ [DIRECTIONS] Set _routeDistance=$_routeDistance, _routeDuration=$_routeDuration',
              );
            });

            // Update activeCollections with Directions API data
            final distanceMeters = leg['distance']['value'] as int?;
            if (distanceMeters != null) {
              final distanceKm = distanceMeters / 1000.0;
              // Only updates an existing tracking row (created by
              // LocationTrackingService.startTracking); errors are non-fatal.
              supabase
                  .from('active_collections')
                  .update({
                    'distance_remaining': distanceKm,
                    'last_updated': DateTime.now().toUtc().toIso8601String(),
                  })
                  .eq('posting_id', widget.taskId)
                  .then<void>((_) {}, onError: (_) {});

              debugPrint(
                '🗺️ [DIRECTIONS API] Updated activeCollections: ${distanceKm.toStringAsFixed(1)} km',
              );
            }

            // Fit map to show the route
            _fitBothMarkers();
          }
        } else {
          // More detailed error message
          final errorMessage = data['error_message'] ?? 'Unknown error';
          throw Exception('API Error: ${data['status']} - $errorMessage');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      // ignore: avoid_print
      if (kDebugMode) print('[Directions] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e\n\nPlease enable Directions API in Google Cloud Console',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Decode Google polyline format
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  // Build top status bar
  Widget _buildTopStatusBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 38, 16, 12),
      child: Card(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: AppColors.primaryGreen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
          child: _buildFullWidthStatusTimeline(context),
        ),
      ),
    );
  }

  // Build full-width status timeline with integrated back button
  Widget _buildFullWidthStatusTimeline(BuildContext context) {
    final statuses = [
      {'id': 'assigned', 'label': 'Assigned', 'icon': Icons.assignment},
      {'id': 'in_transit', 'label': 'In Transit', 'icon': Icons.local_shipping},
      {'id': 'arrived', 'label': 'Arrived', 'icon': Icons.location_on},
      {'id': 'collecting', 'label': 'Collecting', 'icon': Icons.recycling},
      {'id': 'completed', 'label': 'Completed', 'icon': Icons.check_circle},
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final shouldLeave = await _confirmExit();
                  if (shouldLeave) _navigateBackToTasks();
                },
              ),
              const SizedBox(width: 0),
              Expanded(
                child: Text(
                  'Task Status',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(_currentStatus),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Status Timeline
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: statuses.asMap().entries.map((entry) {
            final index = entry.key;
            final status = entry.value;
            final isCompleted = _isStatusCompleted(status['id'] as String);
            final isCurrent = _currentStatus == status['id'];

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _handleStatusTap(status['id'] as String),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      status['icon'] as IconData,
                      color: isCompleted || isCurrent
                          ? AppColors.primaryGreen
                          : Colors.white.withValues(alpha: 0.6),
                      size: 13,
                    ),
                  ),
                ),
                if (index < statuses.length - 1)
                  Container(
                    width: 32,
                    height: 2,
                    color: isCompleted
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  bool _isStatusCompleted(String status) {
    final statusOrder = [
      'assigned',
      'in_transit',
      'arrived',
      'collecting',
      'completed',
    ];
    final currentIndex = statusOrder.indexOf(_currentStatus);
    final statusIndex = statusOrder.indexOf(status);
    return statusIndex < currentIndex;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_transit':
        return 'In Transit';
      case 'arrived':
        return 'Arrived';
      case 'collecting':
        return 'Collecting';
      case 'completed':
        return 'Completed';
      case 'assigned':
      default:
        return 'Assigned';
    }
  }

  // Build draggable bottom sheet
  Widget _buildDraggableDetailsSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.15, // Start minimized - only buttons visible
      minChildSize: 0.15,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.15, 0.35, 0.65, 0.92],
      snapAnimationDuration: const Duration(milliseconds: 200),
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Action Bar
                      StatusActionBar(
                        status: _currentStatus,
                        onUpdateStatus: _handleStatusUpdate,
                        onGoBack: (prev) async {
                          final confirm = await _confirmStatusRevert(prev);
                          if (confirm == true) {
                            await _requestStatusUpdate(prev);
                          }
                        },
                      ),

                      // Assigned task briefing header
                      if (_currentStatus == 'assigned') ...[
                        const SizedBox(height: 16),
                        _buildAssignedHeader(),
                      ],

                      // Collecting mode header
                      if (_currentStatus == 'collecting') ...[
                        const SizedBox(height: 16),
                        _buildCollectingHeader(),
                      ],

                      const SizedBox(height: 20),

                      // Customer Information
                      CustomerInfoCard(
                        name: (_taskData['customerName'] ?? '').toString(),
                        phone: (_taskData['customerPhone'] ?? '').toString(),
                        address:
                            (_taskData['address'] ?? 'Address not available')
                                .toString(),
                        scheduledTime: '',
                        specialInstructions:
                            (_taskData['specialInstructions'] ?? '').toString(),
                        onCallPressed: _makePhoneCall,
                        onMessagePressed: _openChat,
                      ),

                      const SizedBox(height: 20),

                      // Posting Details Section (hidden during collecting status)
                      if (_currentStatus != 'collecting') ...[
                        _buildPostingDetailsCard(),
                        const SizedBox(height: 20),
                      ],

                      // Posting Images (if any)
                      if (_taskData['postingImages'] is List &&
                          (_taskData['postingImages'] as List).isNotEmpty) ...[
                        _buildPostingImagesSection(),
                        const SizedBox(height: 20),
                      ],

                      // Waste Items
                      if (_currentStatus == 'collecting') ...[
                        EditableWasteItemsList(
                          items: _getItemsList(),
                          originalItems: _getOriginalItemsList(),
                          junkshopId:
                              _taskData['assignedJunkshopId'] as String?,
                          onChanged: _onItemsVerified,
                          onPayPressed: () => _openCameraFor('payment'),
                          distance: _taskData['distance'] as double?,
                          baseFee: _taskData['baseFee'] as double?,
                          distanceFee: _taskData['distanceFee'] as double?,
                        ),
                        // Collection Fee breakdown below items
                        Builder(
                          builder: (context) {
                            final fee =
                                (_taskData['collectionFee'] as num?)
                                    ?.toDouble() ??
                                0.0;
                            final total =
                                (_taskData['estimatedEarnings'] as num?)
                                    ?.toDouble() ??
                                0.0;
                            if (fee <= 0) return const SizedBox.shrink();
                            final hhPay = (total - fee).clamp(
                              0.0,
                              double.infinity,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total collected value',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        Text(
                                          '₱${_fmtAmt(total)}',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Collection Fee',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        Text(
                                          '− ₱${_fmtAmt(fee)}',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: const Color(0xFFEF4444),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Divider(
                                      height: 1,
                                      color: AppColors.borderLight,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Household payment',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                        ),
                                        Text(
                                          '₱${_fmtAmt(hhPay)}',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryGreen,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _openCameraFor('payment'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.collectorPrimary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        icon: const Icon(
                                          Icons.receipt_long,
                                          size: 20,
                                        ),
                                        label: const Text(
                                          'Pay & Add Receipt',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Pay button (shown when no Collection Fee)
                        Builder(
                          builder: (context) {
                            final fee =
                                (_taskData['collectionFee'] as num?)
                                    ?.toDouble() ??
                                0.0;
                            if (fee > 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _openCameraFor('payment'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.collectorPrimary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(
                                    Icons.receipt_long,
                                    size: 22,
                                  ),
                                  label: const Text(
                                    'Pay & Add Receipt',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ] else
                        WasteItemsList(
                          items: _getItemsList(),
                          totalEarnings:
                              (_taskData['estimatedEarnings'] ?? 0.0) as double,
                        ),

                      const SizedBox(height: 20),

                      // Photo Verification Section (shown based on status)
                      if (_shouldShowPhotoSection()) ...[
                        PhotoVerificationSection(
                          status: _currentStatus,
                          photos: (_taskData['photos'] as Map<String, dynamic>)
                              .map(
                                (key, value) => MapEntry(key, value as List),
                              ),
                          onPhotosUpdated: _updatePhotos,
                        ),

                        const SizedBox(height: 20),
                      ],

                      // Cancel + Reschedule action row (assigned, in_transit, arrived only)
                      if (_currentStatus == 'assigned' ||
                          _currentStatus == 'in_transit' ||
                          _currentStatus == 'arrived') ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSecondaryActionButton(
                                icon: Icons.cancel_outlined,
                                label: 'Cancel Pickup',
                                color: const Color(0xFFEF4444),
                                bgColor: const Color(0xFFFEF2F2),
                                onPressed: _cancelPickup,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSecondaryActionButton(
                                icon: Icons.schedule_rounded,
                                label: 'Reschedule',
                                color: const Color(0xFFF59E0B),
                                bgColor: const Color(0xFFFFFBEB),
                                onPressed: _requestReschedule,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _shouldShowPhotoSection() {
    return ['arrived', 'collecting', 'completed'].contains(_currentStatus);
  }

  List<Map<String, dynamic>> _getItemsList() {
    final items = _taskData['verifiedItems'] ?? _taskData['wasteItems'];
    if (items == null) return [];
    if (items is List) {
      return items.whereType<Map>().map((item) {
        final m = Map<String, dynamic>.from(item);
        // Firestore stores verified items with 'name' and 'totalPrice' keys.
        // WasteItemsList expects 'type' and 'price' — normalize here.
        if (!m.containsKey('type') || m['type'] == null) {
          m['type'] = m['name'];
        }
        if (!m.containsKey('price') || m['price'] == null) {
          m['price'] = m['totalPrice'] ?? m['estimatedValue'];
        }
        return m;
      }).toList();
    }
    return [];
  }

  List<Map<String, dynamic>>? _getOriginalItemsList() {
    // Try to get items from the nested 'items' structure (same as posting data)
    final itemsData = _taskData['items'];
    debugPrint('[TaskDetails] items field from _taskData: $itemsData');

    List<dynamic> items = [];

    if (itemsData is Map) {
      // New nested structure: items.list
      items = (itemsData['list'] ?? []) as List<dynamic>;
      debugPrint(
        '[TaskDetails] Found nested items.list: ${items.length} items',
      );
    } else if (itemsData is List) {
      // Legacy flat structure
      items = itemsData;
      debugPrint('[TaskDetails] Found flat items array: ${items.length} items');
    } else {
      // Fallback to wasteItems if items field doesn't exist
      final wasteItems = _taskData['wasteItems'];
      if (wasteItems is List) {
        items = wasteItems;
        debugPrint(
          '[TaskDetails] Fallback to wasteItems: ${items.length} items',
        );
      }
    }

    if (items.isEmpty) {
      debugPrint('[TaskDetails] ⚠️ No items found in any location');
      return null;
    }

    final result = items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    debugPrint('[TaskDetails] ✅ Original items count: ${result.length}');
    return result;
  }

  Widget _buildAssignedHeader() {
    final earnings =
        (_taskData['estimatedEarnings'] as num?)?.toDouble() ?? 0.0;
    final weight = (_taskData['estimatedWeight'] as num?)?.toDouble() ?? 0.0;
    final itemCount = (_taskData['wasteItems'] as List?)?.length ?? 0;
    final date = _taskData['dateOfCollection'] as DateTime?;

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
    final dateLabel = date != null
        ? '${months[date.month - 1]} ${date.day}, ${date.year}'
        : 'Today';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.collectorPrimary,
            AppColors.collectorPrimary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collection Task',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Assigned to You',
                      style: AppTextStyles.h5.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dateLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (earnings > 0 || weight > 0 || itemCount > 0) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (earnings > 0)
                  _buildHeaderStat(
                    '₱${_fmtAmt(earnings, decimals: 0)}',
                    'Est. Earnings',
                    Icons.payments_outlined,
                  ),
                if (weight > 0)
                  _buildHeaderStat(
                    '${weight.toStringAsFixed(1)} kg',
                    'Est. Weight',
                    Icons.scale_outlined,
                  ),
                if (itemCount > 0)
                  _buildHeaderStat(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    'Materials',
                    Icons.inventory_2_outlined,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCollectingHeader() {
    final itemCount = (_taskData['wasteItems'] as List?)?.length ?? 0;
    final verifiedItems = _taskData['verifiedItems'];
    final verifiedCount = verifiedItems is List
        ? verifiedItems.length
        : itemCount;
    final earnings =
        (_taskData['estimatedEarnings'] as num?)?.toDouble() ?? 0.0;
    final collectionFee =
        (_taskData['collectionFee'] as num?)?.toDouble() ?? 0.0;
    final householdPayment = (earnings - collectionFee).clamp(
      0.0,
      double.infinity,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryGreen, const Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.recycling_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currently Collecting',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Verify & Log Items',
                      style: AppTextStyles.h5.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (verifiedCount > 0 || earnings > 0) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderStat(
                  '$verifiedCount of $itemCount',
                  'Items Verified',
                  Icons.inventory_2_outlined,
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                _buildHeaderStat(
                  '₱${_fmtAmt(earnings, decimals: 0)}',
                  'Total Value',
                  Icons.payments_outlined,
                ),
                if (collectionFee > 0) ...[
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  _buildHeaderStat(
                    '₱${_fmtAmt(householdPayment, decimals: 0)}',
                    'Household Gets',
                    Icons.home_outlined,
                  ),
                ] else ...[
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  _buildHeaderStat(
                    '3 steps',
                    'Photo Proof',
                    Icons.camera_alt_outlined,
                  ),
                ],
              ],
            ),
            // Collection Fee breakdown
            if (collectionFee > 0) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total collected value',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          '₱${_fmtAmt(earnings)}',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Collection Fee',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          '− ₱${_fmtAmt(collectionFee)}',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.orange.shade200,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Household payment',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '₱${_fmtAmt(householdPayment)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSecondaryActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostingDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primaryGreen,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Posting Details',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Collection Date highlight
          if (_taskData['dateOfCollection'] != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.event_available_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SCHEDULED COLLECTION',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(_taskData['dateOfCollection']),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 12),
          ],

          // Rows section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Assigned On
                if (_taskData['createdAt'] != null) ...[
                  _buildModernDetailRow(
                    icon: Icons.assignment_ind_outlined,
                    label: 'Assigned On',
                    value: _formatFullDateTime(_taskData['createdAt']),
                  ),
                  Divider(height: 20, color: AppColors.borderLight),
                ],

                // Collection Fee
                if ((_taskData['collectionFee'] as num?)?.toDouble() != null &&
                    ((_taskData['collectionFee'] as num?)?.toDouble() ?? 0.0) >
                        0) ...[
                  _buildModernDetailRow(
                    icon: Icons.local_shipping_outlined,
                    label: 'Collection Fee',
                    value:
                        '₱${_fmtAmt((_taskData['collectionFee'] as num).toDouble())}',
                  ),
                  Divider(height: 20, color: AppColors.borderLight),
                ],

                // Estimated Weight
                if (_taskData['estimatedWeight'] != null &&
                    (_taskData['estimatedWeight'] as num) > 0) ...[
                  _buildModernDetailRow(
                    icon: Icons.scale_outlined,
                    label: 'Estimated Weight',
                    value:
                        '${(_taskData['estimatedWeight'] as num).toStringAsFixed(2)} kg',
                  ),
                  if (_taskData['notes'] != null &&
                      _taskData['notes'].toString().isNotEmpty)
                    Divider(height: 20, color: AppColors.borderLight),
                ],

                // Notes
                if (_taskData['notes'] != null &&
                    _taskData['notes'].toString().isNotEmpty)
                  _buildModernDetailRow(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Notes',
                    value: _taskData['notes'].toString(),
                    isMultiline: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostingImagesSection() {
    final images = _taskData['postingImages'] as List<String>;
    // Remove duplicates by converting to Set and back to List
    final uniqueImages = images.toSet().toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.image,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Posted Images',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: uniqueImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    image: DecorationImage(
                      image: AppImageProvider(uniqueImages[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
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
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  String _formatFullDateTime(DateTime? date) {
    if (date == null) return '';
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
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}, $hour:$minute $period';
  }

  void _handleStatusTap(String status) {
    _requestStatusUpdate(status);
  }

  bool _canUpdateToStatus(String status) {
    final statusOrder = [
      'assigned',
      'in_transit',
      'arrived',
      'collecting',
      'completed',
    ];
    final currentIndex = statusOrder.indexOf(_currentStatus);
    final targetIndex = statusOrder.indexOf(status);

    // Allow moving forward or one step backward
    if (targetIndex == currentIndex) return true;
    if (targetIndex == currentIndex - 1) return true; // one-step back
    return targetIndex > currentIndex; // forward
  }

  void _onItemsVerified(List<Map<String, dynamic>> items) async {
    // Calculate total before setState
    final total = items.fold<double>(
      0.0,
      (acc, it) => acc + (it['price'] ?? 0).toDouble(),
    );

    final collectionFee =
        (_taskData['collectionFee'] as num?)?.toDouble() ?? 0.0;
    final householdPayment = (total - collectionFee).clamp(
      0.0,
      double.infinity,
    );

    setState(() {
      _taskData['wasteItems'] = items;
      _taskData['estimatedEarnings'] = total;
      _taskData['householdPayment'] = householdPayment;
    });

    // Save verified items to separate field in Firestore
    final messenger = ScaffoldMessenger.of(context);
    if (_taskDocRef != null) {
      try {
        final user = supabase.auth.currentUser;

        // Transform items to have consistent field names for junkshop
        final transformedItems = items.map((item) {
          return {
            'name': item['type'] ?? item['name'] ?? 'Item',
            'category': item['category'],
            'quantity': item['quantity'] ?? 1, // Keep as number
            'unit': item['unit'] ?? 'kg',
            'condition': item['condition'] ?? 'good',
            'pricePerUnit': item['pricePerUnit'] ?? 0.0,
            'totalPrice': item['price'] ?? item['totalPrice'] ?? 0.0,
            'imagePaths': item['imagePaths'] ?? [],
            if (item['promotionBoostPercentage'] != null)
              'promotionBoostPercentage': item['promotionBoostPercentage'],
            if (item['promotionId'] != null) 'promotionId': item['promotionId'],
          };
        }).toList();

        await _taskDocRef!.update({
          PostingFields.verifiedItems: {
            'items': transformedItems,
            'totalValue': total,
            'verifiedAt': _serverTs(),
            'verifiedBy': user?.id ?? '',
          },
          'householdPaymentAmount': householdPayment,
          'updatedAt': _serverTs(),
        });
        debugPrint('✅ TaskDetails: Verified items saved to Firestore');
      } catch (e) {
        debugPrint('❌ TaskDetails: Failed to save verified items: $e');
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to save verified items: $e')),
        );
      }
    }
  }

  /// Ensures verifiedItems field exists in Firestore
  /// If collector didn't modify items, copy original items as verified
  Future<void> _ensureVerifiedItemsExist() async {
    if (_taskDocRef == null) return;

    try {
      // Check if verifiedItems already exists in local state
      final verifiedItems = _taskData['verifiedItems'];

      // Handle both Map structure (from Firestore) and List structure (local)
      bool hasVerifiedItems = false;
      if (verifiedItems is Map<String, dynamic>) {
        final items = verifiedItems['items'];
        hasVerifiedItems = items is List && items.isNotEmpty;
      } else if (verifiedItems is List) {
        hasVerifiedItems = verifiedItems.isNotEmpty;
      }

      if (hasVerifiedItems) {
        debugPrint('✅ TaskDetails: verifiedItems already exists, skipping');
        return;
      }

      // Get items from wasteItems (original posting items)
      final items = List<Map<String, dynamic>>.from(
        _taskData['wasteItems'] ?? const [],
      );

      if (items.isEmpty) {
        debugPrint('⚠️ TaskDetails: No items to verify');
        return;
      }

      // Calculate total
      final total = items.fold<double>(
        0.0,
        (acc, it) => acc + (it['price'] ?? 0).toDouble(),
      );

      // Transform items to have consistent field names for junkshop
      final transformedItems = items.map((item) {
        return {
          'name': item['type'] ?? item['name'] ?? 'Item',
          'category': item['category'],
          'quantity': item['quantity'] ?? 1, // Keep as number
          'unit': item['unit'] ?? 'kg',
          'condition': item['condition'] ?? 'good',
          'pricePerUnit': item['pricePerUnit'] ?? 0.0,
          'totalPrice': item['price'] ?? item['totalPrice'] ?? 0.0,
          'imagePaths': item['imagePaths'] ?? [],
          if (item['promotionBoostPercentage'] != null)
            'promotionBoostPercentage': item['promotionBoostPercentage'],
          if (item['promotionId'] != null) 'promotionId': item['promotionId'],
        };
      }).toList();

      // Update local state
      setState(() {
        _taskData['verifiedItems'] = items;
        _taskData['estimatedEarnings'] = total;
      });

      // Save to Firestore with nested structure
      final user = supabase.auth.currentUser;
      await _taskDocRef!.update({
        PostingFields.verifiedItems: {
          'items': transformedItems,
          'totalValue': total,
          'verifiedAt': _serverTs(),
          'verifiedBy': user?.id ?? '',
        },
        'updatedAt': _serverTs(),
      });

      debugPrint(
        '✅ TaskDetails: Auto-created verifiedItems from original items (${items.length} items, total: ₱$total)',
      );
    } catch (e) {
      debugPrint('❌ TaskDetails: Failed to ensure verifiedItems exist: $e');
    }
  }

  /// Routes status updates — shows On The Way sheet for in_transit, else updates directly.
  void _handleStatusUpdate(String newStatus) {
    if (newStatus == 'in_transit') {
      _showOnTheWaySheet();
    } else {
      _requestStatusUpdate(newStatus);
    }
  }

  /// Shows a modern confirmation sheet before marking the collector as in_transit.
  void _showOnTheWaySheet() {
    final fullAddr = (_taskData['fullAddress']?.toString() ?? '');
    final shortAddr = (_taskData['address']?.toString() ?? '');
    final address = fullAddr.isNotEmpty ? fullAddr : shortAddr;
    final scheduledTime = (_taskData['scheduledTime'] ?? '').toString();
    final dateOfCollection = _taskData['dateOfCollection'] as DateTime?;
    final estimatedEarnings =
        (_taskData['estimatedEarnings'] as num?)?.toDouble() ?? 0.0;
    final itemCount = (_taskData['wasteItems'] as List?)?.length ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _OnTheWaySheet(
        address: address.isEmpty ? 'Address not available' : address,
        scheduledTime: scheduledTime,
        dateOfCollection: dateOfCollection,
        estimatedEarnings: estimatedEarnings,
        itemCount: itemCount,
        onConfirm: () {
          Navigator.of(ctx).pop();
          _requestStatusUpdate('in_transit');
        },
      ),
    );
  }

  Future<void> _requestStatusUpdate(String newStatus) async {
    if (!_canUpdateToStatus(newStatus)) return;

    final error = _validateTransition(_currentStatus, newStatus);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Check if trying to start collection (in_transit, arrived, collecting, completed)
    // Only allow if it's the assigned date
    if (newStatus == 'in_transit' ||
        newStatus == 'arrived' ||
        newStatus == 'collecting' ||
        newStatus == 'completed') {
      final dateOfCollection = _taskData['dateOfCollection'] as DateTime?;
      if (dateOfCollection != null) {
        final now = DateTime.now();
        final collectionDate = DateTime(
          dateOfCollection.year,
          dateOfCollection.month,
          dateOfCollection.day,
        );
        final today = DateTime(now.year, now.month, now.day);

        if (!collectionDate.isAtSameMomentAs(today)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Collection can only be done on ${_formatDate(dateOfCollection)}. '
                'Please wait until the scheduled date.',
              ),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      }
    }

    // Update UI immediately, then start tracking in background
    final previousStatus = _currentStatus;
    setState(() => _currentStatus = newStatus);
    await _updateStatusOnServer(newStatus);

    // Start real-time tracking when going in_transit (async, non-blocking)
    if (previousStatus == 'assigned' && newStatus == 'in_transit') {
      final lat = _taskData['latitude'] as double?;
      final lng = _taskData['longitude'] as double?;
      final address =
          _taskData['fullAddress']?.toString() ??
          _taskData['address']?.toString() ??
          '';
      final user = supabase.auth.currentUser;

      if (lat != null && lng != null && user != null) {
        // Start tracking in background without blocking UI
        _startTrackingInBackground(user.id, lat, lng, address);
      }
    }

    // Update tracking status when arrived
    if (newStatus == 'arrived') {
      try {
        await _trackingService.updateStatus('arrived');
      } catch (e) {
        debugPrint('❌ Failed to update tracking status: $e');
      }
    }

    // Update tracking status when collecting
    if (newStatus == 'collecting') {
      try {
        await _trackingService.updateStatus('collecting');
      } catch (e) {
        debugPrint('❌ Failed to update tracking status: $e');
      }
    }

    // Special behavior: camera triggers at key transitions
    if (previousStatus == 'in_transit' && newStatus == 'arrived') {
      _openCameraFor('arrival');
    }
    if (previousStatus == 'arrived' && newStatus == 'collecting') {
      // Open camera for collection proof when starting collection
      _openCameraFor('collection');
    }
    // No popup dialog after status updates per request
    if (newStatus == 'completed') {
      // Upload all local photos to Firebase Storage before completing
      await _uploadAllLocalPhotos();
      // Stop real-time tracking
      try {
        await _trackingService.stopTracking();
        debugPrint('✅ Tracking stopped');
      } catch (e) {
        debugPrint('❌ Failed to stop tracking: $e');
      }
      _navigateBackToTasks();
    }
  }

  void _startTrackingInBackground(
    String collectorId,
    double lat,
    double lng,
    String address,
  ) async {
    try {
      // Get collector name and photo from user data
      final userDoc = await supabase
          .from('collectors')
          .select('full_name, profile_image_url')
          .eq('id', collectorId)
          .maybeSingle();
      final collectorName = userDoc?['full_name']?.toString() ?? 'Collector';
      final collectorPhoto = userDoc?['profile_image_url']?.toString() ?? '';
      // active_collections.household_id is required (NOT NULL): resolve it
      // from the posting when the screen was opened without a household id.
      String householdId = widget.householdId ?? '';
      if (householdId.isEmpty) {
        final posting = await _taskDocRef?.get();
        householdId = posting?['householdId']?.toString() ?? '';
      }

      await _trackingService.startTracking(
        postingId: widget.taskId,
        collectorId: collectorId,
        collectorName: collectorName,
        collectorPhoto: collectorPhoto,
        householdId: householdId,
        destinationLat: lat,
        destinationLng: lng,
        destinationAddress: address,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live tracking started'),
            backgroundColor: AppColors.primaryGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to start tracking: $e');
    }
  }

  // Upload all local photos to Firebase Storage and update Firestore with URLs
  Future<void> _uploadAllLocalPhotos() async {
    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.collectorPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.collectorPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Uploading Photos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final categories = ['arrival', 'collection', 'payment'];

      // Upload all photos in parallel for each category
      for (final category in categories) {
        final photos = List<String>.from(_taskData['photos'][category] ?? []);

        // Separate already uploaded URLs from local files
        final alreadyUploaded = photos
            .where((p) => p.startsWith('http'))
            .toList();
        final localFiles = photos.where((p) => !p.startsWith('http')).toList();

        if (localFiles.isEmpty) {
          // No local files to upload
          continue;
        }

        // Upload all local files in parallel
        final uploadFutures = localFiles.map((photoPath) async {
          final xFile = XFile(photoPath);
          return await _uploadSinglePhoto(category, xFile);
        }).toList();

        final uploadedUrls = await Future.wait(uploadFutures);

        // Combine already uploaded URLs with newly uploaded URLs
        final allUrls = [...alreadyUploaded, ...uploadedUrls];

        // Update Firestore with all URLs
        if (allUrls.isNotEmpty) {
          await _updatePhotos(category, allUrls);
        }
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All photos uploaded successfully!'),
            backgroundColor: AppColors.primaryGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photos: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      rethrow;
    }
  }

  // Camera launcher: capture photo locally, only upload when task is completed
  void _openCameraFor(String category) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      XFile? image;
      try {
        image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );
      } catch (_) {
        // Fallback for platforms without camera support (e.g., desktop during dev)
        image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
      }
      if (image == null) {
        // User canceled
        messenger.showSnackBar(
          const SnackBar(content: Text('No photo captured')),
        );
        return;
      }

      // Store local file path instead of uploading immediately
      final localPath = image.path;
      final updated = List<String>.from(_taskData['photos'][category] ?? []);
      updated.add(localPath);
      setState(() {
        _taskData['photos'][category] = updated;
      });

      // Show success message
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${category.toUpperCase()} photo saved locally. Will upload when you complete the task.',
            ),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (category == 'payment') {
        // When payment photo is taken, ensure verifiedItems exists
        // If collector didn't add/modify items, copy original items to verifiedItems
        await _ensureVerifiedItemsExist();

        // After capturing receipt, scroll to top to press Complete
        _scrollToTop();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to open camera: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  String? _validateTransition(String from, String to) {
    // Photos (arrival, collection, payment) are optional — collectors can skip them.
    // Only hard requirement: at least one verified item before completing.
    if (from == 'in_transit' && to == 'arrived') {
      // no gating to mark Arrived; photos will be required before moving to Collecting
      return null;
    }
    if (from == 'arrived' && to == 'collecting') {
      return null;
    }
    if (from == 'collecting' && to == 'completed') {
      final items = List<Map<String, dynamic>>.from(
        _taskData['wasteItems'] ?? const [],
      );
      if (items.isEmpty) {
        return 'Verify at least one collected item before completing.';
      }
      return null;
    }
    return null;
  }

  Future<void> _updateStatusOnServer(String status) async {
    if (_taskDocRef == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      debugPrint('📝 TaskDetails: Updating status to "$status"');
      debugPrint('📝 TaskDetails: Document path: ${_taskDocRef!.path}');

      await _taskDocRef!.update({
        'status': status,
        'updatedAt': _serverTs(),
      });

      debugPrint('✅ TaskDetails: Status updated successfully to "$status"');

      // Send automatic message to conversation
      await _sendStatusUpdateMessage(status);
    } catch (e) {
      debugPrint('❌ TaskDetails: Failed to update status: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _sendStatusUpdateMessage(String status) async {
    // Note: Status update messages are now automatically sent by ConversationSyncService
    // This method is kept for backward compatibility and conversation ID updates only
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get conversation ID from posting document, or find it by postingId
      final postingDoc = await _taskDocRef!.get();
      String? conversationId = postingDoc?['conversationId'] as String?;

      // If conversationId not found in posting, try to find the conversation by posting ID
      if (conversationId == null) {
        final postingId = _taskData['postingId'] ?? _taskData['id'];
        conversationId = 'posting_$postingId';

        // Verify the conversation exists
        final conversationDoc = await supabase
            .from('conversations')
            .select('id')
            .eq('id', conversationId)
            .maybeSingle();

        if (conversationDoc == null) {
          debugPrint('⚠️ Conversation not found for posting: $postingId');
          return;
        }

        // Store conversationId in posting for future use
        await _taskDocRef!.update({'conversationId': conversationId});
        debugPrint('✅ Updated posting with conversationId: $conversationId');
      }

      debugPrint(
        '✅ ConversationSyncService will handle status update message for conversation $conversationId',
      );
    } catch (e) {
      debugPrint('❌ Failed to update conversation ID: $e');
      // Don't throw - this is a non-critical feature
    }
  }

  Future<void> _cancelPickup() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CancelPickupDialog(),
    );

    if (result == null) return; // User dismissed dialog

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cancelling collection...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final selectedReasons = result['selectedReasons'] as List<String>;
      final detail = result['detail'] as String;
      final proofPhoto = result['proofPhoto'] as File?;

      // Upload proof photo if provided
      String? proofPhotoUrl;
      if (proofPhoto != null) {
        final user = supabase.auth.currentUser;
        if (user != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          proofPhotoUrl = await uploadPublicFile(
            bucket: 'user-uploads',
            path:
                '${user.id}/postings/${widget.taskId}/cancellation_proof/${timestamp}_proof.jpg',
            file: proofPhoto,
          );
          debugPrint('✅ Uploaded cancellation proof photo: $proofPhotoUrl');
        }
      }

      // Update Firestore with cancellation data - nested under 'cancellation' field
      if (_taskDocRef != null) {
        final user = supabase.auth.currentUser;
        await _taskDocRef!.update({
          PostingFields.status: 'cancelled',
          'cancellation': {
            'selectedReasons': selectedReasons,
            'cancellationReason': selectedReasons.join(', '),
            'cancellationDetail': detail,
            'cancelledAt': _serverTs(),
            'cancelledBy': user?.id ?? '',
            'cancelledByRole': 'collector',
            if (proofPhotoUrl != null) 'cancellationProofPhoto': proofPhotoUrl,
          },
          'updatedAt': _serverTs(),
        });

        debugPrint('✅ Pickup cancelled successfully');

        // Send system message about cancellation with reasons
        await _sendCancellationMessage(selectedReasons, detail, proofPhotoUrl);

        // Stop tracking service if active
        await _trackingService.stopTracking();
        debugPrint('✅ Location tracking stopped after cancellation');

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
        }

        if (mounted) {
          // Navigate back and trigger refresh
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to cancel pickup: $e');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel pickup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _requestReschedule() async {
    // Show reschedule dialog with reasons
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const ReschedulePickupDialog(),
    );

    if (result == null) return; // User dismissed dialog

    try {
      final selectedReasons = result['selectedReasons'] as List<String>;
      final detail = result['detail'] as String;

      if (_taskDocRef != null) {
        final user = supabase.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        // Get current collector's full name from collectors collection
        final collectorData = await supabase
            .from('collectors')
            .select('full_name, profile_image_url')
            .eq('id', user.id)
            .maybeSingle();

        // Use full_name to get the complete name, but validate it's not just initials
        String? fullName = collectorData?['full_name']?.toString().trim();
        String? name = (user.userMetadata?['full_name'] ??
                user.userMetadata?['name'])
            ?.toString()
            .trim();

        // Check if fullName or name is too short (likely just initials like "8c")
        // A valid full name should be at least 3 characters
        if (fullName != null && fullName.length < 3) {
          fullName = null; // Discard if it's just initials
        }
        if (name != null && name.length < 3) {
          name = null; // Discard if it's just initials
        }

        String collectorName =
            fullName ??
            name ??
            user.email?.split('@')[0] ??
            'Collector ${user.id.substring(0, 6)}';

        final collectorPhoto = collectorData?['profile_image_url']?.toString();

        if (kDebugMode) {
          print('DEBUG Reschedule - Collector: ${user.id} / $collectorName');
        }

        // Update status to reschedule and store collector info nested inside reschedule object
        await _taskDocRef!.update({
          PostingFields.status: 'reschedule',
          // NOTE: the real `collector_id` column is intentionally kept: RLS
          // only lets the collector update the row while collector_id = uid.
          // The junkshop replaces it when reassigning.
          'collector': null,
          'assignedCollectorName': null,
          'assignedCollectorPhoto': null,
          'dateOfCollection': null,
          'previousCollectorId': null,
          'previousCollectorName': null,
          'previousCollectorPhoto': null,
          'reschedule': {
            'rescheduledAt': _serverTs(),
            'rescheduledById': user.id,
            'rescheduledByName': collectorName,
            'rescheduledByPhoto': collectorPhoto,
            'rescheduledByRole': 'collector',
            'rescheduleReasons': selectedReasons,
            'rescheduleDetail': detail,
          },
          'updatedAt': _serverTs(),
        });

        // Send system message about rescheduling with reasons
        await _sendRescheduleMessage(selectedReasons, detail);

        debugPrint('✅ Reschedule requested successfully');

        if (mounted) {
          // Navigate back and trigger refresh
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to request reschedule: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request reschedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendRescheduleMessage(
    List<String> selectedReasons,
    String detail,
  ) async {
    try {
      // Get conversation ID
      final postingDoc = await _taskDocRef!.get();
      String? conversationId = postingDoc?['conversationId'] as String?;

      if (conversationId == null) {
        final postingId = _taskData['postingId'] ?? _taskData['id'];
        conversationId = 'posting_$postingId';
      }

      // Map reason keys to readable labels
      final Map<String, String> reasonLabels = {
        'bad_weather': 'Bad weather conditions',
        'traffic_delay': 'Severe traffic delay',
        'vehicle_issue': 'Vehicle maintenance needed',
        'time_conflict': 'Schedule conflict',
        'personal_emergency': 'Personal emergency',
        'route_optimization': 'Better route planning needed',
        'late_running': 'Running late from previous collection',
        'equipment_needed': 'Need special equipment',
        'other': 'Other reason',
      };

      // Format reasons for display
      final reasonsText = selectedReasons
          .map((key) => reasonLabels[key] ?? key)
          .join(', ');

      String messageText =
          '🔄 Collector has requested to reschedule this collection.\n'
          '📋 Reason: $reasonsText';

      if (detail.isNotEmpty) {
        messageText += '\n💬 Details: $detail';
      }

      messageText +=
          '\n\n📅 The junkshop will review and find a suitable schedule for this collection.';

      // Send system message (also updates the conversation's last message)
      await ChatRepository().sendSystemMessage(
        conversationId: conversationId,
        text: messageText,
        action: 'reschedule_requested',
        additionalMetadata: {
                'rescheduleReasons': selectedReasons,
                'rescheduleDetail': detail,
              },
      );

      debugPrint('✅ Reschedule message sent to conversation $conversationId');
    } catch (e) {
      debugPrint('❌ Failed to send reschedule message: $e');
    }
  }

  Future<void> _sendCancellationMessage(
    List<String> selectedReasons,
    String detail,
    String? proofPhotoUrl,
  ) async {
    try {
      // Get conversation ID
      final postingDoc = await _taskDocRef!.get();
      String? conversationId = postingDoc?['conversationId'] as String?;

      if (conversationId == null) {
        final postingId = _taskData['postingId'] ?? _taskData['id'];
        conversationId = 'posting_$postingId';
      }

      // Map reason keys to readable labels
      final Map<String, String> reasonLabels = {
        'household_not_home': 'Household not home',
        'items_mismatch': 'Items do not match posting',
        'items_not_recyclable': 'Items not recyclable',
        'incorrect_address': 'Incorrect address',
        'unsafe_location': 'Unsafe location/area',
        'items_already_collected': 'Already collected',
        'items_too_contaminated': 'Items too contaminated',
        'household_changed_mind': 'Household cancelled',
        'duplicate_posting': 'Duplicate posting',
        'other': 'Other reason',
      };

      // Format reasons for display
      final reasonsText = selectedReasons
          .map((key) => reasonLabels[key] ?? key)
          .join(', ');

      String messageText =
          '❌ Collector has cancelled this collection.\n'
          '📋 Reason: $reasonsText';

      if (detail.isNotEmpty) {
        messageText += '\n💬 Details: $detail';
      }

      if (proofPhotoUrl != null) {
        messageText += '\n📸 Proof photo attached';
      }

      messageText +=
          '\n\n🚫 This collection has been cancelled and cannot be completed.';

      // Send system message (also updates the conversation's last message)
      await ChatRepository().sendSystemMessage(
        conversationId: conversationId,
        text: messageText,
        action: 'collection_cancelled',
        additionalMetadata: {
                'cancellationReasons': selectedReasons,
                'cancellationDetail': detail,
                if (proofPhotoUrl != null)
                  'cancellationProofPhoto': proofPhotoUrl,
              },
      );

      debugPrint('✅ Cancellation message sent to conversation $conversationId');
    } catch (e) {
      debugPrint('❌ Failed to send cancellation message: $e');
    }
  }

  Future<void> _updatePhotos(String category, List<String> photos) async {
    setState(() {
      _taskData['photos'][category] = photos;
    });
    final messenger = ScaffoldMessenger.of(context);
    // Persist to Firestore
    if (_taskDocRef != null) {
      try {
        // Merge with the photos already stored (other categories)
        final current = await _taskDocRef!.get();
        final existing = Map<String, dynamic>.from(
          (current?['photos'] as Map?) ?? const {},
        );
        existing[category] = photos;
        await _taskDocRef!.set({
          'photos': existing,
          'updatedAt': _serverTs(),
        });
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to save $category photos: $e')),
        );
      }
    }
  }

  Future<String> _uploadSinglePhoto(String category, XFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = supabase.auth.currentUser;
      // ignore: avoid_print
      if (kDebugMode) {
        print(
          '[TaskDetails] Current user: ${user?.id ?? "NULL"}, email: ${user?.email ?? "NULL"}',
        );
      }
      if (user == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to upload photos.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        throw Exception('Not authenticated');
      }
      final uid = user.id;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Path namespaced by the authenticated user (storage RLS):
      // {uid}/postings/{taskId}/{category}/{timestamp_filename}
      final objectPath =
          '$uid/postings/${widget.taskId}/$category/${timestamp}_${file.name}';
      if (kDebugMode) print('[TaskDetails] Uploading to user-uploads/$objectPath');
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        return await uploadPublicFile(
          bucket: 'user-uploads',
          path: objectPath,
          bytes: bytes,
        );
      }
      // Compress image before uploading to reduce file size
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.path,
        '${file.path}_compressed.jpg',
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );
      final fileToUpload = compressedFile != null
          ? File(compressedFile.path)
          : File(file.path);
      return await uploadPublicFile(
        bucket: 'user-uploads',
        path: objectPath,
        file: fileToUpload,
      );
    } catch (e) {
      final msg = e.toString();
      // Provide clearer guidance for Storage 403 errors
      if (msg.contains('Permission denied') || msg.contains('403')) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Could not upload photo (permission denied). Please ensure this user may write under user-uploads/{uid}/...',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
      rethrow;
    }
  }

  void _makePhoneCall() async {
    final phoneNumber = (_taskData['customerPhone'] ?? '').toString();
    if (phoneNumber.isNotEmpty) {
      try {
        await PhoneLauncher.makePhoneCall(phoneNumber);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to make phone call: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _openChat() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening chat...'),
          duration: Duration(seconds: 1),
          backgroundColor: AppColors.collectorPrimary,
        ),
      );

      // Fetch the conversation for this posting
      final chatRepo = ChatRepository();
      final conversation = await chatRepo.getConversationByPostingId(
        _taskData['postingId'],
      );

      if (conversation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat not available for this posting'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Navigate to the chat detail screen with the conversation
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/collector/chat-detail',
          arguments: {'conversation': conversation},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<bool> _confirmExit() async {
    // Status changes are automatically saved to Firestore
    // Allow free navigation - collectors can leave and return anytime
    return true;
  }

  void _navigateBackToTasks() {
    if (Navigator.of(context).canPop()) {
      // Return true to indicate task was completed, so home screen can reload
      Navigator.of(context).pop(true);
    } else {
      // Fallback: stay defensive; route may differ
      // Navigator.of(context).pushReplacementNamed('/collector/tasks');
    }
  }

  Future<bool> _confirmStatusRevert(String prevStatus) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CustomConfirmDialog(
        icon: Icons.history,
        iconColor: AppColors.collectorPrimary,
        title: 'Revert Status?',
        message:
            'Do you want to go back to "$prevStatus"? This may affect task tracking.',
        cancelText: 'Cancel',
        confirmText: 'Yes, Revert',
        confirmColor: AppColors.collectorPrimary,
      ),
    );
    return result ?? false;
  }
}

class _CustomConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final Color confirmColor;

  const _CustomConfirmDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.cancelText,
    required this.confirmText,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: AppColors.borderLight,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      cancelText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// On The Way confirmation bottom sheet
// ---------------------------------------------------------------------------

class _OnTheWaySheet extends StatelessWidget {
  final String address;
  final String scheduledTime;
  final DateTime? dateOfCollection;
  final double estimatedEarnings;
  final int itemCount;
  final VoidCallback onConfirm;

  const _OnTheWaySheet({
    required this.address,
    required this.scheduledTime,
    required this.dateOfCollection,
    required this.estimatedEarnings,
    required this.itemCount,
    required this.onConfirm,
  });

  String _formatDate(DateTime dt) {
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = dateOfCollection != null
        ? _formatDate(dateOfCollection!)
        : scheduledTime.isNotEmpty
        ? scheduledTime
        : 'Today';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Truck icon in a soft-blue circle
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.collectorPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 36,
                  color: AppColors.collectorPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Title + subtitle
              Text(
                'Heading to Pickup!',
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Confirm you\'re on your way to collect',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    // Address row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.collectorPrimary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: AppColors.collectorPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PICKUP LOCATION',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                address,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: AppColors.borderLight),
                    ),

                    // Date + item count row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.collectorPrimary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: AppColors.collectorPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SCHEDULED',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dateLabel,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (itemCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 13,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$itemCount item${itemCount == 1 ? '' : 's'}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    if (estimatedEarnings > 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: AppColors.borderLight),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.payments_outlined,
                              size: 16,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EST. EARNINGS',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '₱${_fmtAmt(estimatedEarnings, decimals: 0)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Confirm button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.local_shipping_rounded, size: 20),
                  label: const Text("I'm On My Way!"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.collectorPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: AppTextStyles.buttonMedium,
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Dismiss
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Not Yet',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
