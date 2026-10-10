import 'package:dartz/dartz.dart';
import '../entities/waste_detection_result.dart';
import '../repositories/ai_detection_repository.dart';

class DetectWasteUseCase {
  final AiDetectionRepository repository;

  DetectWasteUseCase(this.repository);

  Future<Either<String, WasteDetectionResult>> call(String imagePath) {
    return repository.detectWaste(imagePath);
  }
}
