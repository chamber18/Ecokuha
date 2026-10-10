import 'dart:io';

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/promotion.dart';
import '../entities/promotion_type.dart';

abstract class PromotionRepository {
  Future<Either<Failure, String>> createPromotion(
    Promotion promotion, {
    File? imageFile,
  });

  Future<Either<Failure, void>> updatePromotion(
    Promotion promotion, {
    File? imageFile,
  });

  Future<Either<Failure, void>> deletePromotion(
    String promotionId,
    String junkshopId,
  );

  Future<Either<Failure, Promotion>> getPromotion(String promotionId);

  Future<Either<Failure, List<Promotion>>> getJunkshopPromotions(
    String junkshopId, {
    PromotionStatus? status,
  });

  Future<Either<Failure, List<Promotion>>> getActivePromotions({
    String? materialType,
    PromotionType? promotionType,
    int? limit,
  });

  Stream<Either<Failure, List<Promotion>>> watchActivePromotions({
    String? materialType,
    PromotionType? promotionType,
  });

  Future<Either<Failure, void>> cancelPromotion(
    String promotionId,
    String junkshopId,
  );
}
