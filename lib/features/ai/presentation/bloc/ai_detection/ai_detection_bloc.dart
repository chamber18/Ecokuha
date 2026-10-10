import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/ai_detection_repository.dart';
import '../../../domain/usecases/detect_waste_usecase.dart';
import '../../../../../core/constants/app_constants.dart';
import 'ai_detection_event.dart';
import 'ai_detection_state.dart';

class AiDetectionBloc extends Bloc<AiDetectionEvent, AiDetectionState> {
  final AiDetectionRepository repository;
  final DetectWasteUseCase detectWasteUseCase;

  AiDetectionBloc({required this.repository, required this.detectWasteUseCase})
    : super(const AiDetectionInitial()) {
    on<LoadModelEvent>(_onLoadModel);
    on<DetectWasteEvent>(_onDetectWaste);
    on<ClearDetectionEvent>(_onClearDetection);
  }

  Future<void> _onLoadModel(
    LoadModelEvent event,
    Emitter<AiDetectionState> emit,
  ) async {
    emit(const AiDetectionLoadingModel());

    final result = await repository.loadModel();

    result.fold(
      (error) => emit(AiDetectionModelError(error)),
      (_) => emit(const AiDetectionModelLoaded()),
    );
  }

  Future<void> _onDetectWaste(
    DetectWasteEvent event,
    Emitter<AiDetectionState> emit,
  ) async {
    emit(const AiDetectionDetecting());

    final result = await detectWasteUseCase(event.imagePath);

    result.fold((error) => emit(AiDetectionError(error)), (detection) {
      final confidence = detection.confidence;

      if (confidence < AIConstants.rejectionThreshold) {
        emit(AiDetectionRejected(confidence, detection));
      } else {
        emit(AiDetectionSuccess(detection));
      }
    });
  }

  void _onClearDetection(
    ClearDetectionEvent event,
    Emitter<AiDetectionState> emit,
  ) {
    emit(const AiDetectionModelLoaded());
  }

  @override
  Future<void> close() {
    repository.dispose();
    return super.close();
  }
}
