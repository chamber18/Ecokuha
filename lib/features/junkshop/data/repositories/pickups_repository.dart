import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';

class NewPickupItem {
  final String id;
  final String householdId;
  final double totalValue;
  final double? estimatedTotalWeight; // Total weight in kg
  final List<String> items; // e.g., ["Plastic Bottles (2.3 kg)"]
  final List<ItemDetail> itemDetails; // Detailed item information
  final DateTime? createdAt;
  final String? householdName;
  final String? addressShort;
  final String? fullAddress; // Full location from 'location' field
  final double? householdLat; // Household latitude
  final double? householdLng; // Household longitude
  final double? distanceKm; // Distance from junkshop in kilometers
  final String? profileImageUrl;
  final List<DateTime>? unavailableDates; // Dates household is NOT available
  final DateTime? scheduledDate;
  final String? scheduledTime;
  final String? specialInstructions;
  final List<String> imageUrls; // All image URLs from posting items
  final List<String> categories; // All unique categories from items
  final String? assignedJunkshopId; // Junkshop assigned to this pickup
  final String? assignedCollectorId;
  final String? assignedCollectorName;
  final String? assignedCollectorPhoto;
  final DateTime? dateOfCollection; // Date selected by junkshop for collection
  final Map<String, List<String>>
  proofPhotos; // Proof photos from collector {arrival, collection, before_after}
  final List<String> paymentProofUrls; // Payment proof photos
  final DateTime?
  reviewedAt; // When junkshop reviewed this completed collection
  final List<ItemDetail>?
  purchasedItems; // Items purchased by junkshop from collector with junkshop-set prices
  final double?
  junkshopPurchaseTotal; // Total amount junkshop paid to collector
  final String? status; // Current status of the posting
  final String?
  previousCollector; // Previous collector name if reassign requested
  final String?
  previousCollectorId; // Previous collector ID if reassign requested
  final String?
  previousCollectorPhoto; // Previous collector photo if reassign requested
  final DateTime? rescheduleRequestedAt; // When reschedule was requested
  final List<String>? rescheduleReasons; // Reasons for reschedule
  final String? rescheduleDetail; // Additional reschedule details
  final bool?
  isReviewed; // Whether junkshop has reviewed and paid for this collection

  NewPickupItem({
    required this.id,
    required this.householdId,
    required this.totalValue,
    this.estimatedTotalWeight,
    required this.items,
    this.itemDetails = const [],
    this.createdAt,
    this.householdName,
    this.addressShort,
    this.fullAddress,
    this.householdLat,
    this.householdLng,
    this.distanceKm,
    this.profileImageUrl,
    this.unavailableDates,
    this.scheduledDate,
    this.scheduledTime,
    this.specialInstructions,
    this.imageUrls = const [],
    this.categories = const [],
    this.assignedJunkshopId,
    this.assignedCollectorId,
    this.assignedCollectorName,
    this.assignedCollectorPhoto,
    this.dateOfCollection,
    this.proofPhotos = const {},
    this.paymentProofUrls = const [],
    this.reviewedAt,
    this.purchasedItems,
    this.junkshopPurchaseTotal,
    this.status,
    this.previousCollector,
    this.previousCollectorId,
    this.previousCollectorPhoto,
    this.rescheduleRequestedAt,
    this.rescheduleReasons,
    this.rescheduleDetail,
    this.isReviewed,
  });
}

class ItemDetail {
  final String name;
  final String quantity;
  final String unit;
  final String condition;
  final String? category;
  final List<String> imagePaths;
  final double? pricePerUnit; // Collector's price per unit
  final double? totalPrice; // Collector's total price
  final double? junkshopPricePerUnit; // Junkshop's buying price per unit
  final double?
  junkshopTotalPrice; // Junkshop's total buying price for this item
  final double? promotionBoostPercentage; // Promotion boost percentage

  ItemDetail({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.condition,
    this.category,
    this.imagePaths = const [],
    this.pricePerUnit,
    this.totalPrice,
    this.junkshopPricePerUnit,
    this.junkshopTotalPrice,
    this.promotionBoostPercentage,
  });

  ItemDetail copyWith({
    String? name,
    String? quantity,
    String? unit,
    String? condition,
    String? category,
    List<String>? imagePaths,
    double? pricePerUnit,
    double? totalPrice,
    double? junkshopPricePerUnit,
    double? junkshopTotalPrice,
    double? promotionBoostPercentage,
  }) {
    return ItemDetail(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      condition: condition ?? this.condition,
      category: category ?? this.category,
      imagePaths: imagePaths ?? this.imagePaths,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      totalPrice: totalPrice ?? this.totalPrice,
      junkshopPricePerUnit: junkshopPricePerUnit ?? this.junkshopPricePerUnit,
      junkshopTotalPrice: junkshopTotalPrice ?? this.junkshopTotalPrice,
      promotionBoostPercentage:
          promotionBoostPercentage ?? this.promotionBoostPercentage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'condition': condition,
      'category': category,
      'imagePaths': imagePaths,
      'pricePerUnit': pricePerUnit,
      'totalPrice': totalPrice,
      'junkshopPricePerUnit': junkshopPricePerUnit,
      'junkshopTotalPrice': junkshopTotalPrice,
      'promotionBoostPercentage': promotionBoostPercentage,
    };
  }
}

class CollectorAssignment {
  final String collectorId;
  final String collectorName;
  final String? collectorPhoto;
  final List<NewPickupItem> pickups;
  final double totalEstimatedValue;
  final int pickupCount;

  CollectorAssignment({
    required this.collectorId,
    required this.collectorName,
    this.collectorPhoto,
    required this.pickups,
    required this.totalEstimatedValue,
    required this.pickupCount,
  });
}

abstract class IJunkshopPickupsRepository {
  Future<List<NewPickupItem>> fetchNewPickups();
  Future<List<NewPickupItem>> fetchAssignedPickups();
  Future<List<CollectorAssignment>> fetchAssignedPickupsByCollector();
  Future<List<CollectorAssignment>> fetchCompletedPickupsByCollector();
  Future<List<NewPickupItem>>
  fetchReviewedPurchases(); // Reviewed/approved collections
  Future<Map<String, dynamic>> fetchReviewedPurchasesPaginated({
    required int limit,
    Object? startAfter, // row offset (int) returned as 'lastDoc' by the previous page
  }); // Paginated version
  Future<List<NewPickupItem>> fetchManualPayouts(); // Manual onsite payouts
  Future<List<NewPickupItem>> fetchSales(); // Bulk sales transactions
  Future<Map<String, dynamic>> fetchSalesPaginated({
    required int limit,
    Object? startAfter, // row offset (int) returned as 'lastDoc' by the previous page
  }); // Paginated version
  Future<void> markCollectionAsReviewed(
    String householdId,
    String postingId, {
    required List<ItemDetail> purchasedItems,
    required double junkshopPurchaseTotal,
  });
}

class JunkshopPickupsRepository implements IJunkshopPickupsRepository {
  final SupabaseClient _db;

