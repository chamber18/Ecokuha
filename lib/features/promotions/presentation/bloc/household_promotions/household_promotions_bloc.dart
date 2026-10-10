import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';
import '../../../../../core/error/failures.dart';
import '../../../domain/entities/promotion.dart';
import '../../../domain/usecases/get_active_promotions.dart';
import '../../../domain/repositories/promotion_repository.dart';
import 'household_promotions_event.dart';
import 'household_promotions_state.dart';

class HouseholdPromotionsBloc
    extends Bloc<HouseholdPromotionsEvent, HouseholdPromotionsState> {
  final GetActivePromotions getActivePromotions;
  final PromotionRepository repository;

  HouseholdPromotionsBloc({
    required this.getActivePromotions,
    required this.repository,
  }) : super(HouseholdPromotionsInitial()) {
    on<LoadActivePromotions>(_onLoadPromotions);
    on<WatchActivePromotions>(_onWatchPromotions);
    on<StopWatchingPromotions>(_onStopWatching);
    on<RefreshPromotions>(_onRefreshPromotions);
  }

  Future<void> _onLoadPromotions(
    LoadActivePromotions event,
    Emitter<HouseholdPromotionsState> emit,
  ) async {
    emit(HouseholdPromotionsLoading());

    final result = await getActivePromotions(
      materialType: event.materialType,
      promotionType: event.promotionType,
      limit: event.limit,
    );

    result.fold(
      (failure) => emit(HouseholdPromotionsError(failure.message)),
      (promotions) => emit(HouseholdPromotionsLoaded(promotions)),
    );
  }

  Future<void> _onWatchPromotions(
    WatchActivePromotions event,
    Emitter<HouseholdPromotionsState> emit,
  ) async {
    emit(HouseholdPromotionsLoading());

    await emit.forEach<Either<Failure, List<Promotion>>>(
      repository.watchActivePromotions(
        materialType: event.materialType,
        promotionType: event.promotionType,
      ),
      onData: (result) {
        return result.fold(
          (failure) => HouseholdPromotionsError(failure.message),
          (promotions) => HouseholdPromotionsLoaded(promotions),
        );
      },
      onError: (error, stackTrace) {
        return HouseholdPromotionsError(error.toString());
      },
    );
  }

  Future<void> _onStopWatching(
    StopWatchingPromotions event,
    Emitter<HouseholdPromotionsState> emit,
  ) async {
    // emit.forEach handles subscription cleanup automatically when new event arrives
    // Just emit initial state to reset
    emit(HouseholdPromotionsInitial());
  }

  Future<void> _onRefreshPromotions(
    RefreshPromotions event,
    Emitter<HouseholdPromotionsState> emit,
  ) async {
    if (state is HouseholdPromotionsLoaded) {
      final result = await getActivePromotions();

      result.fold(
        (failure) => emit(HouseholdPromotionsError(failure.message)),
        (promotions) => emit(HouseholdPromotionsLoaded(promotions)),
      );
    }
  }
}
