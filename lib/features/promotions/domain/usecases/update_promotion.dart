import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/promotion.dart';
import '../repositories/promotion_repository.dart';

class UpdatePromotion {
  final PromotionRepository repository;

  UpdatePromotion(this.repository);

  Future<Either<Failure, void>> call(Promotion promotion) async {
    return await repository.updatePromotion(promotion);
  }
}
