import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:ecokuha/core/constants/firestore_fields/rating_fields.dart';
import 'package:ecokuha/features/household/domain/entities/collection_rating.dart';

class CollectionRatingModel extends CollectionRating {
  const CollectionRatingModel({
    required super.id,
    required super.collectorRating,
    required super.junkshopRating,
    required super.reviewText,
    required super.timelinessScore,
    required super.professionalismScore,
    required super.createdAt,
    required super.ratedBy,
    required super.postingId,
  });

  factory CollectionRatingModel.fromJson(Map<String, dynamic> json, String id) {
    return CollectionRatingModel(
      id: id,
      collectorRating:
          (json[RatingFields.collectorRating] as num?)?.toDouble() ?? 0.0,
      junkshopRating:
          (json[RatingFields.junkshopRating] as num?)?.toDouble() ?? 0.0,
      reviewText: json[RatingFields.reviewText] as String? ?? '',
      timelinessScore: json[RatingFields.timelinessScore] as int? ?? 0,
      professionalismScore:
          json[RatingFields.professionalismScore] as int? ?? 0,
      createdAt:
          toDateTime(json[RatingFields.createdAt]) ??
          DateTime.now(),
      ratedBy: json[RatingFields.ratedBy] as String? ?? '',
      postingId: json[RatingFields.postingId] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      RatingFields.collectorRating: collectorRating,
      RatingFields.junkshopRating: junkshopRating,
      RatingFields.reviewText: reviewText,
      RatingFields.timelinessScore: timelinessScore,
      RatingFields.professionalismScore: professionalismScore,
      RatingFields.createdAt: Timestamp.fromDate(createdAt),
      RatingFields.ratedBy: ratedBy,
      RatingFields.postingId: postingId,
    };
  }

  CollectionRating toEntity() {
    return CollectionRating(
      id: id,
      collectorRating: collectorRating,
      junkshopRating: junkshopRating,
      reviewText: reviewText,
      timelinessScore: timelinessScore,
      professionalismScore: professionalismScore,
      createdAt: createdAt,
      ratedBy: ratedBy,
      postingId: postingId,
    );
  }
}
