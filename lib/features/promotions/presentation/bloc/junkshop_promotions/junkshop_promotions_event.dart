import 'dart:io';

import 'package:equatable/equatable.dart';
import '../../../domain/entities/promotion.dart';
import '../../../domain/entities/promotion_type.dart';

abstract class JunkshopPromotionsEvent extends Equatable {
  const JunkshopPromotionsEvent();

  @override
  List<Object?> get props => [];
}

class LoadJunkshopPromotions extends JunkshopPromotionsEvent {
  final String junkshopId;
  final PromotionStatus? statusFilter;

  const LoadJunkshopPromotions({required this.junkshopId, this.statusFilter});

  @override
  List<Object?> get props => [junkshopId, statusFilter];
}

class CreatePromotion extends JunkshopPromotionsEvent {
  final Promotion promotion;
  final File? imageFile;

  const CreatePromotion(this.promotion, this.imageFile);

  @override
  List<Object?> get props => [promotion, imageFile];
}

class UpdatePromotion extends JunkshopPromotionsEvent {
  final Promotion promotion;
  final File? imageFile;

  const UpdatePromotion(this.promotion, this.imageFile);

  @override
  List<Object?> get props => [promotion, imageFile];
}

class CancelExistingPromotion extends JunkshopPromotionsEvent {
  final String promotionId;
  final String junkshopId;

  const CancelExistingPromotion({
    required this.promotionId,
    required this.junkshopId,
  });

  @override
  List<Object?> get props => [promotionId, junkshopId];
}

class DeleteExistingPromotion extends JunkshopPromotionsEvent {
  final String promotionId;
  final String junkshopId;

  const DeleteExistingPromotion({
    required this.promotionId,
    required this.junkshopId,
  });

  @override
  List<Object?> get props => [promotionId, junkshopId];
}
