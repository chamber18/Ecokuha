import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/create_promotion.dart' as uc;
import '../../../domain/usecases/get_junkshop_promotions.dart';
import '../../../domain/usecases/update_promotion.dart' as uc;
import '../../../domain/usecases/cancel_promotion.dart';
import '../../../domain/repositories/promotion_repository.dart';
import 'junkshop_promotions_event.dart';
import 'junkshop_promotions_state.dart';

class JunkshopPromotionsBloc
    extends Bloc<JunkshopPromotionsEvent, JunkshopPromotionsState> {
  final uc.CreatePromotion createPromotionUseCase;
  final GetJunkshopPromotions getJunkshopPromotions;
  final uc.UpdatePromotion updatePromotionUseCase;
  final CancelPromotion cancelPromotion;
  final PromotionRepository repository;

  JunkshopPromotionsBloc({
    required this.createPromotionUseCase,
    required this.getJunkshopPromotions,
    required this.updatePromotionUseCase,
    required this.cancelPromotion,
    required this.repository,
  }) : super(JunkshopPromotionsInitial()) {
    on<LoadJunkshopPromotions>(_onLoadPromotions);
    on<CreatePromotion>(_onCreatePromotion);
    on<UpdatePromotion>(_onUpdatePromotion);
    on<CancelExistingPromotion>(_onCancelPromotion);
    on<DeleteExistingPromotion>(_onDeletePromotion);
  }

  Future<void> _onLoadPromotions(
    LoadJunkshopPromotions event,
    Emitter<JunkshopPromotionsState> emit,
  ) async {
    emit(JunkshopPromotionsLoading());

    final result = await getJunkshopPromotions(
      event.junkshopId,
      status: event.statusFilter,
    );

    result.fold(
      (failure) => emit(JunkshopPromotionsError(failure.message)),
      (promotions) => emit(JunkshopPromotionsLoaded(promotions)),
    );
  }

  Future<void> _onCreatePromotion(
    CreatePromotion event,
    Emitter<JunkshopPromotionsState> emit,
  ) async {
    emit(JunkshopPromotionsOperationInProgress());

    final result = await repository.createPromotion(
      event.promotion,
      imageFile: event.imageFile,
    );

    result.fold(
      (failure) => emit(JunkshopPromotionsError(failure.message)),
      (promotionId) => emit(JunkshopPromotionsOperationSuccess()),
    );
  }

  Future<void> _onUpdatePromotion(
    UpdatePromotion event,
    Emitter<JunkshopPromotionsState> emit,
  ) async {
    emit(JunkshopPromotionsOperationInProgress());

    final result = await repository.updatePromotion(
      event.promotion,
      imageFile: event.imageFile,
    );

    result.fold(
      (failure) => emit(JunkshopPromotionsError(failure.message)),
      (_) => emit(JunkshopPromotionsOperationSuccess()),
    );
  }

  Future<void> _onCancelPromotion(
    CancelExistingPromotion event,
    Emitter<JunkshopPromotionsState> emit,
  ) async {
    emit(PromotionCancelling());

    final result = await cancelPromotion(event.promotionId, event.junkshopId);

    result.fold(
      (failure) => emit(PromotionOperationError(failure.message)),
      (_) => emit(PromotionCancelled()),
    );
  }

  Future<void> _onDeletePromotion(
    DeleteExistingPromotion event,
    Emitter<JunkshopPromotionsState> emit,
  ) async {
    emit(PromotionDeleting());

    final result = await repository.deletePromotion(
      event.promotionId,
      event.junkshopId,
    );

    result.fold(
      (failure) => emit(PromotionOperationError(failure.message)),
      (_) => emit(PromotionDeleted()),
    );
  }
}
