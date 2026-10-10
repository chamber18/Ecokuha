import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/promotion_type.dart';
import '../../domain/repositories/promotion_repository.dart';
import '../datasources/promotion_remote_datasource.dart';
import '../models/promotion_model.dart';

class PromotionRepositoryImpl implements PromotionRepository {
  final PromotionRemoteDataSource remoteDataSource;

  PromotionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, String>> createPromotion(
    Promotion promotion, {
    File? imageFile,
  }) async {
    try {
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _uploadImage(imageFile, promotion.junkshopId);
      }

      final promotionWithImage = promotion.copyWith(imageUrl: imageUrl);
      final model = PromotionModel.fromEntity(promotionWithImage);
      final id = await remoteDataSource.createPromotion(model);
      return Right(id);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePromotion(
    Promotion promotion, {
    File? imageFile,
  }) async {
    try {
      String? imageUrl = promotion.imageUrl;

      if (imageFile != null) {
        // Delete old image if exists
        if (promotion.imageUrl != null) {
          await _deleteImage(promotion.imageUrl!);
        }
        // Upload new image
        imageUrl = await _uploadImage(imageFile, promotion.junkshopId);
      }

      final promotionWithImage = promotion.copyWith(imageUrl: imageUrl);
      final model = PromotionModel.fromEntity(promotionWithImage);
      await remoteDataSource.updatePromotion(model);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<String> _uploadImage(File imageFile, String junkshopId) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadPublicFile(
      bucket: 'promotions',
      path: '$junkshopId/$fileName',
      file: imageFile,
    );
  }

  Future<void> _deleteImage(String imageUrl) async {
    try {
      const marker = '/object/public/promotions/';
      final idx = imageUrl.indexOf(marker);
      if (idx < 0) return;
      var path = imageUrl.substring(idx + marker.length);
      final q = path.indexOf('?');
      if (q >= 0) path = path.substring(0, q);
      await deleteStorageObject('promotions', Uri.decodeComponent(path));
    } catch (e) {
      // Ignore deletion errors
    }
  }

  @override
  Future<Either<Failure, void>> deletePromotion(
    String promotionId,
    String junkshopId,
  ) async {
    try {
      // Fetch the promotion first to get its imageUrl for Storage cleanup
      final imageUrl = await remoteDataSource.getPromotionImageUrl(promotionId);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _deleteImage(imageUrl);
      }

      await remoteDataSource.deletePromotion(promotionId, junkshopId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Promotion>> getPromotion(String promotionId) async {
    try {
      final promotion = await remoteDataSource.getPromotion(promotionId);
      return Right(promotion);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Promotion>>> getJunkshopPromotions(
    String junkshopId, {
    PromotionStatus? status,
  }) async {
    try {
      final promotions = await remoteDataSource.getJunkshopPromotions(
        junkshopId,
        status: status,
      );
      return Right(promotions);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Promotion>>> getActivePromotions({
    String? materialType,
    PromotionType? promotionType,
    int? limit,
  }) async {
    try {
      final promotions = await remoteDataSource.getActivePromotions(
        materialType: materialType,
        promotionType: promotionType,
        limit: limit,
      );
      return Right(promotions);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<Promotion>>> watchActivePromotions({
    String? materialType,
    PromotionType? promotionType,
  }) {
    try {
      return remoteDataSource
          .watchActivePromotions(
            materialType: materialType,
            promotionType: promotionType,
          )
          .map((promotions) => Right<Failure, List<Promotion>>(promotions))
          .handleError(
            (error) =>
                Left<Failure, List<Promotion>>(ServerFailure(error.toString())),
          );
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Future<Either<Failure, void>> cancelPromotion(
    String promotionId,
    String junkshopId,
  ) async {
    try {
      await remoteDataSource.cancelPromotion(promotionId, junkshopId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
