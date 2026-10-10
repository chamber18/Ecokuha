import 'package:dartz/dartz.dart';
import '../../domain/entities/waste_detection_result.dart';
import '../../domain/repositories/ai_detection_repository.dart';
import '../datasources/ai_detection_datasource.dart';
import '../models/waste_detection_model.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class AiDetectionRepositoryImpl implements AiDetectionRepository {
  final AiDetectionDatasource datasource;

  AiDetectionRepositoryImpl({required this.datasource});

  @override
  Future<Either<String, void>> loadModel() async {
    try {
      await datasource.loadModel();
      return const Right(null);
    } catch (e) {
      return Left('Failed to load AI model: $e');
    }
  }

  @override
  Future<Either<String, WasteDetectionResult>> detectWaste(
    String imagePath,
  ) async {
    try {
      final result = await datasource.detectWaste(imagePath);

      if (kDebugMode) print('[Repository] Raw result from datasource: $result');

      // Build lightweight WasteDetectionModel for each top candidate
      final rawTop = result['topResults'] as List? ?? [];
      final topModels = rawTop.map((r) {
        final entry = r as Map<String, dynamic>;
        return WasteDetectionModel.fromDetection(
          label: entry['label'] as String,
          confidence: entry['confidence'] as double,
        );
      }).toList();

      final model = WasteDetectionModel.fromDetection(
        label: result['label'] as String,
        confidence: result['confidence'] as double,
        boundingBox: null,
        topResults: topModels,
      );

      if (kDebugMode) {
        print(
          '[Repository] Model created: ${model.label} with ${topModels.length} top results',
        );
      }

      return Right(model);
    } catch (e) {
      return Left('Failed to detect waste: $e');
    }
  }

  @override
  void dispose() {
    datasource.dispose();
  }
}
