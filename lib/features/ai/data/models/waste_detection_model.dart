import '../../domain/entities/waste_detection_result.dart';

class WasteDetectionModel extends WasteDetectionResult {
  const WasteDetectionModel({
    required super.label,
    required super.confidence,
    required super.materialCategory,
    super.suggestedWeight,
    super.boundingBox,
    super.topResults,
  });

  factory WasteDetectionModel.fromDetection({
    required String label,
    required double confidence,
    Map<String, double>? boundingBox,
    List<WasteDetectionResult> topResults = const [],
  }) {
    final materialCategory = _mapLabelToCategory(label);
    final suggestedWeight = _estimateWeight(label, materialCategory);

    return WasteDetectionModel(
      label: label,
      confidence: confidence,
      materialCategory: materialCategory,
      suggestedWeight: suggestedWeight,
      boundingBox: boundingBox,
      topResults: topResults,
    );
  }

  /// Maps AI model label → Firebase category string.
  /// Category values must match exactly what junkshops store in Firestore
  /// (/junkshops/{uid}/materials → 'category' field).
  static String _mapLabelToCategory(String label) {
    const Map<String, String> labelToCategory = {
      // E-waste
      'aircon': 'e-waste',
      'electronic_board': 'e-waste',
      // Glass bottles
      'emperador_bottle': 'glass',
      'garapa_bottle': 'glass',
      'ketchup_bottle': 'glass',
      'red_horse_bottle': 'glass',
      'san_mig_bottle': 'glass',
      'shiohoctong_bottle': 'glass',
      'softdrinks_bottle': 'glass',
      'tanduay_bottle': 'glass',
      'tanduay_select_bottle': 'glass',
      'bottle_case': 'glass',
      // Metal
      'aluminum_can': 'metal',
      'brass_bronze': 'metal',
      'cin_metal': 'metal',
      'copper': 'metal',
      'kaldero': 'metal',
      'light_metal': 'metal',
      'metal_cylinder': 'metal',
      'stainless_scrap': 'metal',
      'stainless_tray': 'metal',
      // Iron (separate Firebase category in this junkshop)
      'alloy': 'iron',
      'cyclone': 'iron',
      'pundido_metal': 'iron',
      'solid_metal': 'iron',
      // Paper
      'karton': 'paper',
      'paper': 'paper',
      // Plastic
      'monobloc_plastic': 'plastic',
      'pet_bottle': 'plastic',
      'plastic_waste': 'plastic',
      // Battery
      'battery': 'battery',
      // Others
      'tires': 'others',
      'lata': 'others',
    };

    return labelToCategory[label.toLowerCase()] ?? 'others';
  }

  /// Returns the Firebase search term for the given AI label.
  /// Firebase material names now match label names exactly, so we just
  /// normalize underscores to spaces to match Firestore's name field.
  static String getSearchNameForLabel(String label) {
    return label
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _estimateWeight(String label, String category) {
    // Provide weight suggestions based on common items
    final labelLower = label.toLowerCase();

    if (labelLower.contains('bottle')) {
      return '0.5 kg';
    } else if (labelLower.contains('can_aluminum')) {
      return '0.1 kg';
    } else if (labelLower.contains('cartoon')) {
      return '1.0 kg';
    } else if (labelLower.contains('kaldero')) {
      return '2.0 kg';
    } else if (labelLower.contains('battery')) {
      return '0.05 kg';
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'confidence': confidence,
      'materialCategory': materialCategory,
      'suggestedWeight': suggestedWeight,
    };
  }

  factory WasteDetectionModel.fromJson(Map<String, dynamic> json) {
    return WasteDetectionModel(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      materialCategory: json['materialCategory'] as String,
      suggestedWeight: json['suggestedWeight'] as String?,
    );
  }
}