  JunkshopPickupsRepository({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;

  /// Postings of this junkshop (optionally filtered by status) as legacy-shaped docs.
  Future<List<Map<String, dynamic>>> _fetchPostingDocs(
    String junkshopId,
    List<String> statuses,
  ) async {
    final rows = await _db
        .from('postings')
        .select()
        .eq('junkshop_id', junkshopId)
        .inFilter('status', statuses);
    return rowsToDocs('postings', rows);
  }

  @override
  Future<List<NewPickupItem>> fetchNewPickups() async {
    if (kDebugMode) print('🔍 DEBUG: fetchNewPickups() called - START');
    if (!_supportedPlatform()) return [];

    // Get current junkshop user ID
    final junkshopId = await _getCurrentJunkshopId();
    if (junkshopId == null) {
      if (kDebugMode) print('DEBUG: No junkshop user logged in');
      return [];
    }

    final snapshot = await _fetchPostingDocs(junkshopId, ['pending']);

    final items = snapshot
        .map((data) {
          final docId = data['id'].toString();
          if (kDebugMode) print('🔍 MAPPING: Processing doc $docId');
          // Client-side status filter if needed
          final status = data[PostingFields.status]?.toString();
          if (kDebugMode) print('🔍 MAPPING: $docId status = $status');
          if (status != null && status != 'pending') {
            if (kDebugMode) {
              print('🔍 MAPPING: $docId filtered out - status not pending');
            }
            return null; // filtered out; remove later
          }
          // Client-side junkshop filter - MUST have junkshop.id matching current junkshop
          // Check nested junkshop object first, fallback to legacy assignedJunkshopId
          final junkshopData =
              data[PostingFields.junkshop] as Map<String, dynamic>?;
          final assignedId =
              junkshopData?['id']?.toString() ??
              data[PostingFields.assignedJunkshopId]?.toString();
          if (kDebugMode) {
            print(
              '🔍 MAPPING: $docId assignedId = $assignedId, junkshopId = $junkshopId',
            );
          }
          if (assignedId == null || assignedId != junkshopId) {
            if (kDebugMode) {
              print(
                '🔍 MAPPING: $docId filtered out - not assigned to this junkshop',
              );
            }
            return null; // Not assigned to this junkshop or no assignment
          }
          if (kDebugMode) {
            print('🔍 MAPPING: $docId PASSED all filters, extracting data...');
          }
          final items = <String>[];
          final itemDetails = <ItemDetail>[];
          final imageUrls = <String>[];
          final categories = <String>{}; // Use Set to collect unique categories

          // Extract items from nested structure (items.list) or legacy flat array
          final itemsData = data[PostingFields.items];
          final rawItems = (itemsData is Map<String, dynamic>)
              ? itemsData[PostingFields.itemsList] // Nested: items.list
              : itemsData; // Legacy: direct array

          if (kDebugMode) {
            print('DEBUG fetchNewPickups: Processing posting $docId');
          }
          if (kDebugMode) print('DEBUG fetchNewPickups: rawItems = $rawItems');
          if (rawItems is List) {
            for (final it in rawItems) {
              if (it is Map<String, dynamic>) {
                final name = it[PostingFields.itemName]?.toString() ?? 'Item';
                final category = it[PostingFields.itemCategory]?.toString();
                final qty = it[PostingFields.itemQuantity]?.toString() ?? '';
                final unit = it[PostingFields.itemUnit]?.toString() ?? '';
                final condition =
                    it[PostingFields.itemCondition]?.toString() ?? 'Good';

                items.add(
                  qty.isNotEmpty && unit.isNotEmpty
                      ? '$name ($qty $unit)'
                      : name,
                );

                // Extract image paths for this item
                final itemImagePaths = <String>[];
                final itemImages = it[PostingFields.itemImagePaths];
                if (itemImages is List) {
                  for (final img in itemImages) {
                    if (img is String && img.isNotEmpty) {
                      itemImagePaths.add(img);
                    }
                  }
                }

                // Create ItemDetail object
                itemDetails.add(
                  ItemDetail(
                    name: name,
                    quantity: qty,
                    unit: unit,
                    condition: condition,
                    category: category,
                    imagePaths: itemImagePaths,
                  ),
                );

                // Collect unique categories
                if (category != null && category.isNotEmpty) {
                  categories.add(category);
                }

                // Add to imageUrls list with debug prints
                if (kDebugMode) {
                  print(
                    'DEBUG fetchNewPickups: Item "$name" has imagePaths: $itemImages',
                  );
                }
                if (itemImages is List) {
                  for (final img in itemImages) {
                    if (img is String && img.isNotEmpty) {
                      imageUrls.add(img);
                      if (kDebugMode) {
                        print('DEBUG fetchNewPickups: Added image URL: $img');
                      }
                    }
                  }
                }
              }
            }
          }
          if (kDebugMode) {
            print(
              'DEBUG fetchNewPickups: Total imageUrls collected: ${imageUrls.length}',
            );
          }
          if (kDebugMode) {
            print('DEBUG fetchNewPickups: Categories: $categories');
          }

          // Extract value from nested structure (items.totalEstimatedValue) or legacy
          final valueFromNested = (itemsData is Map<String, dynamic>)
              ? itemsData['totalEstimatedValue']
              : null;
          final value = (valueFromNested is num)
              ? valueFromNested.toDouble()
              : (data[PostingFields.totalEstimatedValue] is num)
              ? (data[PostingFields.totalEstimatedValue] as num).toDouble()
              : 0.0;

          // Extract weight from nested structure (items.estimatedTotalWeight) or legacy
          final weightFromNested = (itemsData is Map<String, dynamic>)
              ? itemsData['estimatedTotalWeight']
              : null;
          final weight = (weightFromNested is num)
              ? weightFromNested.toDouble()
              : (data[PostingFields.estimatedTotalWeight] as num?)?.toDouble();

          final ts = data[PostingFields.createdAt];
          DateTime? created;
          if (ts is Timestamp) created = ts.toDate();

          // Parse unavailable dates (dates household is NOT available)
          List<DateTime>? unavailableDates;
          final unavailableDatesData = data[PostingFields.unavailableDates];
          if (unavailableDatesData is List) {
            unavailableDates = unavailableDatesData
                .whereType<Timestamp>()
                .map((item) => (item).toDate())
                .toList();
          }

          // Parse scheduled date
          DateTime? scheduledDate;
          final scheduledTs = data[PostingFields.scheduledDate];
          if (scheduledTs is Timestamp) {
            scheduledDate = scheduledTs.toDate();
          }

          // Extract household data from nested structure or legacy
          final householdData =
              data[PostingFields.household] as Map<String, dynamic>?;
          final householdId =
              householdData?['id']?.toString() ??
              data[PostingFields.householdId]?.toString() ??
              'Unknown';
          final householdName =
              householdData?['full_name']?.toString() ??
              data[PostingFields.householdName]?.toString();
          final addressShort =
              householdData?['address']?.toString() ??
              data[PostingFields.addressShort]?.toString();
          final profileImageUrl =
              householdData?['profile_image_url']?.toString() ??
              data[PostingFields.profileImageUrl]?.toString();

          return NewPickupItem(
            id: docId,
            householdId: householdId,
            totalValue: value,
            estimatedTotalWeight: weight,
            items: items,
            itemDetails: itemDetails, // Pass populated ItemDetail list
            categories: categories.toList(), // Convert Set to List
            createdAt: created,
            householdName: householdName,
            addressShort: addressShort,
            profileImageUrl: profileImageUrl,
            unavailableDates: unavailableDates,
            scheduledDate: scheduledDate,
            scheduledTime: data[PostingFields.scheduledTime]?.toString(),
            specialInstructions: data[PostingFields.specialInstructions]
                ?.toString(),
            imageUrls: imageUrls,
            assignedJunkshopId: assignedId, // Use the already-extracted ID
          );
        })
        .whereType<NewPickupItem>()
        .toList();

    // Optional: enrich any missing name/address/photo from users collection
    if (kDebugMode) print('🔍 DEBUG: Before enrichment: ${items.length} items');
    for (var item in items) {
      if (kDebugMode) {
        print('🔍   Item ${item.id}: ${item.imageUrls.length} images');
      }
    }
    final enriched = await _enrichFromUserProfiles(items);
    if (kDebugMode) {
      print('🔍 DEBUG: After enrichment: ${enriched.length} items');
    }

    // Client-side sort by createdAt desc
    enriched.sort((a, b) {
      final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    if (kDebugMode) {
      print(
        '🔍 DEBUG: fetchNewPickups() returning ${enriched.length} items - END',
      );
    }
    return enriched;
  }

  @override
  Future<List<NewPickupItem>> fetchAssignedPickups() async {
    if (!_supportedPlatform()) return [];

    // Get current junkshop user ID
    final junkshopId = await _getCurrentJunkshopId();
    if (junkshopId == null) {
      if (kDebugMode) print('DEBUG: No junkshop user logged in');
      return [];
    }

    final snapshot = await _fetchPostingDocs(junkshopId, [
      'assigned',
      'in_transit',
      'arrived',
      'collecting',
    ]);

    final items = snapshot
        .map((data) {
          final docId = data['id'].toString();
          // Client-side status filter if needed
          final status = data['status']?.toString();
          if (kDebugMode) {
            print('DEBUG: Processing posting $docId with status: $status');
          }
          const allowed = {'assigned', 'in_transit', 'arrived', 'collecting'};
          if (status != null && !allowed.contains(status)) {
            return null; // filtered out; remove later
          }
          // Client-side junkshop filter if needed
          // Check nested junkshop object first, fallback to legacy assignedJunkshopId
          final junkshopData =
              data[PostingFields.junkshop] as Map<String, dynamic>?;
          final assignedId =
              junkshopData?['id']?.toString() ??
              data['assignedJunkshopId']?.toString();
          if (assignedId != null && assignedId != junkshopId) {
            if (kDebugMode) {
              print(
                'DEBUG: Filtering out posting $docId - assigned to $assignedId, not $junkshopId',
              );
            }
            return null; // Not assigned to this junkshop
          }
          final items = <String>[];
          final imageUrls = <String>[];
          final categories = <String>{}; // Use Set to collect unique categories

          // Extract items from nested structure (items.list) or legacy flat array
          final itemsData = data['items'];
          final rawItems = (itemsData is Map<String, dynamic>)
              ? itemsData['list'] // Nested: items.list
              : itemsData; // Legacy: direct array

          if (rawItems is List) {
            for (final it in rawItems) {
              if (it is Map<String, dynamic>) {
                final name = it['name']?.toString() ?? 'Item';
                final category = it['category']?.toString();
                final qty = it['quantity']?.toString() ?? '';
                final unit = it['unit']?.toString() ?? '';
                items.add(
                  qty.isNotEmpty && unit.isNotEmpty
                      ? '$name ($qty $unit)'
                      : name,
                );

                // Collect unique categories
                if (category != null && category.isNotEmpty) {
                  categories.add(category);
                }

                // Extract image paths from each item
                final itemImages = it['imagePaths'];
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

          // Extract value from nested structure (items.totalEstimatedValue) or legacy
          final valueFromNested = (itemsData is Map<String, dynamic>)
              ? itemsData['totalEstimatedValue']
              : null;
          final value = (valueFromNested is num)
              ? valueFromNested.toDouble()
              : (data['totalEstimatedValue'] is num)
              ? (data['totalEstimatedValue'] as num).toDouble()
              : 0.0;

          final ts = data['createdAt'];
          DateTime? created;
          if (ts is Timestamp) created = ts.toDate();

          // Parse available dates (household's options)
          // Parse unavailable dates
          List<DateTime>? unavailableDates;
          final unavailableDatesData = data['unavailableDates'];
          if (unavailableDatesData is List) {
            unavailableDates = unavailableDatesData
                .whereType<Timestamp>()
                .map((item) => (item).toDate())
                .toList();
          }

          // Parse scheduled date
          DateTime? scheduledDate;
          final scheduledTs = data['scheduledDate'];
          if (scheduledTs is Timestamp) {
            scheduledDate = scheduledTs.toDate();
          }

          // Parse date of collection (selected by junkshop)
          DateTime? dateOfCollection;
          final collectionTs = data['dateOfCollection'];
          if (collectionTs is Timestamp) {
            dateOfCollection = collectionTs.toDate();
          }

          // Extract household data from nested structure or legacy
          final householdData = data['household'] as Map<String, dynamic>?;
          final householdId =
              householdData?['id']?.toString() ??
              data['householdId']?.toString() ??
              'Unknown';
          final householdName =
              householdData?['full_name']?.toString() ??
              data['householdName']?.toString();
          final addressShort =
              householdData?['address']?.toString() ??
              data['addressShort']?.toString();
          final profileImageUrl =
              householdData?['profile_image_url']?.toString() ??
              data['profileImageUrl']?.toString();

          return NewPickupItem(
            id: docId,
            householdId: householdId,
            totalValue: value,
            items: items,
            categories: categories.toList(), // Convert Set to List
            createdAt: created,
            householdName: householdName,
            addressShort: addressShort,
            profileImageUrl: profileImageUrl,
            unavailableDates: unavailableDates,
            scheduledDate: scheduledDate,
            scheduledTime: data['scheduledTime']?.toString(),
            specialInstructions: data['specialInstructions']?.toString(),
            imageUrls: imageUrls,
            assignedJunkshopId: assignedId, // Use the already-extracted ID
            // Extract collector data from nested structure or legacy
            assignedCollectorId:
                (data['collector'] as Map<String, dynamic>?)?['id']
                    ?.toString() ??
                data['assignedCollectorId']?.toString(),
            assignedCollectorName:
                (data['collector'] as Map<String, dynamic>?)?['full_name']
                    ?.toString() ??
                data['assignedCollectorName']?.toString(),
            assignedCollectorPhoto:
                (data['collector']
                        as Map<String, dynamic>?)?['profile_image_url']
                    ?.toString() ??
                data['assignedCollectorPhoto']?.toString(),
            dateOfCollection: dateOfCollection,
          );
        })
        .whereType<NewPickupItem>()
        .toList();

    if (kDebugMode) {
      print('DEBUG: Mapped ${items.length} assigned pickup items');
    }

    // Optional: enrich any missing name/address/photo from users collection
    final enriched = await _enrichFromUserProfiles(items);

    if (kDebugMode) print('DEBUG: After enrichment: ${enriched.length} items');

    // Client-side sort by createdAt desc
    enriched.sort((a, b) {
      final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    return enriched;
  }

  /// Gets the current logged-in junkshop user ID
  Future<String?> _getCurrentJunkshopId() async {
    return currentUid;
  }

  bool _supportedPlatform() {
    if (kDebugMode) {
      print(
        'DEBUG: Checking platform support. kIsWeb=$kIsWeb, platform=$defaultTargetPlatform',
      );
    }
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
        return true;
      default:
        if (kDebugMode) {
          print('DEBUG: Platform not supported: $defaultTargetPlatform');
        }
        return false;
    }
  }

  Future<List<NewPickupItem>> _enrichFromUserProfiles(
    List<NewPickupItem> items,
  ) async {
    // Determine which householdIds need enrichment
    final need = items.where(
      (it) =>
          it.householdName == null ||
          it.addressShort == null ||
          it.profileImageUrl == null ||
          it.fullAddress == null ||
          it.distanceKm == null,
    );
    final ids = need.map((e) => e.householdId).toSet().toList();
    if (ids.isEmpty) return items;

    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    // Fetch household profiles from the households table
    final Map<String, Map<String, dynamic>> profiles = {};
    final householdIds = ids.where(uuidRe.hasMatch).toList();
    if (householdIds.isNotEmpty) {
      try {
        final rows = await _db
            .from('households')
            .select()
            .inFilter('id', householdIds);
        for (final doc in rowsToDocs('households', rows)) {
          profiles[doc['id'].toString()] = doc;
        }
      } catch (e) {
        if (kDebugMode) print('DEBUG: Error fetching household profiles: $e');
      }
    }

    // Build a map of junkshop locations for distance calculation
    final junkshopIds = items
        .where((it) => it.assignedJunkshopId != null)
        .map((it) => it.assignedJunkshopId!)
        .where(uuidRe.hasMatch)
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> junkshops = {};
    if (junkshopIds.isNotEmpty) {
      try {
        final rows = await _db
            .from('junkshops')
            .select()
            .inFilter('id', junkshopIds);
        for (final doc in rowsToDocs('junkshops', rows)) {
          junkshops[doc['id'].toString()] = doc;
        }
      } catch (e) {
        if (kDebugMode) print('DEBUG: Error fetching junkshop profiles: $e');
      }
    }

    String? shortAddr(Map<String, dynamic>? data) {
      if (data == null) return null;
      final city = data[UserFields.city]?.toString();
      final province = data[UserFields.province]?.toString();
      final address = data[UserFields.address]?.toString();
      if (city != null && city.isNotEmpty) {
        return (province != null && province.isNotEmpty)
            ? '$city, $province'
            : city;
      }
      if (province != null && province.isNotEmpty) return province;
      if (address != null && address.isNotEmpty) return address;
      return null;
    }

    return items.map((it) {
      final data = profiles[it.householdId];
      if (data == null) return it;
      final fullName = (data[UserFields.fullName] ?? data[UserFields.name])
          ?.toString();
      final photo = data[UserFields.profileImageUrl]?.toString();
      final addrShort = shortAddr(data);

      // Extract full address from nested 'location' map (NOT 'note')
      String? fullAddress;
      final locationData = data[UserFields.location];
      if (locationData is Map) {
        // Get address from the location map, not the note
        fullAddress = locationData[UserFields.address]?.toString();
      }

      // Extract household coordinates from nested location map
      double? householdLat;
      double? householdLng;
      if (locationData is Map) {
        householdLat =
            (locationData[UserFields.lat] ?? locationData[UserFields.latitude])
                as double?;
        householdLng =
            (locationData[UserFields.lng] ?? locationData[UserFields.longitude])
                as double?;
      }
      // Fallback to top-level lat/lng if not in location map
      householdLat ??= data[UserFields.latitude] as double?;
      householdLng ??= data[UserFields.longitude] as double?;

      if (kDebugMode) {
        print(
          'DEBUG: Household ${it.householdId} - lat: $householdLat, lng: $householdLng, assignedJunkshop: ${it.assignedJunkshopId}',
        );
      }

      // Calculate distance to the assigned junkshop (not current logged-in junkshop)
      double? distanceKm;
      if (it.assignedJunkshopId != null &&
          householdLat != null &&
          householdLng != null) {
        final junkshopData = junkshops[it.assignedJunkshopId];
        if (junkshopData != null) {
          // Extract junkshop coordinates from nested location map (same as household)
          // But junkshops store data in 'junkshop_profile' field
          double? junkshopLat;
          double? junkshopLng;

          // First check junkshop_profile for location data
          final junkshopProfile = junkshopData[UserFields.junkshopProfile];
          if (junkshopProfile is Map) {
            final junkshopLocation = junkshopProfile[UserFields.location];
            if (junkshopLocation is Map) {
              junkshopLat =
                  (junkshopLocation[UserFields.lat] ??
                          junkshopLocation[UserFields.latitude])
                      as double?;
              junkshopLng =
                  (junkshopLocation[UserFields.lng] ??
                          junkshopLocation[UserFields.longitude])
                      as double?;
              if (kDebugMode) {
                print(
                  'DEBUG: Extracted from junkshop_profile.location - lat: $junkshopLat, lng: $junkshopLng',
                );
              }
            }
            // Fallback to top-level in junkshop_profile
            junkshopLat ??= junkshopProfile[UserFields.latitude] as double?;
            junkshopLng ??= junkshopProfile[UserFields.longitude] as double?;
          }

          // Also check top-level location field
          if (junkshopLat == null || junkshopLng == null) {
            final junkshopLocation = junkshopData[UserFields.location];
            if (junkshopLocation is Map) {
              junkshopLat ??=
                  (junkshopLocation[UserFields.lat] ??
                          junkshopLocation[UserFields.latitude])
                      as double?;
              junkshopLng ??=
                  (junkshopLocation[UserFields.lng] ??
                          junkshopLocation[UserFields.longitude])
                      as double?;
              if (kDebugMode) {
                print(
                  'DEBUG: Extracted from top-level location - lat: $junkshopLat, lng: $junkshopLng',
                );
              }
            }
          }

          // Final fallback to top-level lat/lng
          junkshopLat ??= junkshopData[UserFields.latitude] as double?;
          junkshopLng ??= junkshopData[UserFields.longitude] as double?;
          if (kDebugMode) {
            print(
              'DEBUG: Final junkshop coordinates - lat: $junkshopLat, lng: $junkshopLng',
            );
          }

          if (junkshopLat != null && junkshopLng != null) {
            final distanceMeters = Geolocator.distanceBetween(
              householdLat,
              householdLng,
              junkshopLat,
              junkshopLng,
            );
            distanceKm = distanceMeters / 1000; // Convert to kilometers
            if (kDebugMode) {
              print(
                'DEBUG: Distance from household ${it.householdId} to junkshop ${it.assignedJunkshopId}: ${distanceKm.toStringAsFixed(2)} km',
              );
            }
          } else {
            if (kDebugMode) {
              print(
                'DEBUG: Junkshop coordinates not found for ${it.assignedJunkshopId}',
              );
            }
          }
        } else {
          if (kDebugMode) {
            print(
              'DEBUG: Junkshop data not found for ${it.assignedJunkshopId}',
            );
          }
        }
      } else {
        if (kDebugMode) {
          print(
            'DEBUG: Missing data for distance calculation - assignedJunkshopId: ${it.assignedJunkshopId}, householdLat: $householdLat, householdLng: $householdLng',
          );
        }
      }

      return NewPickupItem(
        id: it.id,
        householdId: it.householdId,
        totalValue: it.totalValue,
        items: it.items,
        categories: it.categories,
        createdAt: it.createdAt,
        householdName: it.householdName ?? fullName,
        addressShort: it.addressShort ?? addrShort,
        fullAddress: it.fullAddress ?? fullAddress,
        householdLat: it.householdLat ?? householdLat,
        householdLng: it.householdLng ?? householdLng,
        distanceKm: it.distanceKm ?? distanceKm,
        profileImageUrl: it.profileImageUrl ?? photo,
        unavailableDates: it.unavailableDates,
        scheduledDate: it.scheduledDate,
        scheduledTime: it.scheduledTime,
        specialInstructions: it.specialInstructions,
        imageUrls: it.imageUrls,
        assignedJunkshopId: it.assignedJunkshopId,
        assignedCollectorId: it.assignedCollectorId,
        assignedCollectorName: it.assignedCollectorName,
        assignedCollectorPhoto: it.assignedCollectorPhoto,
        dateOfCollection: it.dateOfCollection,
      );
    }).toList();
  }

  @override
  Future<List<CollectorAssignment>> fetchAssignedPickupsByCollector() async {
    if (kDebugMode) {
      print('🔍 DEBUG: fetchAssignedPickupsByCollector() called - START');
    }

    // First fetch all assigned pickups
    final pickups = await fetchAssignedPickups();

    if (pickups.isEmpty) {
      if (kDebugMode) print('DEBUG: No assigned pickups found');
      return [];
    }

    // Group pickups by collector
    final Map<String, List<NewPickupItem>> collectorGroups = {};

    for (final pickup in pickups) {
      final collectorId = pickup.assignedCollectorId ?? 'unknown';
      if (!collectorGroups.containsKey(collectorId)) {
        collectorGroups[collectorId] = [];
      }
      collectorGroups[collectorId]!.add(pickup);
    }

    // Create CollectorAssignment objects
    final assignments = <CollectorAssignment>[];

    for (final entry in collectorGroups.entries) {
      final collectorId = entry.key;
      final collectorPickups = entry.value;

      // Get collector info from first pickup
      final firstPickup = collectorPickups.first;
      final collectorName =
          firstPickup.assignedCollectorName ?? 'Unknown Collector';
      final collectorPhoto = firstPickup.assignedCollectorPhoto;

      // Calculate totals
      final totalValue = collectorPickups.fold<double>(
        0.0,
        (acc, pickup) => acc + pickup.totalValue,
      );

      assignments.add(
        CollectorAssignment(
          collectorId: collectorId,
          collectorName: collectorName,
          collectorPhoto: collectorPhoto,
          pickups: collectorPickups,
          totalEstimatedValue: totalValue,
          pickupCount: collectorPickups.length,
        ),
      );
    }

    // Sort by pickup count (descending) and then by total value
    assignments.sort((a, b) {
      final countCompare = b.pickupCount.compareTo(a.pickupCount);
      if (countCompare != 0) return countCompare;
      return b.totalEstimatedValue.compareTo(a.totalEstimatedValue);
    });

    if (kDebugMode) {
      print('DEBUG: Created ${assignments.length} collector assignments');
    }

    return assignments;
  }

  @override
  Future<List<CollectorAssignment>> fetchCompletedPickupsByCollector() async {
    if (kDebugMode) {
      print('🔍 DEBUG: fetchCompletedPickupsByCollector() called - START');
    }

    // Fetch all completed pickups
    final pickups = await _fetchCompletedPickups();

    if (pickups.isEmpty) {
      if (kDebugMode) print('DEBUG: No completed pickups found');
      return [];
    }

    // Group pickups by collector
    final Map<String, List<NewPickupItem>> collectorGroups = {};

    for (final pickup in pickups) {
      final collectorId = pickup.assignedCollectorId ?? 'unknown';
      if (!collectorGroups.containsKey(collectorId)) {
        collectorGroups[collectorId] = [];
      }
      collectorGroups[collectorId]!.add(pickup);
    }

    // Create CollectorAssignment objects
    final assignments = <CollectorAssignment>[];

    for (final entry in collectorGroups.entries) {
      final collectorId = entry.key;
      final collectorPickups = entry.value;

      // Get collector info from first pickup
      final firstPickup = collectorPickups.first;
      final collectorName =
          firstPickup.assignedCollectorName ?? 'Unknown Collector';
      final collectorPhoto = firstPickup.assignedCollectorPhoto;

      // Calculate totals
      final totalValue = collectorPickups.fold<double>(
        0.0,
        (acc, pickup) => acc + pickup.totalValue,
      );

      assignments.add(
        CollectorAssignment(
          collectorId: collectorId,
          collectorName: collectorName,
          collectorPhoto: collectorPhoto,
          pickups: collectorPickups,
          totalEstimatedValue: totalValue,
          pickupCount: collectorPickups.length,
        ),
      );
    }

    // Sort by pickup count (descending) and then by total value
    assignments.sort((a, b) {
      final countCompare = b.pickupCount.compareTo(a.pickupCount);
      if (countCompare != 0) return countCompare;
      return b.totalEstimatedValue.compareTo(a.totalEstimatedValue);
    });

    if (kDebugMode) {
      print(
        'DEBUG: Created ${assignments.length} completed collector assignments',
      );
    }

    return assignments;
  }

  Future<List<NewPickupItem>> _fetchCompletedPickups() async {
    if (!_supportedPlatform()) return [];

    // Get current junkshop user ID
    final junkshopId = await _getCurrentJunkshopId();
    if (junkshopId == null) {
      if (kDebugMode) print('DEBUG: No junkshop user logged in');
      return [];
    }
    if (kDebugMode) {
      print('DEBUG _fetchCompletedPickups: Current junkshop ID = $junkshopId');
    }

    final snapshot = await _fetchPostingDocs(junkshopId, ['completed']);

    final items = snapshot
        .map((data) {
          final docId = data['id'].toString();

          // Client-side status filter
          final status = data['status']?.toString();
          if (status != 'completed') {
            if (kDebugMode) {
              print(
                'DEBUG: Filtering out doc $docId - status=$status (not completed)',
              );
            }
            return null; // filtered out
          }
          // Client-side junkshop filter - check nested structure first
          final junkshopData = data['junkshop'] as Map<String, dynamic>?;
          final assignedId =
              junkshopData?['id']?.toString() ??
              data['assignedJunkshopId']?.toString();

          if (kDebugMode) {
            print('DEBUG: Doc $docId junkshop data: $junkshopData');
          }
          if (kDebugMode) {
            print(
              'DEBUG: Doc $docId assignedJunkshopId: ${data['assignedJunkshopId']}',
            );
          }
          if (kDebugMode) {
            print('DEBUG: Doc $docId all keys: ${data.keys.toList()}');
          }

          if (assignedId != junkshopId) {
            if (kDebugMode) {
              print(
                'DEBUG: Filtering out doc $docId - junkshop.id=$assignedId (expected $junkshopId)',
              );
            }
            return null; // Not assigned to this junkshop
          }

          if (kDebugMode) {
            print(
              'DEBUG: Processing completed posting $docId for junkshop $junkshopId',
            );
          }

          final items = <String>[];
          final itemDetails = <ItemDetail>[];
          final imageUrls = <String>[];
          final categories = <String>{}; // Use Set to collect unique categories

          // Prioritize purchasedItems.list (junkshop's pricing), then verifiedItems (collector's collection)
          final purchasedItemsData = data['purchasedItems'];
          final verifiedItemsData = data['verifiedItems'];
          final itemsData = data['items']; // Keep for legacy value extraction
          List itemsArray = [];

          if (purchasedItemsData is Map && purchasedItemsData['list'] is List) {
            // Preferred: purchasedItems structure with junkshop pricing
            itemsArray = purchasedItemsData['list'] as List;
          } else if (purchasedItemsData is List) {
            // Fallback if purchasedItems is directly a list
            itemsArray = purchasedItemsData;
          } else if (verifiedItemsData is Map &&
              verifiedItemsData['items'] is List) {
            // Fallback: verifiedItems with collector pricing
            itemsArray = verifiedItemsData['items'] as List;
          } else if (verifiedItemsData is List) {
            // Old structure: verifiedItems is directly an array (backward compatibility)
            itemsArray = verifiedItemsData;
          } else {
            // Fallback to original items
            itemsArray = itemsData is List ? itemsData : [];
          }

          if (itemsArray.isNotEmpty) {
            for (final it in itemsArray) {
              if (it is Map<String, dynamic>) {
                final name =
                    it['name']?.toString() ?? it['type']?.toString() ?? 'Item';
                final category = it['category']?.toString();
                final qty = it['quantity']?.toString() ?? '';
                final unit = it['unit']?.toString() ?? '';
                final condition = it['condition']?.toString() ?? '';

                // Extract pricing
                final junkshopPricePerUnit =
                    (it['junkshopPricePerUnit'] as num?)?.toDouble();
                final junkshopTotalPrice = (it['junkshopTotalPrice'] as num?)
                    ?.toDouble();
                final collectorPricePerUnit = (it['pricePerUnit'] as num?)
                    ?.toDouble();
                final collectorTotalPrice =
                    (it['totalPrice'] as num?)?.toDouble() ??
                    (it['price'] as num?)?.toDouble();

                // Determine display price (prioritize junkshop)
                final pricePerUnit =
                    junkshopPricePerUnit ?? collectorPricePerUnit;
                final totalPrice = junkshopTotalPrice ?? collectorTotalPrice;

                // Extract promotion boost percentage
                final promotionBoostPercentage =
                    (it['promotionBoostPercentage'] as num?)?.toDouble();

                items.add(
                  qty.isNotEmpty && unit.isNotEmpty
                      ? '$name ($qty $unit)'
                      : name,
                );

                // Collect unique categories
                if (category != null && category.isNotEmpty) {
                  categories.add(category);
                }

                // Extract image paths for this item
                final itemImages = <String>[];
                final itemImagePaths = it['imagePaths'];
                if (itemImagePaths is List) {
                  for (final img in itemImagePaths) {
                    if (img is String && img.isNotEmpty) {
                      imageUrls.add(img);
                      itemImages.add(img);
                    }
                  }
                }

                // Add detailed item info with pricing
                itemDetails.add(
                  ItemDetail(
                    name: name,
                    quantity: qty,
                    unit: unit,
                    condition: condition,
                    category: category,
                    imagePaths: itemImages,
                    pricePerUnit: pricePerUnit,
                    totalPrice: totalPrice,
                    junkshopPricePerUnit: junkshopPricePerUnit,
                    junkshopTotalPrice: junkshopTotalPrice,
                    promotionBoostPercentage: promotionBoostPercentage,
                  ),
                );
              }
            }
          }

          // Extract proof photos from collector
          final proofPhotos = <String, List<String>>{};
          final paymentProofUrls = <String>[];
          final rawPhotos = data['photos'];
          if (rawPhotos is Map<String, dynamic>) {
            for (final category in ['arrival', 'collection', 'before_after']) {
              final categoryPhotos = rawPhotos[category];
              if (categoryPhotos is List) {
                proofPhotos[category] = categoryPhotos
                    .map((e) => e.toString())
                    .where((s) => s.isNotEmpty)
                    .toList();
              }
            }

            // Extract payment proof from photos.payment
            final paymentPhotos = rawPhotos['payment'];
            if (paymentPhotos is List) {
              paymentProofUrls.addAll(
                paymentPhotos
                    .map((e) => e.toString())
                    .where((s) => s.isNotEmpty)
                    .toList(),
              );
            }
          }

          // Extract value from nested structure (items.totalEstimatedValue) or legacy
          final valueFromNested = (itemsData is Map<String, dynamic>)
              ? itemsData['totalEstimatedValue']
              : null;
          final value = (valueFromNested is num)
              ? valueFromNested.toDouble()
              : (data['totalEstimatedValue'] is num)
              ? (data['totalEstimatedValue'] as num).toDouble()
              : 0.0;

          final ts = data['createdAt'];
          DateTime? created;
          if (ts is Timestamp) created = ts.toDate();

          // Extract household ID from nested structure or document path
          final householdData = data['household'] as Map<String, dynamic>?;
          final householdId =
              householdData?['id']?.toString() ??
              data['householdId']?.toString() ??
              'unknown';
          final householdName =
              householdData?['full_name']?.toString() ??
              data['householdName']?.toString();
          final addressShort =
              householdData?['address']?.toString() ??
              data['addressShort']?.toString();
          final profileImageUrl =
              householdData?['profile_image_url']?.toString() ??
              data['profileImageUrl']?.toString();

          // Extract reviewedAt timestamp
          final reviewedTs = data['reviewedAt'];
          DateTime? reviewedAt;
          if (reviewedTs is Timestamp) reviewedAt = reviewedTs.toDate();

          // For completed pickups, prioritize purchasedItems.total (what junkshop paid), then verifiedItems.totalValue (collector's valuation)
          double actualTotalValue = value; // Default to estimated value

          // First, try purchasedItems.total (what junkshop actually paid to collector)
          if (data['purchasedItems'] is Map) {
            final purchasedItems =
                data['purchasedItems'] as Map<String, dynamic>;
            final purchasedTotal = (purchasedItems['total'] as num?)
                ?.toDouble();
            if (purchasedTotal != null && purchasedTotal > 0) {
              actualTotalValue = purchasedTotal;
              if (kDebugMode) {
                print(
                  'DEBUG: Using purchasedItems.total (junkshop payment): $actualTotalValue',
                );
              }
            }
          }

          // Fallback: Use totalValue from nested verifiedItems structure (collector's valuation)
          if (actualTotalValue == value && verifiedItemsData is Map) {
            final totalValue = (verifiedItemsData['totalValue'] as num?)
                ?.toDouble();
            if (totalValue != null && totalValue > 0) {
              actualTotalValue = totalValue;
              if (kDebugMode) {
                print(
                  'DEBUG: Using verifiedItems.totalValue (collector valuation): $actualTotalValue',
                );
              }
            }
          } else if (actualTotalValue == value) {
            // Backward compatibility: check for old totalVerifiedValue field
            final totalVerifiedValue = (data['totalVerifiedValue'] as num?)
                ?.toDouble();
            if (totalVerifiedValue != null && totalVerifiedValue > 0) {
              actualTotalValue = totalVerifiedValue;
              if (kDebugMode) {
                print(
                  'DEBUG: Using legacy totalVerifiedValue: $actualTotalValue',
                );
              }
            }
          }

          // If no total from purchasedItems or verifiedItems, calculate from itemDetails
          if (actualTotalValue == value && itemDetails.isNotEmpty) {
            actualTotalValue = itemDetails.fold<double>(
              0.0,
              (acc, item) => acc + (item.totalPrice ?? 0.0),
            );
            if (kDebugMode) {
              print(
                'DEBUG: Calculated total from itemDetails: $actualTotalValue (was $value)',
              );
            }
          }

          return NewPickupItem(
            id: docId,
            householdId: householdId,
            totalValue:
                actualTotalValue, // Use calculated total from itemDetails
            items: items,
            categories: categories.toList(), // Convert Set to List
            itemDetails: itemDetails,
            createdAt: created,
            householdName: householdName,
            addressShort: addressShort,
            profileImageUrl: profileImageUrl,
            imageUrls: imageUrls,
            assignedJunkshopId: assignedId, // Use the already-extracted ID
            // Extract collector data from nested structure or legacy
            assignedCollectorId:
                (data['collector'] as Map<String, dynamic>?)?['id']
                    ?.toString() ??
                data['assignedCollectorId']?.toString(),
            assignedCollectorName:
                (data['collector'] as Map<String, dynamic>?)?['full_name']
                    ?.toString() ??
                data['assignedCollectorName']?.toString(),
            assignedCollectorPhoto:
                (data['collector']
                        as Map<String, dynamic>?)?['profile_image_url']
                    ?.toString() ??
                data['assignedCollectorPhoto']?.toString(),
            proofPhotos: proofPhotos,
            paymentProofUrls: paymentProofUrls,
            reviewedAt: reviewedAt,
            isReviewed: data['isReviewed'] as bool?,
          );
        })
        .whereType<NewPickupItem>()
        .toList();

    if (kDebugMode) print('DEBUG: Returning ${items.length} completed pickups');
    return items;
  }

  /// Maps a reviewed (paid) posting doc to a [NewPickupItem].
  NewPickupItem _reviewedDocToItem(Map<String, dynamic> data, String junkshopId) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : toDateTime(v);

    final categories = <String>{};
    final itemsList = <String>[];
    final itemDetails = <ItemDetail>[];

    // purchasedItems is {list: [...], total, purchasedAt}; tolerate a bare list.
    final purchasedRaw = data['purchasedItems'];
    final purchasedList = purchasedRaw is Map
        ? purchasedRaw['list']
        : purchasedRaw;
    if (purchasedList is List) {
      for (final item in purchasedList) {
        if (item is Map) {
          final name = item['name']?.toString() ?? 'Unknown Item';
          final category = item['category']?.toString();
          final quantity = item['quantity']?.toString() ?? '0';
          final unit = item['unit']?.toString() ?? 'pcs';
          final condition = item['condition']?.toString() ?? '';

          if (category != null && category.isNotEmpty) {
            categories.add(category);
          }
          itemsList.add('$name ($quantity $unit)');

          final junkshopPricePerUnit =
              (item['junkshopPricePerUnit'] as num?)?.toDouble();
          final junkshopTotalPrice = (item['junkshopTotalPrice'] as num?)
              ?.toDouble();
          final pricePerUnit = (item['pricePerUnit'] as num?)?.toDouble();
          final totalPrice = (item['totalPrice'] as num?)?.toDouble();

          final itemImages = <String>[];
          final itemImagePaths = item['imagePaths'];
          if (itemImagePaths is List) {
            for (final img in itemImagePaths) {
              if (img is String && img.isNotEmpty) itemImages.add(img);
            }
          }

          itemDetails.add(
            ItemDetail(
              name: name,
              quantity: quantity,
              unit: unit,
              condition: condition,
              category: category,
              imagePaths: itemImages,
              pricePerUnit: junkshopPricePerUnit ?? pricePerUnit,
              totalPrice: junkshopTotalPrice ?? totalPrice,
              junkshopPricePerUnit: junkshopPricePerUnit,
              junkshopTotalPrice: junkshopTotalPrice,
            ),
          );
        }
      }
    }

    final householdData = data['household'] as Map<String, dynamic>?;
    final collectorData = data['collector'] as Map<String, dynamic>?;
    final locationData = data['location'] as Map<String, dynamic>?;

    return NewPickupItem(
      id: data['id'].toString(),
      householdId: data['householdId']?.toString() ?? '',
      totalValue:
          (data['totalJunkshopCost'] as num?)?.toDouble() ??
          (purchasedRaw is Map
              ? (purchasedRaw['total'] as num?)?.toDouble()
              : null) ??
          0.0,
      items: itemsList,
      categories: categories.toList(),
      itemDetails: itemDetails,
      householdName: householdData?['full_name']?.toString() ?? 'Unknown',
      addressShort: locationData?['address']?.toString(),
      profileImageUrl: householdData?['profile_image_url']?.toString(),
      createdAt: ts(data['createdAt']),
      reviewedAt: ts(data['reviewedAt']),
      unavailableDates: <DateTime>[],
      scheduledDate: ts(data['scheduledDate']),
      scheduledTime: data['scheduledTime']?.toString(),
      specialInstructions: data['specialInstructions']?.toString(),
      imageUrls: <String>[],
      assignedJunkshopId: junkshopId,
      assignedCollectorId: collectorData?['id']?.toString() ??
          data['collectorId']?.toString(),
      assignedCollectorName: collectorData?['full_name']?.toString(),
      assignedCollectorPhoto: collectorData?['profile_image_url']?.toString(),
      dateOfCollection: ts(data['dateOfCollection']),
      status: data['status']?.toString(),
      isReviewed: data['isReviewed'] == true,
    );
  }

  /// Fetch reviewed/approved collections (purchases) for history screen
  @override
  Future<List<NewPickupItem>> fetchReviewedPurchases() async {
    if (!_supportedPlatform()) return [];

    final junkshopId = await _getCurrentJunkshopId();
    if (junkshopId == null) {
      if (kDebugMode) print('DEBUG: No junkshop user logged in');
      return [];
    }

    try {
      final rows = await _db
          .from('postings')
          .select()
          .eq('junkshop_id', junkshopId)
          .eq('status', 'completed')
          .eq('is_reviewed', true)
          .order('reviewed_at', ascending: false)
          .limit(200);

      final items = rowsToDocs('postings', rows)
          .map((doc) => _reviewedDocToItem(doc, junkshopId))
          .toList();

      // Sort by reviewedAt descending (newest first)
      items.sort((a, b) {
        if (a.reviewedAt == null && b.reviewedAt == null) return 0;
        if (a.reviewedAt == null) return 1;
        if (b.reviewedAt == null) return -1;
        return b.reviewedAt!.compareTo(a.reviewedAt!);
      });

      return items;
    } catch (e) {
      if (kDebugMode) print('ERROR fetching reviewed purchases: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> fetchReviewedPurchasesPaginated({
    required int limit,
    Object? startAfter, // row offset (int) returned as 'lastDoc' by the previous page
  }) async {
    if (!_supportedPlatform()) {
      return {'items': <NewPickupItem>[], 'lastDoc': null};
    }

    final junkshopId = await _getCurrentJunkshopId();
    if (junkshopId == null) {
      return {'items': <NewPickupItem>[], 'lastDoc': null};
    }

    try {
      final offset = startAfter is int ? startAfter : 0;
      final rows = await _db
          .from('postings')
          .select()
          .eq('junkshop_id', junkshopId)
          .eq('status', 'completed')
          .eq('is_reviewed', true)
          .order('reviewed_at', ascending: false)
          .range(offset, offset + limit - 1);

      final items = rowsToDocs('postings', rows)
          .map((doc) => _reviewedDocToItem(doc, junkshopId))
          .toList();

      return {'items': items, 'lastDoc': rows.isNotEmpty ? offset + rows.length : null};
    } catch (e) {
      if (kDebugMode) print('ERROR fetching paginated reviewed purchases: $e');
      return {'items': <NewPickupItem>[], 'lastDoc': null};
    }
  }

  /// Fetch manual payout purchases for history screen
  @override
  Future<List<NewPickupItem>> fetchManualPayouts() async {
    if (kDebugMode) print('🔍 DEBUG: fetchManualPayouts() called - START');
    if (!_supportedPlatform()) return [];

    // Get current junkshop user ID
    final junkshopId = await _getCurrentJunkshopId();
    if (junkshopId == null) {
      if (kDebugMode) print('DEBUG: No junkshop user logged in');
      return [];
    }

    if (kDebugMode) print('DEBUG: Current junkshop ID = $junkshopId');

    try {
      // Query Purchase collection for manual onsite payouts
      final purchaseRows = await _db
          .from('purchases')
          .select()
          .eq('junkshop_id', junkshopId)
          .eq('type', 'manual_onsite')
          .order('created_at', ascending: false);
      final querySnapshot = rowsToDocs('purchases', purchaseRows);

      if (kDebugMode) {
        print(
          'DEBUG: Fetched ${querySnapshot.length} manual payouts',
        );
      }

      final items = querySnapshot.map((data) {

        final createdTs = data['createdAt'];
        DateTime? createdAt;
        if (createdTs is Timestamp) createdAt = createdTs.toDate();

        final itemsData = data['items'] as List<dynamic>? ?? [];

        // Create readable item strings
        final purchasedItems = itemsData.map((item) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString() ?? 'Unknown Item';
            final quantity = item['quantity']?.toString() ?? '0';
            final unit = item['unit']?.toString() ?? 'pcs';
            return '$name ($quantity $unit)';
          }
          return item.toString();
        }).toList();

        // Create itemDetails with price information
        final itemDetails = itemsData.map((item) {
          if (item is Map<String, dynamic>) {
            final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            // Read pricePerUnit and subtotal directly from Firestore
            final pricePerUnit =
                (item['pricePerUnit'] as num?)?.toDouble() ??
                (item['price'] as num?)?.toDouble();
            final totalPrice =
                (item['subtotal'] as num?)?.toDouble() ??
                (item['totalPrice'] as num?)?.toDouble() ??
                (item['price'] as num?)?.toDouble();

            return ItemDetail(
              name: item['name']?.toString() ?? 'Unknown',
              quantity: qty.toString(),
              unit: item['unit']?.toString() ?? 'pcs',
              condition: 'good',
              pricePerUnit: pricePerUnit,
              totalPrice: totalPrice,
            );
          }
          return ItemDetail(
            name: 'Unknown',
            quantity: '0',
            unit: 'pcs',
            condition: 'Unknown',
            imagePaths: [],
          );
        }).toList();

        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

        return NewPickupItem(
          id: data['id'].toString(),
          householdId: 'manual_payout', // Identifier for manual payouts
          totalValue: totalAmount,
          items: purchasedItems,
          categories: ['Onsite Purchase'],
          itemDetails: itemDetails,
          householdName: data['customer_name']
              ?.toString(), // Customer name from form
          addressShort: null, // No address for onsite
          profileImageUrl: null,
          createdAt: createdAt,
          reviewedAt: createdAt, // Use createdAt for sorting
          unavailableDates: [],
          scheduledDate: null,
          scheduledTime: null,
          specialInstructions: data['notes']?.toString().isNotEmpty == true
              ? data['notes']?.toString()
              : null,
          imageUrls: [],
          assignedJunkshopId: null, // No assignment for manual
          assignedCollectorId: null, // No collector involved
          assignedCollectorName: null,
          assignedCollectorPhoto: null,
          dateOfCollection: null, // No collection, onsite transaction
        );
      }).toList();

      if (kDebugMode) {
        print('DEBUG: Converted to ${items.length} manual payout items');
      }
      return items;
    } catch (e) {
      if (kDebugMode) print('ERROR fetching manual payouts: $e');
      return [];
    }
  }

  @override
  Future<List<NewPickupItem>> fetchSales() async {
    if (kDebugMode) print('🔍 DEBUG: fetchSales() called - START');
    if (!_supportedPlatform()) return [];

    // Get current junkshop user ID
    final junkshopId = await _getCurrentJunkshopId();
    if (junkshopId == null) {
      if (kDebugMode) print('DEBUG: No junkshop user logged in');
      return [];
    }

    if (kDebugMode) print('DEBUG: Current junkshop ID = $junkshopId');

    try {
      // Query Sales collection for bulk sale transactions
      final salesRows = await _db
          .from('sales')
          .select()
          .eq('junkshop_id', junkshopId)
          .order('created_at', ascending: false);
      final querySnapshot = rowsToDocs('sales', salesRows);

      if (kDebugMode) {
        print(
          'DEBUG: Fetched ${querySnapshot.length} sales',
        );
      }

      final items = querySnapshot.map((data) {

        final createdTs = data['createdAt'];
        DateTime? createdAt;
        if (createdTs is Timestamp) createdAt = createdTs.toDate();

        final itemsData = data['items'] as List<dynamic>? ?? [];

        // Create readable item strings
        final soldItems = itemsData.map((item) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString() ?? 'Unknown Item';
            final quantity = item['quantity']?.toString() ?? '0';
            final unit = item['unit']?.toString() ?? 'pcs';
            return '$name ($quantity $unit)';
          }
          return item.toString();
        }).toList();

        // Create itemDetails with price information
        final itemDetails = itemsData.map((item) {
          if (item is Map<String, dynamic>) {
            final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            // Read pricePerUnit and subtotal directly from Firestore
            final pricePerUnit =
                (item['pricePerUnit'] as num?)?.toDouble() ??
                (item['price'] as num?)?.toDouble();
            final totalPrice =
                (item['subtotal'] as num?)?.toDouble() ??
                (item['totalPrice'] as num?)?.toDouble() ??
                (item['price'] as num?)?.toDouble();

            return ItemDetail(
              name: item['name']?.toString() ?? 'Unknown',
              quantity: qty.toString(),
              unit: item['unit']?.toString() ?? 'pcs',
              condition: 'good',
              pricePerUnit: pricePerUnit,
              totalPrice: totalPrice,
            );
          }
          return ItemDetail(
            name: 'Unknown',
            quantity: '0',
            unit: 'pcs',
            condition: 'Unknown',
            imagePaths: [],
          );
        }).toList();

        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final buyer = data['buyer']?.toString();

        return NewPickupItem(
          id: data['id'].toString(),
          householdId: 'bulk_sale', // Identifier for sales
          totalValue: totalAmount,
          items: soldItems,
          categories: ['Bulk Sale'],
          itemDetails: itemDetails,
          householdName: buyer, // Use buyer name in householdName field
          addressShort: null,
          profileImageUrl: null,
          createdAt: createdAt,
          reviewedAt: createdAt, // Use createdAt for sorting
          unavailableDates: [],
          scheduledDate: null,
          scheduledTime: null,
          specialInstructions: null,
          imageUrls: [],
          assignedJunkshopId: null,
          assignedCollectorId: null,
          assignedCollectorName: null,
          assignedCollectorPhoto: null,
          dateOfCollection: null,
        );
      }).toList();

      if (kDebugMode) print('DEBUG: Converted to ${items.length} sale items');
      return items;
    } catch (e) {
      if (kDebugMode) print('ERROR fetching sales: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> fetchSalesPaginated({
    required int limit,
    Object? startAfter, // row offset (int) returned as 'lastDoc' by the previous page
  }) async {
    if (kDebugMode) {
      print(
        '🔍 DEBUG: fetchSalesPaginated() - limit: $limit, hasStartAfter: ${startAfter != null}',
      );
    }
    if (!_supportedPlatform()) {
      return {'items': <NewPickupItem>[], 'lastDoc': null};
    }

    final junkshopId = await _getCurrentJunkshopId();
    if (junkshopId == null) {
      if (kDebugMode) print('DEBUG: No junkshop user logged in');
      return {'items': <NewPickupItem>[], 'lastDoc': null};
    }

    try {
      final offset = startAfter is int ? startAfter : 0;
      final salesRows = await _db
          .from('sales')
          .select()
          .eq('junkshop_id', junkshopId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final querySnapshot = rowsToDocs('sales', salesRows);
      if (kDebugMode) {
        print('DEBUG: Fetched ${querySnapshot.length} sales (paginated)');
      }

      final items = querySnapshot.map((data) {

        final createdTs = data['createdAt'];
        DateTime? createdAt;
        if (createdTs is Timestamp) createdAt = createdTs.toDate();

        final soldItems = <String>[];
        final itemDetails = <ItemDetail>[];

        final itemsData = data['items'] as List<dynamic>? ?? [];

        for (final item in itemsData) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString() ?? 'Unknown Item';
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            final unit = item['unit']?.toString() ?? 'pcs';
            final pricePerUnit =
                (item['pricePerUnit'] as num?)?.toDouble() ??
                (item['price'] as num?)?.toDouble();
            final totalPrice =
                (item['subtotal'] as num?)?.toDouble() ??
                (item['totalPrice'] as num?)?.toDouble() ??
                (item['price'] as num?)?.toDouble();

            soldItems.add('$name ($quantity $unit)');

            itemDetails.add(
              ItemDetail(
                name: name,
                quantity: quantity.toString(),
                unit: unit,
                condition: 'good',
                category: 'Bulk Sale',
                pricePerUnit: pricePerUnit,
                totalPrice: totalPrice,
              ),
            );
          }
        }

        final totalAmount = (data['totalAmount'] is num)
            ? (data['totalAmount'] as num).toDouble()
            : 0.0;
        final buyer = data['buyer']?.toString() ?? 'Unknown Buyer';

        return NewPickupItem(
          id: data['id'].toString(),
          householdId: 'bulk_sale',
          totalValue: totalAmount,
          items: soldItems,
          categories: ['Bulk Sale'],
          itemDetails: itemDetails,
          householdName: buyer,
          addressShort: null,
          profileImageUrl: null,
          createdAt: createdAt,
          reviewedAt: createdAt,
          unavailableDates: [],
          scheduledDate: null,
          scheduledTime: null,
          specialInstructions: null,
          imageUrls: [],
          assignedJunkshopId: null,
          assignedCollectorId: null,
          assignedCollectorName: null,
          assignedCollectorPhoto: null,
          dateOfCollection: null,
        );
      }).toList();

      return {
        'items': items,
        'lastDoc': querySnapshot.isNotEmpty ? offset + querySnapshot.length : null,
      };
    } catch (e) {
      if (kDebugMode) print('ERROR fetching paginated sales: $e');
      return {'items': <NewPickupItem>[], 'lastDoc': null};
    }
  }

  /// Mark a completed collection as reviewed by junkshop
  @override
  Future<void> markCollectionAsReviewed(
    String householdId,
    String postingId, {
    required List<ItemDetail> purchasedItems,
    required double junkshopPurchaseTotal,
  }) async {
    try {
      if (kDebugMode) print('✅ Marking collection as reviewed:');
      if (kDebugMode) print('   Household ID: $householdId');
      if (kDebugMode) print('   Posting ID: $postingId');
      if (kDebugMode) {
        print('   Purchased Items Count: ${purchasedItems.length}');
      }
      if (kDebugMode) {
        print('   Junkshop Purchase Total: ₱$junkshopPurchaseTotal');
      }

      final row = await _db
          .from('postings')
          .select()
          .eq('id', postingId)
          .maybeSingle();
      if (row == null) {
        if (kDebugMode) print('Warning: posting does not exist!');
        throw Exception('Posting not found');
      }

      final data = rowToDoc('postings', row);
      final junkshopData = data['junkshop'] as Map<String, dynamic>?;
      final junkshopId =
          row['junkshop_id']?.toString() ?? junkshopData?['id']?.toString();
      final householdData = data['household'] as Map<String, dynamic>?;
      final collectorData = data['collector'] as Map<String, dynamic>?;

      // Convert purchasedItems to JSON
      final purchasedItemsJson = purchasedItems
          .map((item) => item.toJson())
          .toList();

      final collectorPaid =
          ((data['verifiedItems'] as Map?)?['totalValue'] as num?)
              ?.toDouble() ??
          0.0;

      // Mark completed + reviewed, store purchased items and set the 30-day rating deadline
      final now = DateTime.now().toUtc();
      final ratingDeadline = now.add(const Duration(days: 30));
      await _db.from('postings').update({
        'status': 'completed',
        'is_reviewed': true,
        'rating_deadline': ratingDeadline.toIso8601String(),
        'is_rated': false,
        'purchased_items': {
          'list': purchasedItemsJson,
          'total': junkshopPurchaseTotal,
          'purchasedAt': now.toIso8601String(),
        },
        'total_collector_paid': collectorPaid,
        'total_junkshop_cost': junkshopPurchaseTotal,
        'profit': junkshopPurchaseTotal - collectorPaid,
      }).eq('id', postingId);

      if (kDebugMode) {
        print('Successfully marked posting $postingId as reviewed');
      }

      // Delete the active_collections row since the collection is now completed
      try {
        await _db.from('active_collections').delete().eq('posting_id', postingId);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to delete active_collections (may not exist): $e');
        }
      }

      // Log activity
      if (junkshopId != null) {
        try {
          final householdName = householdData?['full_name'] ?? 'Customer';
          final collectorName = collectorData?['full_name'] ?? 'Collector';

          await _db.from('activity_logs').insert({
            'junkshop_id': junkshopId,
            'type': 'collection_completed',
            'title':
                '$collectorName completed pickup from $householdName - ₱${junkshopPurchaseTotal.toStringAsFixed(2)}',
            'details': {
              'postingId': postingId,
              'householdId': householdId,
              'householdName': householdName,
              'collectorId': collectorData?['id'],
              'collectorName': collectorName,
              'totalAmount': junkshopPurchaseTotal,
              'itemsCount': purchasedItems.length,
            },
          });
        } catch (e) {
          if (kDebugMode) print('Failed to log activity: $e');
          // Don't fail the review if logging fails
        }
      }

      // Update junkshop inventory stock with purchased items
      if (junkshopId != null) {
        await _updateInventoryStock(junkshopId, purchasedItems);
      } else {
        if (kDebugMode) {
          print('No junkshop ID found, skipping inventory update');
        }
      }
    } catch (e) {
      if (kDebugMode) print('ERROR marking collection as reviewed: $e');
      rethrow;
    }
  }

  /// Update junkshop inventory stock based on purchased items from collector
  Future<void> _updateInventoryStock(
    String junkshopId,
    List<ItemDetail> purchasedItems,
  ) async {
    try {
      if (purchasedItems.isEmpty) return;

      // Group items by material name and sum quantities + costs
      final itemQuantities = <String, double>{};
      final itemCosts = <String, double>{};

      for (final item in purchasedItems) {
        final name = item.name;
        final quantity = double.tryParse(item.quantity) ?? 0.0;
        final totalPrice = item.totalPrice ?? 0.0;

        if (name.isNotEmpty && quantity > 0) {
          itemQuantities[name] = (itemQuantities[name] ?? 0.0) + quantity;
          itemCosts[name] = (itemCosts[name] ?? 0.0) + totalPrice;
        }
      }

      if (itemQuantities.isEmpty) return;

      // All materials of the junkshop (include inactive to ensure matching)
      final materialRows = await _db
          .from('junkshop_materials')
          .select()
          .eq('junkshop_id', junkshopId);

      // Case-insensitive, normalized index of materials by name
      String norm(String s) {
        return s.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
      }

      String singularize(String s) {
        if (s.endsWith('s') && s.length > 1) {
          return s.substring(0, s.length - 1);
        }
        return s;
      }

      final materialsByName = <String, Map<String, dynamic>>{};
      for (final m in materialRows) {
        final name = (m['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        final n = norm(name);
        materialsByName[n] = m;
        materialsByName.putIfAbsent(singularize(n), () => m);
      }

      int updatedCount = 0;

      for (final entry in itemQuantities.entries) {
        final itemName = entry.key;
        final qtyCollected = entry.value;
        final costCollected = itemCosts[itemName] ?? 0.0;

        final nItem = norm(itemName);
        final nItemSingular = singularize(nItem);

        Map<String, dynamic>? target =
            materialsByName[nItem] ?? materialsByName[nItemSingular];

        // Fallback: partial match across all materials
        if (target == null) {
          for (final m in materialRows) {
            final mName = (m['name'] as String?)?.toLowerCase().trim() ?? '';
            if (mName.isNotEmpty &&
                (mName.contains(nItem) || nItem.contains(mName))) {
              target = m;
              break;
            }
          }
        }

        if (target != null) {
          final currentStock = (target['stock'] as num?)?.toDouble() ?? 0.0;
          final currentTotalCost =
              (target['total_purchase_cost'] as num?)?.toDouble() ?? 0.0;

          final newStock = currentStock + qtyCollected;
          final newTotalCost = currentTotalCost + costCollected;
          final newAvgCost = newStock > 0 ? newTotalCost / newStock : 0.0;

          await _db
              .from('junkshop_materials')
              .update({
                'stock': newStock,
                'total_purchase_cost': newTotalCost,
                'avg_purchase_cost': newAvgCost,
              })
              .eq('id', target['id']);
          // keep the in-memory copy current in case another item matches the same material
          target['stock'] = newStock;
          target['total_purchase_cost'] = newTotalCost;
          updatedCount++;
        } else if (kDebugMode) {
          print('No inventory match for collected item "$itemName"');
        }
      }

      if (kDebugMode) print('Updated stock for $updatedCount materials');
    } catch (e) {
      if (kDebugMode) print('Failed to update inventory stock: $e');
      // Don't rethrow - inventory update is non-critical
    }
  }
}
