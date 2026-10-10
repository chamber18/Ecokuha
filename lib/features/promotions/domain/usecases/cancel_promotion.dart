import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/promotion_repository.dart';

class CancelPromotion {
  final PromotionRepository repository;

  CancelPromotion(this.repository);

  Future<Either<Failure, void>> call(
    String promotionId,
    String junkshopId,
  ) async {
    return await repository.cancelPromotion(promotionId, junkshopId);
  }
}
