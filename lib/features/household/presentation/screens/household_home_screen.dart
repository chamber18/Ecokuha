import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_helpers.dart';
import '../../../../../../core/constants/firestore_fields/index.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/carbon_calculator_service.dart';
import '../../../../core/di/service_locator.dart';
import 'junkshop_locations_screen.dart';
import 'junkshop_profile_screen.dart';
import '../utils/posting_helpers.dart';
import '../../../promotions/presentation/widgets/household_promotions_carousel.dart';
import '../../../promotions/presentation/bloc/household_promotions/household_promotions_bloc.dart';
import '../../../promotions/presentation/bloc/household_promotions/household_promotions_event.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class HouseholdHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HouseholdHomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HouseholdHomeScreen> createState() => _HouseholdHomeScreenState();
}

class _HouseholdHomeScreenState extends State<HouseholdHomeScreen> {
  final _carbonCalculatorService = CarbonCalculatorService();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          getIt<HouseholdPromotionsBloc>()..add(const WatchActivePromotions()),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.successColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: AppDimensions.headerPadding,
          title: Row(
            children: [
              Image.asset(
                'assets/images/logos/bbp logo-50px.png',
                height: 32,
                width: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              const Expanded(
                child: Text(
                  'B.B.P. Tracker',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          bottom: true,
          top: false,
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.successColor,
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildStatsGrid(),
                  _buildActionButtons(),
                  const HouseholdPromotionsCarousel(),
                  _buildNearbyJunkshops(),
                  _buildRecentActivity(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyJunkshops() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with "View all" button
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby Junkshops',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JunkshopLocationsScreen(),
                    ),
                  );
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingS),

        // Fetch household location first, then junkshops
        FutureBuilder<Map<String, dynamic>?>(
          future: Supabase.instance.client
              .from('households')
              .select('location')
              .eq('id', user.id)
              .maybeSingle(),
          builder: (context, householdSnapshot) {
            double? householdLat;
            double? householdLng;

            if (householdSnapshot.hasData && householdSnapshot.data != null) {
              final data = householdSnapshot.data;
              final location = data?[UserFields.location] is Map
                  ? Map<String, dynamic>.from(data![UserFields.location] as Map)
                  : null;
              if (location != null) {
                householdLat = (location[UserFields.lat] is num)
                    ? (location[UserFields.lat] as num).toDouble()
                    : double.tryParse(
                        location[UserFields.lat]?.toString() ?? '',
                      );
                householdLng = (location[UserFields.lng] is num)
                    ? (location[UserFields.lng] as num).toDouble()
                    : double.tryParse(
                        location[UserFields.lng]?.toString() ?? '',
                      );
              }
            }

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('junkshops')
                  .stream(primaryKey: ['id'])
                  .limit(10)
                  .map((rows) => rowsToDocs('junkshops', rows)),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    child: Text(
                      'Error loading junkshops',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.errorColor,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    child: Text(
                      'No junkshops available',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                // Build junkshop data asynchronously to fetch review counts
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _buildJunkshopList(
                    snapshot.data!,
                    householdLat,
                    householdLng,
                  ),
                  builder: (context, junkshopsSnapshot) {
                    if (junkshopsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Container(
                        height: 180,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: AppColors.primaryBlue,
                        ),
                      );
                    }

                    if (!junkshopsSnapshot.hasData) {
                      return Container(
                        height: 180,
                        alignment: Alignment.center,
                        child: Text(
                          'No junkshops available',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }

                    final junkshops = junkshopsSnapshot.data!;

                    return SizedBox(
                      height: 180, // Match prototype card height
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(
                          left: AppDimensions.spacing16,
                          right: AppDimensions.spacing16,
                          top: 4,
                          bottom: 4,
                        ),
                        itemCount: junkshops.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final shop = junkshops[index];
                          return _buildJunkshopCard(context, shop, index);
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildJunkshopCard(
    BuildContext context,
    Map<String, dynamic> shop,
    int index,
  ) {
    return GestureDetector(
      onTap: () {
        // Navigate to junkshop profile
        _showJunkshopProfile(context, shop);
      },
      child: Container(
        width: 280, // Match prototype width
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background image placeholder
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: index % 3 == 0
                        ? [AppColors.success, AppColors.success]
                        : index % 3 == 1
                        ? [AppColors.primaryBlue, AppColors.primaryBlue]
                        : [AppColors.primaryOrange, AppColors.primaryOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Try to load actual image if URL is valid
              if (shop['image'] != null &&
                  (shop['image'] as String).startsWith('http'))
                Positioned.fill(
                  child: Image.network(
                    shop['image'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox.shrink();
                    },
                  ),
                ),

              // Average rating badge (top right)
              if ((shop['reviews'] as int) > 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          (shop['rating'] as double).toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom overlay with info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 108, // 60% of 180px
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: 0.6,
                        ), // lighten overlay to reduce gray feel
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shop['location'] as String,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📍 ${(shop['distance'] as double).toStringAsFixed(1)} km away',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJunkshopProfile(BuildContext context, Map<String, dynamic> shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JunkshopProfileScreen(shop: shop),
      ),
    );
  }

  String _formatOpenDays(String? fromDay, String? toDay) {
    if (fromDay == null || toDay == null) {
      return 'Not specified';
    }
    if (fromDay == toDay) {
      return fromDay;
    }
    return '$fromDay - $toDay';
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

  Future<List<Map<String, dynamic>>> _buildJunkshopList(
    List<Map<String, dynamic>> docs,
    double? householdLat,
    double? householdLng,
  ) async {
    final junkshopsFutures = docs.map((data) async {
      final junkshopId = data['id'].toString();

      // Skip junkshops disabled by admin
      if (data['isActive'] == false) return null;

      final junkshopProfile =
          data[UserFields.junkshopProfile] as Map<String, dynamic>?;
      final business = junkshopProfile?['business'] as Map<String, dynamic>?;
      final location =
          junkshopProfile?[UserFields.location] as Map<String, dynamic>?;

      // Calculate real distance if both coordinates are available
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

      // Get real rating and review count
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

      // If review count is 0 but rating exists, query the actual ratings subcollection
      if (reviewCount == 0 && rating > 0) {
        try {
          final ratingRows = await Supabase.instance.client
              .from('ratings')
              .select('id')
              .eq('target_type', 'junkshop')
              .eq('target_id', junkshopId);
          reviewCount = ratingRows.length;
        } catch (e) {
          reviewCount = 0;
        }
      }

      if (kDebugMode) {
        print(
          '🏪 Junkshop ${business?[UserFields.businessName] ?? 'Unknown'}: rating=$rating, reviews=$reviewCount',
        );
      }

      return {
        'id': junkshopId,
        'name':
            business?[UserFields.businessName] ??
            data[UserFields.fullName] ??
            'Unknown Junkshop',
        'location': location?[UserFields.address] ?? 'No address',
        'address': location?[UserFields.address] ?? 'No address available',
        'locationNote': location?['note'] as String?,
        'rating': rating,
        'image': data[UserFields.profileImageUrl],
        'collections': business?['total_collections'] ?? 0,
        'since': business?['year_established'] ?? 2020,
        'phone': business?[UserFields.phone] ?? 'No phone available',
        'hours': business?['operating_hours'] ?? '8:00 AM - 6:00 PM',
        'openDays': _formatOpenDays(
          business?['from_day'] as String?,
          business?['to_day'] as String?,
        ),
        'isOpen': _isJunkshopOpen(
          business?['from_day'] as String?,
          business?['to_day'] as String?,
          business?['open_time'] as String?,
          business?['close_time'] as String?,
        ),
        'reviews': reviewCount,
        'distance': distance,
        'rates': business?['rates'],
      };
    });

    final results = await Future.wait(junkshopsFutures);
    final junkshops = results.whereType<Map<String, dynamic>>().toList();

    // Sort by distance (closest first)
    junkshops.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );

    return junkshops;
  }

  // Header moved into AppBar to keep it non-scrollable and cover the full top area

  Widget _buildStatsGrid() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Impact',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('postings')
                .stream(primaryKey: ['id'])
                .eq('household_id', user.id)
                .map(
                  (rows) => rowsToDocs(
                    'postings',
                    rows.where((r) => r['status'] == 'completed').toList(),
                  ),
                ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading stats'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.successColor,
                  ),
                );
              }

              // Calculate stats from completed collections
              int totalCollections = 0;
              double totalEarned = 0.0;
              Set<String> uniqueMaterials = {};
              double carbonSaved = 0.0;

              if (snapshot.hasData) {
                final docs = snapshot.data!;
                totalCollections = docs.length;

                for (final data in docs) {
                  double totalValue = 0.0;

                  // Priority 1: Check purchasedItems.total (final junkshop pricing)
                  if (data['purchasedItems'] is Map<String, dynamic>) {
                    final purchased =
                        data['purchasedItems'] as Map<String, dynamic>;
                    final total = purchased['total'];
                    if (total is num) {
                      totalValue = total.toDouble();
                    } else if (total is String) {
                      totalValue = double.tryParse(total) ?? 0.0;
                    }
                  }
                  // Priority 2: Check verifiedItems.totalValue (collector verification)
                  else if (data[PostingFields.verifiedItems]
                      is Map<String, dynamic>) {
                    final verified =
                        data[PostingFields.verifiedItems]
                            as Map<String, dynamic>;
                    final totalVal = verified['totalValue'];
                    if (totalVal is num) {
                      totalValue = totalVal.toDouble();
                    } else if (totalVal is String) {
                      totalValue = double.tryParse(totalVal) ?? 0.0;
                    }
                  }
                  // Priority 3: Check top-level verified value
                  else if (data[PostingFields.totalVerifiedValue] != null) {
                    final verifiedVal = data[PostingFields.totalVerifiedValue];
                    if (verifiedVal is num) {
                      totalValue = verifiedVal.toDouble();
                    } else if (verifiedVal is String) {
                      totalValue = double.tryParse(verifiedVal) ?? 0.0;
                    }
                  }
                  // Priority 4: Fallback to estimated value
                  else {
                    final estimatedVal =
                        data[PostingFields.totalEstimatedValue];
                    if (estimatedVal is num) {
                      totalValue = estimatedVal.toDouble();
                    } else if (estimatedVal is String) {
                      totalValue = double.tryParse(estimatedVal) ?? 0.0;
                    }
                  }

                  totalEarned += totalValue;

                  // Count unique materials - check multiple sources
                  List<dynamic> items = [];

                  // Priority 1: Check purchasedItems.list (final junkshop items)
                  if (data['purchasedItems'] is Map<String, dynamic>) {
                    final purchased =
                        data['purchasedItems'] as Map<String, dynamic>;
                    if (purchased['list'] is List) {
                      items = purchased['list'] as List<dynamic>;
                    }
                  }
                  // Priority 2: Check verifiedItems.items (collector verified)
                  else if (data[PostingFields.verifiedItems]
                      is Map<String, dynamic>) {
                    final verified =
                        data[PostingFields.verifiedItems]
                            as Map<String, dynamic>;
                    if (verified['items'] is List) {
                      items = verified['items'] as List<dynamic>;
                    } else if (verified[PostingFields.itemsList] is List) {
                      items =
                          verified[PostingFields.itemsList] as List<dynamic>;
                    }
                  }
                  // Priority 3: Check direct items field (household posting)
                  else if (data[PostingFields.items] is List) {
                    items = data[PostingFields.items] as List<dynamic>;
                  }

                  // Add unique material names to the set
                  for (final item in items) {
                    if (item is Map<String, dynamic>) {
                      final materialName =
                          item['name'] as String? ??
                          item['category'] as String? ??
                          'Other';
                      uniqueMaterials.add(materialName);
                    }
                  }
                }
              }
              return FutureBuilder<CarbonSavingsReport>(
                future: _carbonCalculatorService.calculateTotalCarbon(
                  userId: user.id,
                ),
                builder: (context, carbonSnapshot) {
                  if (carbonSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !carbonSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.successColor,
                      ),
                    );
                  }

                  if (carbonSnapshot.hasError) {
                    // If there's an error in the detailed calculator,
                    // fall back to showing 0 for carbon saved but keep other stats.
                    carbonSaved = 0.0;
                  } else if (carbonSnapshot.hasData) {
                    carbonSaved = carbonSnapshot.data!.totalKgCO2;
                  }

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppDimensions.spacing12,
                    crossAxisSpacing: AppDimensions.spacing12,
                    childAspectRatio: 1.2,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/household/history');
                        },
                        child: _buildStatsCard(
                          title: 'Total Collections',
                          value: totalCollections.toString(),
                          icon: Icons.recycling_outlined,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/household/history');
                        },
                        child: _buildStatsCard(
                          title: 'Total Earned',
                          value: AppFormatters.currencyWhole(totalEarned),
                          icon: FluentIcons.money_24_regular,
                          color: AppColors.successColor,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final userId = Supabase.instance.client.auth.currentUser?.id;
                          if (userId != null && context.mounted) {
                            Navigator.pushNamed(
                              context,
                              '/household/carbon-impact',
                              arguments: {'userId': userId},
                            );
                          }
                        },
                        child: _buildStatsCard(
                          title: 'Carbon Saved',
                          value: '${AppFormatters.number(carbonSaved)} kg',
                          icon: Icons.eco_outlined,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/household/materials');
                        },
                        child: _buildStatsCard(
                          title: 'Items Recycled',
                          value: uniqueMaterials.length.toString(),
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.warningColor,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMd,
          vertical: AppDimensions.paddingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: AppDimensions.iconM),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  ),
                  child: Icon(Icons.trending_up, color: color, size: 14),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTextStyles.statsValue.copyWith(color: color),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTextStyles.statsLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final quickActions = [
      {
        'icon': FluentIcons.camera_add_24_regular,
        'label': 'Post',
        'action': () => widget.onNavigateToTab?.call(1),
      },
      {
        'icon': FluentIcons.history_24_regular,
        'label': 'History',
        'action': () => Navigator.pushNamed(context, '/household/history'),
      },
      {
        'icon': FluentIcons.trophy_24_regular,
        'label': 'Leaderboard',
        'action': () => Navigator.pushNamed(context, '/household/leaderboard'),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Row(
            children: quickActions.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < quickActions.length - 1 ? 12 : 0,
                  ),
                  child: _buildQuickActionItem(
                    icon: action['icon'] as IconData,
                    label: action['label'] as String,
                    onTap: action['action'] as VoidCallback,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 53,
              height: 53,
              decoration: const BoxDecoration(
                color: AppColors.containerGray,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Collections',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/household/history');
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('postings')
                .stream(primaryKey: ['id'])
                .eq('household_id', user.id)
                .order('created_at', ascending: false)
                .limit(3)
                .map((rows) => rowsToDocs('postings', rows)),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint(
                  'Error loading recent collections: ${snapshot.error}',
                );
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingXl),
                    child: Text(
                      'Error loading collections',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.errorColor,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.successColor,
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingXl),
                    child: Text(
                      'No collections yet',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              final collections = snapshot.data!;

              return Column(
                children: [
                  for (int i = 0; i < collections.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppDimensions.spacing12),
                    _buildCollectionCard(collections[i]),
                  ],
                  const SizedBox(height: AppDimensions.spacingXxl),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> data) {

    // Parse items - handle both flat list and nested structure
    final itemsContainer = data[PostingFields.items];
    List<dynamic> itemsData = [];
    if (itemsContainer is List) {
      itemsData = itemsContainer;
    } else if (itemsContainer is Map<String, dynamic>) {
      final list = itemsContainer[PostingFields.itemsList];
      if (list is List) {
        itemsData = list;
      }
    }

    String title = 'Collection';

    if (itemsData.isNotEmpty) {
      final firstItem = itemsData[0];
      if (firstItem is Map<String, dynamic>) {
        final name = firstItem[PostingFields.itemName]?.toString() ?? 'Items';
        final quantity =
            firstItem[PostingFields.itemQuantity]?.toString() ?? '';
        final unit = firstItem[PostingFields.itemUnit]?.toString() ?? '';

        if (itemsData.length == 1) {
          title = '$name${quantity.isNotEmpty ? " ($quantity $unit)" : ""}';
        } else {
          title = '$name +${itemsData.length - 1}more';
        }
      }
    }

    // Calculate total value from items
    double totalValue = 0.0;
    for (var item in itemsData) {
      if (item is Map<String, dynamic>) {
        final itemValue =
            (item[PostingFields.itemEstimatedValue] as num?)?.toDouble() ?? 0.0;
        totalValue += itemValue;
      }
    }

    // Fallback to stored total if items calculation is 0
    if (totalValue == 0.0) {
      totalValue =
          (data[PostingFields.totalEstimatedValue] as num?)?.toDouble() ?? 0.0;
    }

    final status = data[PostingFields.status]?.toString() ?? 'pending';

    // Determine status display - descriptive text below material name
    String statusText = 'Waiting for junkshop to confirm';
    String statusBadge = 'Pending';
    Color statusColor = AppColors.warningColor;

    if (status == 'completed') {
      statusText = 'Successfully collected';
      statusBadge = 'Completed';
      statusColor = AppColors.statusCompleted;
    } else if (status == 'collected') {
      statusText = 'Collection completed';
      statusBadge = 'Collected';
      statusColor = AppColors.statusEnRoute;
    } else if (status == 'assigned') {
      statusText = 'Collector assigned';
      statusBadge = 'Assigned';
      statusColor = AppColors.statusEnRoute;
    } else if (status == 'in_progress') {
      statusText = 'Collector on the way';
      statusBadge = 'Ongoing';
      statusColor = AppColors.statusEnRoute;
    } else if (status == 'pending') {
      statusText = 'Waiting for junkshop to confirm';
      statusBadge = 'Pending';
      statusColor = AppColors.warningColor;
    } else if (status == 'scheduled') {
      statusText = 'Pickup scheduled';
      statusBadge = 'Scheduled';
      statusColor = AppColors.primaryBlue;
    } else if (status == 'declined') {
      statusText = 'Request declined';
      statusBadge = 'Declined';
      statusColor = AppColors.errorColor;
    } else if (status == 'cancelled' || status == 'cancelled_by_collector') {
      statusText = 'Collection cancelled';
      statusBadge = 'Cancelled';
      statusColor = AppColors.errorColor;
    }

    return GestureDetector(
      onTap: () {
        // Navigate based on status: completed -> History (open that collection), others -> Track
        if (status == 'completed') {
          Navigator.of(
            context,
          ).pushNamed('/household/history', arguments: {'focusId': data['id']});
        } else if (status == 'assigned' ||
            status == 'pending' ||
            status == 'scheduled' ||
            status == 'in_progress' ||
            status == 'collected' ||
            status == 'declined' ||
            status == 'cancelled' ||
            status == 'cancelled_by_collector') {
          widget.onNavigateToTab?.call(2); // Track tab
        } else {
          // Fallback to Track
          widget.onNavigateToTab?.call(2);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMd,
          vertical: AppDimensions.paddingSm,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: AppDimensions.spacingS),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(statusText, style: AppTextStyles.activitySubtitle),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppFormatters.currency(totalValue),
                        style: AppTextStyles.activityValue,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingS,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.statusBadgeRadius,
                          ),
                        ),
                        child: Text(
                          statusBadge,
                          style: AppTextStyles.statusBadge.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialCategoryCard extends StatefulWidget {
  final String category;
  final String icon;
  final List<Map<String, dynamic>> materials;

  const _MaterialCategoryCard({
    required this.category,
    required this.icon,
    required this.materials,
  });

  @override
  State<_MaterialCategoryCard> createState() => _MaterialCategoryCardState();
}

class _MaterialCategoryCardState extends State<_MaterialCategoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final displayMaterials = _isExpanded
        ? widget.materials
        : widget.materials.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                widget.category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...displayMaterials.map((material) {
            final priceMin = material['priceMin'] as num?;
            final priceMax = material['priceMax'] as num?;
            final unit = material['unit'] as String? ?? 'piece';

            String priceText;
            if (priceMin != null && priceMax != null) {
              if (priceMin == priceMax) {
                priceText =
                    '${AppFormatters.currencyWhole(priceMin.toDouble())}/$unit';
              } else {
                priceText =
                    '${AppFormatters.currencyWhole(priceMin.toDouble())}-${AppFormatters.currencyWhole(priceMax.toDouble())}/$unit';
              }
            } else {
              priceText = 'Price not set';
            }

            final isActive = material['isActive'] as bool? ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            material['name'] as String,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.successColor.withValues(alpha: 0.15)
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.15,
                                  ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppColors.successColor
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    priceText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.successColor,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (widget.materials.length > 3)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text(
                      _isExpanded
                          ? 'Show less'
                          : '+${widget.materials.length - 3} more items',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
