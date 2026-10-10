import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/promotion.dart';
import '../repositories/promotion_repository.dart';

class CreatePromotion {
  final PromotionRepository repository;

  CreatePromotion(this.repository);

  Future<Either<Failure, String>> call(Promotion promotion) async {
    return await repository.createPromotion(promotion);
  }
}
