import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';

class PostingItemDto {
  final String name;
  final String category;
  final int quantity;
  final String unit;
  final double estimatedValue;
  final double? priceMin;
  final double? priceMax;
  final String? baseUnit;
  final bool? isAiScanned;
  final double? promotionBoostPercentage;
  final String? promotionId;

  // Image paths for the item
  final List<String>? imagePaths;

  PostingItemDto({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.estimatedValue,
    this.priceMin,
    this.priceMax,
    this.baseUnit,
    this.isAiScanned,
    this.imagePaths,
    this.promotionBoostPercentage,
    this.promotionId,
  });

  Map<String, dynamic> toMap() {
    // Helper to round to 2 decimal places
    double round(double value) => (value * 100).roundToDouble() / 100;

    return {
      PostingFields.itemName: name,
      PostingFields.itemCategory: category,
      PostingFields.itemQuantity: quantity,
      PostingFields.itemUnit: unit,
      PostingFields.itemEstimatedValue: round(estimatedValue),
      if (priceMin != null) PostingFields.itemPriceMin: round(priceMin!),
      if (priceMax != null) PostingFields.itemPriceMax: round(priceMax!),
      if (baseUnit != null) PostingFields.itemBaseUnit: baseUnit,
      if (isAiScanned != null) PostingFields.itemIsAiScanned: isAiScanned,
      if (imagePaths != null && imagePaths!.isNotEmpty)
        PostingFields.itemImagePaths: imagePaths,
      if (promotionBoostPercentage != null)
        'promotionBoostPercentage': round(promotionBoostPercentage!),
      if (promotionId != null) 'promotionId': promotionId,
    };
  }
}

class PostingDto {
  final String householdId;
  final List<PostingItemDto> items;
  final double totalEstimatedValue;
  final double? estimatedTotalWeight; // in kg - helps junkshop assign collector
  final String status; // e.g., pending, scheduled, completed
  final String? notes;

  // Legacy fields kept only for passing data to repository
  // Repository will organize these into nested household/junkshop objects
  final String? householdName;
  final String? householdPhone;
  final String? householdAddress; // Full household address
  final String? addressShort;
  final double? householdLat; // Pickup location latitude
  final double? householdLng; // Pickup location longitude
  final String? assignedJunkshopId;
  final String? assignedJunkshopName;
  final String? assignedJunkshopAddress;
  final String? assignedJunkshopPhone;
  final double? assignedJunkshopRating;
  final double? assignedJunkshopLat; // Junkshop location latitude
  final double? assignedJunkshopLng; // Junkshop location longitude
  final String? pickupLocation; // Address note

  // Schedule information - household blocks dates when they're NOT available
  final List<DateTime>?
  unavailableDates; // Dates when household is NOT available for pickup
  final DateTime?
  scheduledDate; // Junkshop's selected date (must not be in unavailableDates)
  final String? scheduledTime;
  final String? specialInstructions;

  // Rating fields
  final bool? isRated;
  final DateTime? ratingDeadline;
  final double? collectorRating;
  final double? junkshopRating;

  PostingDto({
    required this.householdId,
    required this.items,
    required this.totalEstimatedValue,
    this.estimatedTotalWeight,
    this.status = 'pending',
    this.notes,
    this.householdName,
    this.householdPhone,
    this.householdAddress,
    this.addressShort,
    this.householdLat,
    this.householdLng,
    this.assignedJunkshopId,
    this.assignedJunkshopName,
    this.assignedJunkshopAddress,
    this.assignedJunkshopPhone,
    this.assignedJunkshopRating,
    this.assignedJunkshopLat,
    this.assignedJunkshopLng,
    this.pickupLocation,
    this.unavailableDates,
    this.scheduledDate,
    this.scheduledTime,
    this.specialInstructions,
    this.isRated,
    this.ratingDeadline,
    this.collectorRating,
    this.junkshopRating,
  });

  Map<String, dynamic> toMap() {
    // Helper to round to 2 decimal places
    double round(double value) => (value * 100).roundToDouble() / 100;

    return {
      // Items with summary data nested together
      PostingFields.itemsData: {
        PostingFields.itemsList: items.map((e) => e.toMap()).toList(),
        PostingFields.totalEstimatedValue: round(totalEstimatedValue),
        if (estimatedTotalWeight != null)
          PostingFields.estimatedTotalWeight: round(estimatedTotalWeight!),
      },
      PostingFields.status: status,
      if (notes != null) PostingFields.notes: notes,
      // Schedule data
      if (unavailableDates != null && unavailableDates!.isNotEmpty)
        PostingFields.unavailableDates: unavailableDates!
            .map((date) => Timestamp.fromDate(date))
            .toList(),
      if (scheduledDate != null)
        PostingFields.scheduledDate: Timestamp.fromDate(scheduledDate!),
      if (scheduledTime != null) PostingFields.scheduledTime: scheduledTime,
      if (specialInstructions != null)
        PostingFields.specialInstructions: specialInstructions,
      // Rating fields
      if (isRated != null) 'isRated': isRated,
      if (ratingDeadline != null)
        'ratingDeadline': Timestamp.fromDate(ratingDeadline!),
      if (collectorRating != null) 'collectorRating': collectorRating,
      if (junkshopRating != null) 'junkshopRating': junkshopRating,
    };
  }
}
