import 'package:equatable/equatable.dart';
import '../../../domain/entities/promotion.dart';

abstract class JunkshopPromotionsState extends Equatable {
  const JunkshopPromotionsState();

  @override
  List<Object?> get props => [];
}

class JunkshopPromotionsInitial extends JunkshopPromotionsState {}

class JunkshopPromotionsLoading extends JunkshopPromotionsState {}

class JunkshopPromotionsOperationInProgress extends JunkshopPromotionsState {}

class JunkshopPromotionsOperationSuccess extends JunkshopPromotionsState {}

class JunkshopPromotionsLoaded extends JunkshopPromotionsState {
  final List<Promotion> promotions;

  const JunkshopPromotionsLoaded(this.promotions);

  @override
  List<Object?> get props => [promotions];
}

class JunkshopPromotionsError extends JunkshopPromotionsState {
  final String message;

  const JunkshopPromotionsError(this.message);

  @override
  List<Object?> get props => [message];
}

class PromotionCreating extends JunkshopPromotionsState {}

class PromotionCreated extends JunkshopPromotionsState {
  final String promotionId;

  const PromotionCreated(this.promotionId);

  @override
  List<Object?> get props => [promotionId];
}

class PromotionUpdating extends JunkshopPromotionsState {}

class PromotionUpdated extends JunkshopPromotionsState {}

class PromotionCancelling extends JunkshopPromotionsState {}

class PromotionCancelled extends JunkshopPromotionsState {}

class PromotionDeleting extends JunkshopPromotionsState {}

class PromotionDeleted extends JunkshopPromotionsState {}

class PromotionOperationError extends JunkshopPromotionsState {
  final String message;

  const PromotionOperationError(this.message);

  @override
  List<Object?> get props => [message];
}
