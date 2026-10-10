import 'package:equatable/equatable.dart';

abstract class AiDetectionEvent extends Equatable {
  const AiDetectionEvent();

  @override
  List<Object?> get props => [];
}

class LoadModelEvent extends AiDetectionEvent {
  const LoadModelEvent();
}

class DetectWasteEvent extends AiDetectionEvent {
  final String imagePath;
  final List<Map<String, dynamic>>? materialCatalog;

  const DetectWasteEvent(this.imagePath, {this.materialCatalog});

  @override
  List<Object?> get props => [imagePath, materialCatalog];
}

class ClearDetectionEvent extends AiDetectionEvent {
  const ClearDetectionEvent();
}
