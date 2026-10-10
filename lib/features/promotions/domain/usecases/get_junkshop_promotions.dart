import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/promotion.dart';
import '../entities/promotion_type.dart';
import '../repositories/promotion_repository.dart';

class GetJunkshopPromotions {
  final PromotionRepository repository;

  GetJunkshopPromotions(this.repository);

  Future<Either<Failure, List<Promotion>>> call(
    String junkshopId, {
    PromotionStatus? status,
  }) async {
    return await repository.getJunkshopPromotions(junkshopId, status: status);
  }
}
