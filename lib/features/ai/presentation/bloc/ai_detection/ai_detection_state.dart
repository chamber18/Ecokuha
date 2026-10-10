import 'package:equatable/equatable.dart';
import '../../../domain/entities/waste_detection_result.dart';

abstract class AiDetectionState extends Equatable {
  const AiDetectionState();

  @override
  List<Object?> get props => [];
}

class AiDetectionInitial extends AiDetectionState {
  const AiDetectionInitial();
}

class AiDetectionLoadingModel extends AiDetectionState {
  const AiDetectionLoadingModel();
}

class AiDetectionModelLoaded extends AiDetectionState {
  const AiDetectionModelLoaded();
}

class AiDetectionModelError extends AiDetectionState {
  final String message;

  const AiDetectionModelError(this.message);

  @override
  List<Object?> get props => [message];
}

class AiDetectionDetecting extends AiDetectionState {
  const AiDetectionDetecting();
}

class AiDetectionSuccess extends AiDetectionState {
  final WasteDetectionResult result;

  const AiDetectionSuccess(this.result);

  @override
  List<Object?> get props => [result];
}

class AiDetectionError extends AiDetectionState {
  final String message;

  const AiDetectionError(this.message);

  @override
  List<Object?> get props => [message];
}

class AiDetectionRejected extends AiDetectionState {
  final double confidence;

  /// Full detection result — carries topResults for manual selection in the UI.
  final WasteDetectionResult result;

  const AiDetectionRejected(this.confidence, this.result);

  @override
  List<Object?> get props => [confidence, result];
}

class AiDetectionUncertain extends AiDetectionState {
  final WasteDetectionResult result;
  final List<Map<String, dynamic>> alternativeMaterials;

  const AiDetectionUncertain(this.result, this.alternativeMaterials);

  @override
  List<Object?> get props => [result, alternativeMaterials];
}
