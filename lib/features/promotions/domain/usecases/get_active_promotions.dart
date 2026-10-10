import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/promotion.dart';
import '../entities/promotion_type.dart';
import '../repositories/promotion_repository.dart';

class GetActivePromotions {
  final PromotionRepository repository;

  GetActivePromotions(this.repository);

  Future<Either<Failure, List<Promotion>>> call({
    String? materialType,
    PromotionType? promotionType,
    int? limit,
  }) async {
    return await repository.getActivePromotions(
      materialType: materialType,
      promotionType: promotionType,
      limit: limit,
    );
  }
}
