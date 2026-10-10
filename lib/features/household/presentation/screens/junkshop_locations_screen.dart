import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_helpers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../../../../../../core/constants/firestore_fields/index.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/phone_launcher.dart';
import '../utils/direct_chat_helper.dart';
import 'junkshop_profile_screen.dart';
import '../utils/posting_helpers.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class JunkshopLocationsScreen extends StatefulWidget {
  const JunkshopLocationsScreen({super.key});

  @override
  State<JunkshopLocationsScreen> createState() =>
      _JunkshopLocationsScreenState();
}

class _JunkshopLocationsScreenState extends State<JunkshopLocationsScreen> {
  bool _showMap = false;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Near Me', 'Highest Rates', 'Open Now'];
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  int _refreshTrigger = 0;

  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  final Set<Marker> _markers = {};
  final ValueNotifier<Junkshop?> _selectedJunkshop = ValueNotifier(null);
  LatLng? _householdLocation;
  bool _markersBuilt = false;
  @override
  void initState() {
    super.initState();
    // Ensure markers rebuild on hot restart
    _markersBuilt = false;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _selectedJunkshop.dispose();
    super.dispose();
  }

  void _zoomToLocation(LatLng latLng) {
    if (_mapController != null) {
      // Offset center slightly south so the pin appears above the bottom info card
      final target = LatLng(latLng.latitude - 0.0012, latLng.longitude);
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 16.0),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
        title: const Text(
          'Junkshop Locations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showMap = !_showMap;
                _markersBuilt = false;
                _markers.clear();
              });
            },
            icon: Icon(
              _showMap ? Icons.list_rounded : Icons.map_outlined,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (!_showMap) _buildFilterSection(),
          Expanded(child: _showMap ? _buildMapView() : _buildListView()),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = filter == _selectedFilter;
            return Padding(
              padding: const EdgeInsets.only(right: AppDimensions.paddingS),
              child: FilterChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter;
                    _refreshTrigger++; // Trigger rebuild with new filter
                    _markersBuilt = false; // Rebuild markers for new filter
                    _markers.clear(); // Force clear markers
                  });
                },
                backgroundColor: Colors.white,
                selectedColor: AppColors.successColor.withValues(alpha: 0.12),
                labelStyle: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected
                      ? AppColors.successColor
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.successColor
                      : AppColors.borderLight,
                ),
                checkmarkColor: AppColors.successColor,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildListView() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in'));
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('households')
          .select('location')
          .eq('id', user.id)
          .maybeSingle(),
      builder: (context, householdSnapshot) {
        if (householdSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading your location',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.errorColor,
              ),
            ),
          );
        }

        if (householdSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.successColor),
          );
        }

        double? householdLat;
        double? householdLng;

        if (householdSnapshot.hasData && householdSnapshot.data != null) {
          final householdData = householdSnapshot.data;
          final location = householdData?[UserFields.location] is Map
              ? Map<String, dynamic>.from(
                  householdData![UserFields.location] as Map,
                )
              : null;

          if (location != null) {
            householdLat = (location[UserFields.lat] is num)
                ? (location[UserFields.lat] as num).toDouble()
                : double.tryParse(location[UserFields.lat]?.toString() ?? '');
            householdLng = (location[UserFields.lng] is num)
                ? (location[UserFields.lng] as num).toDouble()
                : double.tryParse(location[UserFields.lng]?.toString() ?? '');
          }
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('junkshops')
              .stream(primaryKey: ['id'])
              .map((rows) => rowsToDocs('junkshops', rows)),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.errorColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading junkshops',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.errorColor,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.successColor),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  'No junkshops available',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            return FutureBuilder<List<Junkshop>>(
              key: ValueKey(_refreshTrigger),
              future: _buildJunkshopList(
                snapshot.data!,
                householdLat,
                householdLng,
              ),
              builder: (context, junkshopsSnapshot) {
                if (junkshopsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.successColor,
                    ),
                  );
                }

                if (!junkshopsSnapshot.hasData ||
                    junkshopsSnapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No junkshops available',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                final junkshops = junkshopsSnapshot.data!;

                return RefreshIndicator(
                  key: _refreshKey,
                  color: AppColors.successColor,
                  onRefresh: () async {
                    setState(() {
                      _refreshTrigger++;
                      _markersBuilt =
                          false; // Allow markers to rebuild on refresh
                    });
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.paddingMd),
                    itemCount: junkshops.length,
                    itemBuilder: (context, index) {
                      final junkshop = junkshops[index];
                      return _buildJunkshopCard(junkshop);
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  bool _isJunkshopOpen(
    String? fromDay,
    String? toDay,
    String? openTime,
    String? closeTime,
  ) {
    if (fromDay == null ||
        toDay == null ||
        openTime == null ||
        closeTime == null) {
      return false;
    }

    final now = DateTime.now();
    final currentDay = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][now.weekday - 1];

    // Check if current day is within operating days
    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final fromIndex = daysOfWeek.indexOf(fromDay);
    final toIndex = daysOfWeek.indexOf(toDay);
    final currentIndex = daysOfWeek.indexOf(currentDay);

    bool isDayOpen = false;
    if (fromIndex <= toIndex) {
      // Normal range (e.g., Monday to Friday)
      isDayOpen = currentIndex >= fromIndex && currentIndex <= toIndex;
    } else {
      // Wrap around (e.g., Friday to Monday)
      isDayOpen = currentIndex >= fromIndex || currentIndex <= toIndex;
    }

    if (!isDayOpen) {
      return false;
    }

    // Parse time strings (format: "HH:mm")
    final openParts = openTime.split(':');
    final closeParts = closeTime.split(':');

    if (openParts.length != 2 || closeParts.length != 2) {
      return false;
    }

    final openHour = int.tryParse(openParts[0]);
    final openMinute = int.tryParse(openParts[1]);
    final closeHour = int.tryParse(closeParts[0]);
    final closeMinute = int.tryParse(closeParts[1]);

    if (openHour == null ||
        openMinute == null ||
        closeHour == null ||
        closeMinute == null) {
      return false;
    }

    final openDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      openHour,
      openMinute,
    );
    final closeDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      closeHour,
      closeMinute,
    );

    // Check if current time is within operating hours
    return now.isAfter(openDateTime) && now.isBefore(closeDateTime);
  }

  Future<List<Junkshop>> _buildJunkshopList(
    List<Map<String, dynamic>> docs,
    double? householdLat,
    double? householdLng,
  ) async {
    final junkshopsFutures = docs.map((data) async {
      final junkshopDocId = data['id'].toString();
      final junkshopProfile =
          data[UserFields.junkshopProfile] as Map<String, dynamic>?;
      final business = junkshopProfile?['business'] as Map<String, dynamic>?;
      final location =
          junkshopProfile?[UserFields.location] as Map<String, dynamic>?;

      // Calculate real distance
      double distance = 0.0;
      double? junkshopLat;
      double? junkshopLng;

      if (location != null) {
        junkshopLat = (location[UserFields.lat] is num)
            ? (location[UserFields.lat] as num).toDouble()
            : double.tryParse(location[UserFields.lat]?.toString() ?? '');
        junkshopLng = (location[UserFields.lng] is num)
            ? (location[UserFields.lng] as num).toDouble()
            : double.tryParse(location[UserFields.lng]?.toString() ?? '');
      }

      if (householdLat != null &&
          householdLng != null &&
          junkshopLat != null &&
          junkshopLng != null) {
        distance = PostingHelpers.calculateDistance(
          householdLat,
          householdLng,
          junkshopLat,
          junkshopLng,
        );
      }

      // Get real rating
      double rating = 0.0;
      if (business?[UserFields.rating] != null) {
        rating = (business![UserFields.rating] as num).toDouble();
      } else if (business?['averageRating'] != null) {
        rating = (business!['averageRating'] as num).toDouble();
      } else if (data[UserFields.rating] != null) {
        rating = (data[UserFields.rating] as num).toDouble();
      } else if (data['averageRating'] != null) {
        rating = (data['averageRating'] as num).toDouble();
      }

      // Get review count from document first
      int reviewCount =
          (business?['review_count'] as num?)?.toInt() ??
          (business?['totalRatings'] as num?)?.toInt() ??
          (data['review_count'] as num?)?.toInt() ??
          (data['totalRatings'] as num?)?.toInt() ??
          0;

      // If review count is 0 or rating exists, query the ratings subcollection to be sure
      if (reviewCount == 0 || rating > 0) {
        try {
          final ratingRows = await Supabase.instance.client
              .from('ratings')
              .select('id')
              .eq('target_type', 'junkshop')
              .eq('target_id', junkshopDocId);
          reviewCount = ratingRows.length;
        } catch (e) {
          reviewCount = 0;
        }
      }

      if (kDebugMode) {
        print(
          '🏪 [Locations] Junkshop ${business?[UserFields.businessName] ?? 'Unknown'}: rating=$rating, reviews=$reviewCount, distance=${distance.toStringAsFixed(1)} km',
        );
      }

      return Junkshop(
        id: junkshopDocId,
        name:
            business?[UserFields.businessName] ??
            data[UserFields.fullName] ??
            'Unknown Junkshop',
        distance: '${distance.toStringAsFixed(1)} km',
        rating: rating,
        reviewCount: reviewCount,
        address: location?[UserFields.address] ?? 'No address available',
        locationNote: location?['note'] as String?,
        phone: business?[UserFields.phone] ?? 'No phone available',
        hours: business?['operating_hours'] ?? '8:00 AM - 6:00 PM',
        isOpen: _isJunkshopOpen(
          business?['from_day'] as String?,
          business?['to_day'] as String?,
          business?['open_time'] as String?,
          business?['close_time'] as String?,
        ),
        specialties:
            (business?['specialties'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['General'],
        rates:
            (business?['rates'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, value.toString()),
            ) ??
            {},
        latitude: junkshopLat,
        longitude: junkshopLng,
      );
    });

    final junkshops = await Future.wait(junkshopsFutures);

    // Apply filters
    List<Junkshop> filteredJunkshops = junkshops;

    switch (_selectedFilter) {
      case 'Near Me':
        // Already sorted by distance, just take closest ones
        filteredJunkshops = junkshops.where((j) {
          final dist =
              double.tryParse(j.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0.0;
          return dist <= 10.0; // Within 10 km
        }).toList();
        break;
      case 'Highest Rates':
        // Sort by rating (highest first)
        filteredJunkshops = List.from(junkshops);
        filteredJunkshops.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Open Now':
        // Filter only open junkshops
        filteredJunkshops = junkshops.where((j) => j.isOpen).toList();
        break;
      case 'All':
      default:
        // Sort by distance (closest first)
        filteredJunkshops = List.from(junkshops);
        filteredJunkshops.sort((a, b) {
          final distanceA =
              double.tryParse(a.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0.0;
          final distanceB =
              double.tryParse(b.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0.0;
          return distanceA.compareTo(distanceB);
        });
        break;
    }

    return filteredJunkshops;
  }

  Widget _buildJunkshopCard(Junkshop junkshop) {
    return GestureDetector(
      onTap: () => _showJunkshopDetails(junkshop),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadowColor,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Expanded(
                  child: Text(junkshop.name, style: AppTextStyles.cardTitle),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingS,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: junkshop.isOpen
                        ? AppColors.successColor
                        : AppColors.errorColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    junkshop.isOpen ? 'Open' : 'Closed',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textWhite,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            // Rating and distance
            Row(
              children: [
                if (junkshop.reviewCount > 0) ...[
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${junkshop.rating.toStringAsFixed(1)} (${junkshop.reviewCount} ${junkshop.reviewCount == 1 ? 'review' : 'reviews'})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.star_border,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'No reviews yet',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const Spacer(),
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  junkshop.distance,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            // Address
            Text(junkshop.address, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppDimensions.spacingS),
            // Hours
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(junkshop.hours, style: AppTextStyles.bodySmall),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing12),
            // Specialties
            Wrap(
              spacing: AppDimensions.spacingXs,
              runSpacing: AppDimensions.spacingXs,
              children: junkshop.specialties.map((specialty) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingS,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    specialty,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callJunkshop(junkshop),
                    icon: const Icon(
                      Icons.phone,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                    label: const Text(
                      'Call',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusM,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openOrCreateConversation(junkshop),
                    icon: const Icon(
                      Icons.message,
                      size: 16,
                      color: AppColors.textWhite,
                    ),
                    label: const Text(
                      'Message',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusM,
                        ),
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

  Widget _buildMapView() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in'));
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('households')
          .select('location')
          .eq('id', user.id)
          .maybeSingle(),
      builder: (context, householdSnapshot) {
        if (householdSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.successColor),
          );
        }

        double? householdLat;
        double? householdLng;

        if (householdSnapshot.hasData && householdSnapshot.data != null) {
          final householdData = householdSnapshot.data;
          final location = householdData?[UserFields.location] is Map
              ? Map<String, dynamic>.from(
                  householdData![UserFields.location] as Map,
                )
              : null;

          if (location != null) {
            householdLat = (location[UserFields.lat] is num)
                ? (location[UserFields.lat] as num).toDouble()
                : double.tryParse(location[UserFields.lat]?.toString() ?? '');
            householdLng = (location[UserFields.lng] is num)
                ? (location[UserFields.lng] as num).toDouble()
                : double.tryParse(location[UserFields.lng]?.toString() ?? '');

            if (householdLat != null && householdLng != null) {
              _householdLocation = LatLng(householdLat, householdLng);
            }
          }
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('junkshops')
              .stream(primaryKey: ['id'])
              .map((rows) => rowsToDocs('junkshops', rows)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.successColor),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No junkshops available'));
            }

            return FutureBuilder<List<Junkshop>>(
              key: ValueKey(_refreshTrigger),
              future: _buildJunkshopList(
                snapshot.data!,
                householdLat,
                householdLng,
              ),
              builder: (context, junkshopsSnapshot) {
                if (junkshopsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.successColor,
                    ),
                  );
                }

                if (!junkshopsSnapshot.hasData ||
                    junkshopsSnapshot.data!.isEmpty) {
                  return const Center(child: Text('No junkshops available'));
                }

                final junkshops = junkshopsSnapshot.data!;

                // Build markers only once when data changes
                if (!_markersBuilt) {
                  _buildMapMarkers(junkshops, householdLat, householdLng);
                }

                // Calculate center position for initial camera
                LatLng initialPosition =
                    _householdLocation ??
                    const LatLng(14.5995, 120.9842); // Manila default

                return Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialPosition,
                        zoom: 13,
                      ),
                      markers: _markers,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        if (!_mapControllerCompleter.isCompleted) {
                          _mapControllerCompleter.complete(controller);
                        }
                        _fitMarkersInView();
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapType: MapType.normal,
                      onTap: (_) => _selectedJunkshop.value = null,
                    ),
                    // Overlay: FAB + bottom card — only this rebuilds on pin tap
                    ValueListenableBuilder<Junkshop?>(
                      valueListenable: _selectedJunkshop,
                      builder: (context, selected, _) => Stack(
                        children: [
                          Positioned(
                            right: 16,
                            bottom: selected != null ? 200 : 80,
                            child: FloatingActionButton(
                              mini: true,
                              backgroundColor: AppColors.backgroundLight,
                              onPressed: () {
                                if (_householdLocation != null &&
                                    _mapController != null) {
                                  _mapController!.animateCamera(
                                    CameraUpdate.newLatLng(_householdLocation!),
                                  );
                                }
                              },
                              child: const Icon(
                                Icons.my_location,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          if (selected != null)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: _buildMapJunkshopCard(selected),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _buildMapMarkers(
    List<Junkshop> junkshops,
    double? householdLat,
    double? householdLng,
  ) async {
    if (_markersBuilt) return;

    _markers.clear();

    // Add household marker if location exists
    if (householdLat != null && householdLng != null) {
      final householdIcon = await _createCustomMarkerWithLabel(
        'Your Location',
        '',
        true,
        isHousehold: true,
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('household'),
          position: LatLng(householdLat, householdLng),
          icon: householdIcon,
          anchor: const Offset(0.5, 0.683),
        ),
      );
    }

    // Add junkshop markers with labels
    for (final junkshop in junkshops) {
      final latLng = _getJunkshopLatLng(junkshop);
      if (latLng != null) {
        final markerIcon = await _createCustomMarkerWithLabel(
          junkshop.name,
          junkshop.distance,
          junkshop.isOpen,
        );

        _markers.add(
          Marker(
            markerId: MarkerId(junkshop.id),
            position: latLng,
            icon: markerIcon,
            anchor: const Offset(0.5, 0.683),
            onTap: () {
              _selectedJunkshop.value = junkshop;
              // Short delay lets the bottom card render before camera animates
              Future.delayed(const Duration(milliseconds: 150), () {
                _zoomToLocation(latLng);
              });
            },
          ),
        );
      }
    }

    _markersBuilt = true;
    if (mounted) {
      setState(() {}); // Trigger single rebuild with markers
    }
  }

  LatLng? _getJunkshopLatLng(Junkshop junkshop) {
    if (junkshop.latitude != null && junkshop.longitude != null) {
      return LatLng(junkshop.latitude!, junkshop.longitude!);
    }
    return null;
  }

  /// Modern centered pin + pill-label marker.
  /// Layout (logical px, rendered at 2.5× for crisp display):
  ///   shadow pad → circle → triangle tip → gap → label pill → shadow pad
  /// Anchor: (0.5, 0.683) → pin tip at the map coordinate.
  Future<BitmapDescriptor> _createCustomMarkerWithLabel(
    String name,
    String distance,
    bool isOpen, {
    bool isHousehold = false,
  }) async {
    // Draw at 3× device pixels so Maps renders crisp at the correct logical size
    const double s = 3.0;
    const double circleR = 16.0;
    const double tipH = 9.0;
    const double pad = 5.0;
    const double labelH = 18.0;
    const double labelGap = 3.0;
    const double labelPadX = 10.0;
    const double labelFontSize = 11.0;

    final Color pinColor = isHousehold
        ? const Color(0xFF2563EB)
        : (isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    final displayName = name.length > 16 ? '${name.substring(0, 16)}...' : name;

    // Measure label text at canvas scale
    final tp = TextPainter(textDirection: ui.TextDirection.ltr)
      ..text = TextSpan(
        text: displayName,
        style: TextStyle(
          fontSize: labelFontSize * s,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF374151),
          letterSpacing: -0.3,
        ),
      )
      ..layout();

    // Label logical width: text + padding, clamped so pin always fits
    final double labelW = (tp.width / s + labelPadX * 2).clamp(
      circleR * 2,
      120.0,
    );

    // Canvas dimensions
    final double cW = (labelW + pad * 2) * s;
    final double cH = (pad + circleR * 2 + tipH + labelGap + labelH + pad) * s;
    final double cx = cW / 2;

    // Key Y positions (canvas px)
    final double circleY = (pad + circleR) * s;
    final double tipY = (pad + circleR * 2 + tipH) * s;
    final double labelTopY = tipY + labelGap * s;

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    // ── Pin circle ──
    c.drawCircle(Offset(cx, circleY), circleR * s, Paint()..color = pinColor);

    // ── Teardrop triangle ──
    final double halfBase = circleR * s * 0.65; // stays within circle bounds
    final double triTop = circleY + circleR * s - 6.0 * s;
    c.drawPath(
      Path()
        ..moveTo(cx - halfBase, triTop)
        ..lineTo(cx, tipY)
        ..lineTo(cx + halfBase, triTop)
        ..close(),
      Paint()..color = pinColor,
    );

    // ── White inner ring ──
    c.drawCircle(
      Offset(cx, circleY),
      circleR * s * 0.50,
      Paint()..color = Colors.white,
    );

    // ── Colored center dot ──
    c.drawCircle(
      Offset(cx, circleY),
      circleR * s * 0.22,
      Paint()..color = pinColor,
    );

    final double labelLeft = cx - labelW * s / 2;
    // (no blur shadow — keeps shapes crisp at small sizes)

    // ── Label background ──
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(labelLeft, labelTopY, labelW * s, labelH * s),
        Radius.circular(labelH / 2 * s),
      ),
      Paint()..color = Colors.white,
    );

    // ── Label border ──
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(labelLeft, labelTopY, labelW * s, labelH * s),
        Radius.circular(labelH / 2 * s),
      ),
      Paint()
        ..color = pinColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * s,
    );

    // ── Label text ──
    tp.paint(
      c,
      Offset(cx - tp.width / 2, labelTopY + (labelH * s - tp.height) / 2),
    );

    // ── Render ──
    final img = await rec.endRecording().toImage(cW.toInt(), cH.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    // imagePixelRatio tells Maps this bitmap is 3× density → renders at correct logical size, no upscaling blur
    return BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: s,
    );
  }

  void _fitMarkersInView() {
    if (_markers.isEmpty || _mapController == null) return;

    LatLngBounds? bounds;
    for (final marker in _markers) {
      if (bounds == null) {
        bounds = LatLngBounds(
          southwest: marker.position,
          northeast: marker.position,
        );
      } else {
        bounds = LatLngBounds(
          southwest: LatLng(
            bounds.southwest.latitude < marker.position.latitude
                ? bounds.southwest.latitude
                : marker.position.latitude,
            bounds.southwest.longitude < marker.position.longitude
                ? bounds.southwest.longitude
                : marker.position.longitude,
          ),
          northeast: LatLng(
            bounds.northeast.latitude > marker.position.latitude
                ? bounds.northeast.latitude
                : marker.position.latitude,
            bounds.northeast.longitude > marker.position.longitude
                ? bounds.northeast.longitude
                : marker.position.longitude,
          ),
        );
      }
    }

    if (bounds != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  Widget _buildMapJunkshopCard(Junkshop junkshop) {
    return GestureDetector(
      onTap: () => _showJunkshopDetails(junkshop),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadowColor,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(junkshop.name, style: AppTextStyles.cardTitle),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            junkshop.rating.toStringAsFixed(1),
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            junkshop.distance,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
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
                    color: junkshop.isOpen
                        ? AppColors.successColor
                        : AppColors.errorColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    junkshop.isOpen ? 'Open' : 'Closed',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textWhite,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callJunkshop(junkshop),
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(color: AppColors.primaryBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openOrCreateConversation(junkshop),
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: AppColors.textWhite,
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

  void _showJunkshopDetails(Junkshop junkshop) async {
    // Fetch the full junkshop document to pass to JunkshopProfileScreen
    final junkshopRow = await Supabase.instance.client
        .from('junkshops')
        .select()
        .eq('id', junkshop.id)
        .maybeSingle();

    if (junkshopRow == null) return;

    final data = rowToDoc('junkshops', junkshopRow);    final junkshopProfile =
        data[UserFields.junkshopProfile] as Map<String, dynamic>?;
    final business = junkshopProfile?['business'] as Map<String, dynamic>?;
    final location =
        junkshopProfile?[UserFields.location] as Map<String, dynamic>?;

    // Parse distance string to double (e.g., "2.5 km" -> 2.5)
    double distanceValue = 0.0;
    try {
      final distanceStr = junkshop.distance.replaceAll(RegExp(r'[^0-9.]'), '');
      distanceValue = double.tryParse(distanceStr) ?? 0.0;
    } catch (e) {
      distanceValue = 0.0;
    }

    // Create shop data in the same format as household_home_screen
    final shopData = {
      'id': junkshop.id,
      'name':
          business?[UserFields.businessName] ??
          data[UserFields.fullName] ??
          'Unknown Junkshop',
      'location': location?[UserFields.address] ?? 'No address',
      'address': location?[UserFields.address] ?? 'No address available',
      'locationNote': location?['note'] as String?,
      'rating': junkshop.rating,
      'image': data[UserFields.profileImageUrl] ?? business?['image'],
      'collections': business?['total_collections'] ?? 0,
      'since': business?['year_established'] ?? 2020,
      'phone': business?[UserFields.phone] ?? 'No phone available',
      'hours': business?['operating_hours'] ?? '8:00 AM - 6:00 PM',
      'isOpen': _isJunkshopOpen(
        business?['from_day'] as String?,
        business?['to_day'] as String?,
        business?['open_time'] as String?,
        business?['close_time'] as String?,
      ),
      'reviews': junkshop.reviewCount,
      'distance': distanceValue,
      'rates': business?['rates'],
    };

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JunkshopProfileScreen(shop: shopData),
      ),
    );
  }

  void _callJunkshop(Junkshop junkshop) async {
    final phoneNumber = junkshop.phone;
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

  Future<void> _openOrCreateConversation(Junkshop junkshop) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to send messages'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final conversation = await DirectChatHelper.getOrCreate(
        currentUserId: currentUserId,
        junkshopId: junkshop.id,
        junkshopName: junkshop.name,
      );

      if (conversation != null && mounted) {
        Navigator.pushNamed(
          context,
          '/household/conversation',
          arguments: {'conversation': conversation},
        );
      }    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Data class
class Junkshop {
  final String id;
  final String name;
  final String distance;
  final double rating;
  final int reviewCount;
  final String address;
  final String? locationNote;
  final String phone;
  final String hours;
  final bool isOpen;
  final List<String> specialties;
  final Map<String, String> rates;
  final double? latitude;
  final double? longitude;

  Junkshop({
    required this.id,
    required this.name,
    required this.distance,
    required this.rating,
    required this.reviewCount,
    required this.address,
    this.locationNote,
    required this.phone,
    required this.hours,
    required this.isOpen,
    required this.specialties,
    required this.rates,
    this.latitude,
    this.longitude,
  });
}
