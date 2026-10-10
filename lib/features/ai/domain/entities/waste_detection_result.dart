import 'package:equatable/equatable.dart';

class WasteDetectionResult extends Equatable {
  final String label;
  final double confidence;
  final String materialCategory;
  final String? suggestedWeight;
  final Map<String, double>?
  boundingBox; // {x, y, width, height} normalized [0-1]
  /// AI model's top candidates sorted by confidence (non-zero only).
  final List<WasteDetectionResult> topResults;

  const WasteDetectionResult({
    required this.label,
    required this.confidence,
    required this.materialCategory,
    this.suggestedWeight,
    this.boundingBox,
    this.topResults = const [],
  });

  @override
  List<Object?> get props => [
    label,
    confidence,
    materialCategory,
    suggestedWeight,
    boundingBox,
    topResults,
  ];
}
