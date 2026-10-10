import 'package:dartz/dartz.dart';
import '../entities/waste_detection_result.dart';

abstract class AiDetectionRepository {
  Future<Either<String, WasteDetectionResult>> detectWaste(String imagePath);
  Future<Either<String, void>> loadModel();
  void dispose();
}
