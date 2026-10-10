import 'package:equatable/equatable.dart';
import '../../../domain/entities/promotion_type.dart';

abstract class HouseholdPromotionsEvent extends Equatable {
  const HouseholdPromotionsEvent();

  @override
  List<Object?> get props => [];
}

class LoadActivePromotions extends HouseholdPromotionsEvent {
  final String? materialType;
  final PromotionType? promotionType;
  final int? limit;

  const LoadActivePromotions({
    this.materialType,
    this.promotionType,
    this.limit,
  });

  @override
  List<Object?> get props => [materialType, promotionType, limit];
}

class WatchActivePromotions extends HouseholdPromotionsEvent {
  final String? materialType;
  final PromotionType? promotionType;

  const WatchActivePromotions({this.materialType, this.promotionType});

  @override
  List<Object?> get props => [materialType, promotionType];
}

class StopWatchingPromotions extends HouseholdPromotionsEvent {}

class RefreshPromotions extends HouseholdPromotionsEvent {}
