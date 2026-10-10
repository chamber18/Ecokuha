import 'package:equatable/equatable.dart';
import '../../../domain/entities/promotion.dart';

abstract class HouseholdPromotionsState extends Equatable {
  const HouseholdPromotionsState();

  @override
  List<Object?> get props => [];
}

class HouseholdPromotionsInitial extends HouseholdPromotionsState {}

class HouseholdPromotionsLoading extends HouseholdPromotionsState {}

class HouseholdPromotionsLoaded extends HouseholdPromotionsState {
  final List<Promotion> promotions;

  const HouseholdPromotionsLoaded(this.promotions);

  @override
  List<Object?> get props => [promotions];
}

class HouseholdPromotionsError extends HouseholdPromotionsState {
  final String message;

  const HouseholdPromotionsError(this.message);

  @override
  List<Object?> get props => [message];
}
