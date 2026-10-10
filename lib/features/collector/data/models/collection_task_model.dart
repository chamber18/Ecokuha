import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Domain model representing a collection task assigned to a collector.
/// Optional client-computed fields (distanceKm, etaMinutes, estWeightKg) are
/// enriched after resolving the collector's current location; they are not
/// persisted.
class CollectorTask {
  final String id;
  final String householdId;

  /// Legacy field (no longer populated; postings are fetched by id)
  final String? docPath;
  final String? householdName;
  final String? addressShort;
  final String? profileImageUrl;
  final List<String> items; // Human readable item list ("Metal (3 kg)")
  final double totalValue; // Aggregated estimated value (peso)
  final DateTime? createdAt;
  final DateTime? assignedAt;
  final DateTime? dateOfCollection; // Selected collection date
  final String status; // assigned | in_transit | completed | other

  // Household coordinates (if present in posting document)
  final double? householdLat;
  final double? householdLng;

  // Client-side computed (mutable to allow enrichment post fetch)
  double? distanceKm;
  int? etaMinutes;
  double? estWeightKg;

  CollectorTask({
    required this.id,
    required this.householdId,
    this.docPath,
    this.householdName,
    this.addressShort,
    this.profileImageUrl,
    required this.items,
    required this.totalValue,
    this.createdAt,
    this.assignedAt,
    this.dateOfCollection,
    required this.status,
    this.householdLat,
    this.householdLng,
    this.estWeightKg,
  });

