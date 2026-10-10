class DetectedItem {
  String name;
  String category;
  double confidence;
  bool isRecyclable;
  int quantity;
  String unit;
  double estimatedValue;
  double? estimatedWeightKg; // Weight in kg for pricing calculation

  // Source tracking
  bool isAiScanned; // true for AI detected, false for manual input

  // Image paths for the item
  List<String> imagePaths;

  // Optional pricing metadata for manual items
  double? priceMin;
  double? priceMax;
  double? boostedPriceMin; // Price after promotion boost
  double? boostedPriceMax; // Price after promotion boost
  String? baseUnit; // unit of the price (e.g., kg, lbs, piece)
  double?
  promotionBoostPercentage; // Promotion boost applied (e.g., 12.0 for 12%)
  String? promotionId; // ID of the promotion that was applied

  // Junkshop and location information
  String? selectedJunkshop; // Name of selected junkshop
  String? location; // User's location
  bool
  isNotAcceptableByJunkshop; // Flag when material is not accepted by selected junkshop

  // Condition checkboxes
  bool isClean;
  bool isComplete;
  bool isCracked;
  bool isDented;
  bool isFaded;
  bool hasStickers;
  bool hasRust;
  bool hasPaint;

  DetectedItem({
    required this.name,
    required this.category,
    required this.confidence,
    required this.isRecyclable,
    required this.quantity,
    required this.unit,
    required this.estimatedValue,
    this.estimatedWeightKg,
    this.isAiScanned = true,
    this.imagePaths = const [],
    this.priceMin,
    this.priceMax,
    this.boostedPriceMin,
    this.boostedPriceMax,
    this.baseUnit,
    this.promotionBoostPercentage,
    this.promotionId,
    this.selectedJunkshop,
    this.location,
    this.isNotAcceptableByJunkshop = false,
    this.isClean = false,
    this.isComplete = false,
    this.isCracked = false,
    this.isDented = false,
    this.isFaded = false,
    this.hasStickers = false,
    this.hasRust = false,
    this.hasPaint = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'confidence': confidence,
      'isRecyclable': isRecyclable,
      'quantity': quantity,
      'unit': unit,
      'estimatedValue': estimatedValue,
      'estimatedWeightKg': estimatedWeightKg,
      'isAiScanned': isAiScanned,
      'imagePaths': imagePaths,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'baseUnit': baseUnit,
      'promotionBoostPercentage': promotionBoostPercentage,
      'selectedJunkshop': selectedJunkshop,
      'location': location,
      'isNotAcceptableByJunkshop': isNotAcceptableByJunkshop,
      'isClean': isClean,
      'isComplete': isComplete,
      'isCracked': isCracked,
      'isDented': isDented,
      'isFaded': isFaded,
      'hasStickers': hasStickers,
      'hasRust': hasRust,
      'hasPaint': hasPaint,
    };
  }

  factory DetectedItem.fromJson(Map<String, dynamic> json) {
    return DetectedItem(
      name: json['name'] as String,
      category: json['category'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      isRecyclable: json['isRecyclable'] as bool,
      quantity: json['quantity'] as int,
      unit: json['unit'] as String,
      estimatedValue: (json['estimatedValue'] as num).toDouble(),
      estimatedWeightKg: (json['estimatedWeightKg'] as num?)?.toDouble(),
      isAiScanned: json['isAiScanned'] as bool? ?? true,
      imagePaths: (json['imagePaths'] as List<dynamic>?)?.cast<String>() ?? [],
      priceMin: json['priceMin'] as double?,
      priceMax: json['priceMax'] as double?,
      baseUnit: json['baseUnit'] as String?,
      promotionBoostPercentage: json['promotionBoostPercentage'] as double?,
      selectedJunkshop: json['selectedJunkshop'] as String?,
      location: json['location'] as String?,
      isNotAcceptableByJunkshop:
          json['isNotAcceptableByJunkshop'] as bool? ?? false,
      isClean: json['isClean'] as bool? ?? false,
      isComplete: json['isComplete'] as bool? ?? false,
      isCracked: json['isCracked'] as bool? ?? false,
      isDented: json['isDented'] as bool? ?? false,
      isFaded: json['isFaded'] as bool? ?? false,
      hasStickers: json['hasStickers'] as bool? ?? false,
      hasRust: json['hasRust'] as bool? ?? false,
      hasPaint: json['hasPaint'] as bool? ?? false,
    );
  }
}