  /// Factory parser from a posting document map (see rowToDoc('postings', row)).
  /// Also accepts a raw snake_case row. Safely extracts items, household
  /// coordinates and value fields.
  factory CollectorTask.fromMap(Map<String, dynamic> raw, {String? id}) {
    final data = raw.containsKey('household_id') || raw.containsKey('total_estimated_value')
        ? rowToDoc('postings', raw)
        : raw;
    final docId = id ?? data['id']?.toString() ?? '';

    if (kDebugMode) print('[CollectorTask] Parsing doc $docId');
    if (kDebugMode) {
      print(
        '[CollectorTask] Has location field: ${data.containsKey(PostingFields.location)}',
      );
    }
    if (kDebugMode) print('[CollectorTask] Location value: ${data[PostingFields.location]}');
    if (kDebugMode) {
      print(
        '[CollectorTask] Location type: ${data[PostingFields.location]?.runtimeType}',
      );
    }

    // Build display items + compute weight. Support both legacy List and nested { list: [...] } shapes.
    final List<String> displayItems = [];
    double totalWeightKg = 0.0;
    final rawItemsAny = data[PostingFields.items];
    List<dynamic> itemsListDyn = const [];
    Map<String, dynamic>? itemsMap;
    if (rawItemsAny is List) {
      itemsListDyn = rawItemsAny;
    } else if (rawItemsAny is Map<String, dynamic>) {
      itemsMap = rawItemsAny;
      final nestedList = itemsMap[PostingFields.itemsList];
      if (nestedList is List) {
        itemsListDyn = nestedList;
      }
    }

    for (final it in itemsListDyn) {
      if (it is Map<String, dynamic>) {
        final name = it[PostingFields.itemName]?.toString() ?? 'Item';
        final qtyDynamic = it[PostingFields.itemQuantity];
        final unit = it[PostingFields.itemUnit]?.toString() ?? '';
        final qtyStr = qtyDynamic?.toString() ?? '';
        displayItems.add(
          qtyStr.isNotEmpty && unit.isNotEmpty ? '$name ($qtyStr $unit)' : name,
        );

        // Weight derivation rules:
        final weightExplicit = it[PostingFields.itemWeightKg];
        if (weightExplicit is num) {
          totalWeightKg += weightExplicit.toDouble();
        } else if (unit.toLowerCase() == 'kg') {
          final qtyNum = qtyDynamic is num
              ? qtyDynamic.toDouble()
              : double.tryParse(qtyStr);
          if (qtyNum != null) totalWeightKg += qtyNum;
        }
      } else if (it is String) {
        displayItems.add(it);
      }
    }

    // Household coordinates may appear under several possible keys.
    double? lat;
    double? lng;
    void extractCoords(dynamic source) {
      if (source is Map<String, dynamic>) {
        final latRaw =
            source[PostingFields.locationLat] ?? source[PostingFields.latitude];
        final lngRaw =
            source[PostingFields.locationLng] ??
            source[PostingFields.longitude];
        if (latRaw is num) lat = latRaw.toDouble();
        if (lngRaw is num) lng = lngRaw.toDouble();
        if (lat == null && latRaw is String) {
          lat = double.tryParse(latRaw);
        }
        if (lng == null && lngRaw is String) {
          lng = double.tryParse(lngRaw);
        }
        // Some schemas store coords as {'coords': {'lat':..,'lng':..}}
        final nested = source['coords'];
        if ((lat == null || lng == null) && nested is Map<String, dynamic>) {
          final nLat =
              nested[PostingFields.locationLat] ??
              nested[PostingFields.latitude];
          final nLng =
              nested[PostingFields.locationLng] ??
              nested[PostingFields.longitude];
          if (lat == null && nLat is num) lat = nLat.toDouble();
          if (lng == null && nLng is num) lng = nLng.toDouble();
        }
        // Household nested location map
        final userLoc = source[UserFields.location];
        if ((lat == null || lng == null) && userLoc is Map<String, dynamic>) {
          final uLat =
              userLoc[PostingFields.locationLat] ?? userLoc[UserFields.lat];
          final uLng =
              userLoc[PostingFields.locationLng] ?? userLoc[UserFields.lng];
          if (lat == null && uLat is num) lat = uLat.toDouble();
          if (lng == null && uLng is num) lng = uLng.toDouble();
        }
      }
    }

    extractCoords(data[PostingFields.pickupLocation]);
    extractCoords(data[PostingFields.location]);
    extractCoords(data[PostingFields.locationCoords]);
    // Try nested household/junkshop objects for coords
    final nestedHousehold = data[PostingFields.household];
    if (nestedHousehold is Map<String, dynamic>) {
      extractCoords(nestedHousehold);
    }

    if (kDebugMode) print('[CollectorTask] Final extracted coords: lat=$lat, lng=$lng');

    // Total estimated value: prioritise canonical 'totalEstimatedValue'.
    double totalValue =
        (data[PostingFields.totalEstimatedValue] as num?)?.toDouble() ??
        (data[PostingFields.value] as num?)?.toDouble() ??
        (data[PostingFields.estimatedValue] as num?)?.toDouble() ??
        0.0;
    if (totalValue == 0.0 && itemsMap != null) {
      final nestedTotal = itemsMap[PostingFields.totalEstimatedValue];
      if (nestedTotal is num) totalValue = nestedTotal.toDouble();
    }

    DateTime? created;
    final tsCreated = data[PostingFields.createdAt];
    created = toDateTime(tsCreated);

    DateTime? assigned;
    final tsAssigned = data[PostingFields.assignedAt];
    assigned = toDateTime(tsAssigned);

    DateTime? collectionDate;
    final tsCollection = data[PostingFields.dateOfCollection];
    collectionDate = toDateTime(tsCollection);

    // Address fallback chain: addressShort → household.location.address → pickupLocation → location → address
    String? addressShort = data[PostingFields.addressShort]?.toString();
    if (addressShort == null || addressShort.isEmpty) {
      if (nestedHousehold is Map<String, dynamic>) {
        final hLoc = nestedHousehold[UserFields.location];
        if (hLoc is Map<String, dynamic>) {
          addressShort = hLoc[UserFields.address]?.toString();
        }
        addressShort ??= nestedHousehold[UserFields.address]?.toString();
      }
      addressShort ??= data[PostingFields.pickupLocation]?.toString();
      addressShort ??= data[PostingFields.location]?.toString();
      addressShort ??= data[UserFields.address]?.toString();
    }

    // Weight: prioritize estimatedTotalWeight from the posting, fallback to computed weight
    double? finalWeight;
    final estimatedTotalWeight =
        data[PostingFields.estimatedTotalWeight] ??
        itemsMap?[PostingFields.estimatedTotalWeight];
    if (estimatedTotalWeight is num) {
      finalWeight = estimatedTotalWeight.toDouble();
    } else if (totalWeightKg > 0) {
      finalWeight = totalWeightKg;
    }

    return CollectorTask(
      id: docId,
      householdId:
          data[PostingFields.householdId]?.toString() ??
          (nestedHousehold is Map<String, dynamic>
              ? (nestedHousehold[UserFields.id]?.toString() ?? '')
              : ''),
      householdName:
          data[PostingFields.householdName]?.toString() ??
          (nestedHousehold is Map<String, dynamic>
              ? (nestedHousehold[UserFields.fullName]?.toString() ??
                    nestedHousehold[UserFields.name]?.toString())
              : null),
      addressShort: addressShort,
      profileImageUrl:
          data[PostingFields.profileImageUrl]?.toString() ??
          (nestedHousehold is Map<String, dynamic>
              ? nestedHousehold[UserFields.profileImageUrl]?.toString()
              : null),
      items: displayItems,
      totalValue: totalValue,
      createdAt: created,
      assignedAt: assigned,
      dateOfCollection: collectionDate,
      status: data[PostingFields.status]?.toString() ?? 'assigned',
      householdLat: lat,
      householdLng: lng,
      estWeightKg: finalWeight,
    );
  }
}
