import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/promotion_type.dart';

class PromotionModel extends Promotion {
  const PromotionModel({
    required super.id,
    required super.junkshopId,
    required super.junkshopName,
    required super.title,
    required super.description,
    required super.type,
    required super.materials,
    required super.status,
    required super.startDate,
    required super.endDate,
    required super.createdAt,
    required super.priceBoostDetails,
    super.updatedAt,
    super.imageUrl,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: json['id'].toString(),
      junkshopId: json['junkshopId'] as String,
      junkshopName: json['junkshopName'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String,
      type: PromotionType.priceBoost,
      materials: List<String>.from(json['materials'] as List? ?? []),
      status: PromotionStatus.fromString(json['status'] as String? ?? 'active'),
      startDate: toDateTime(json['startDate']) ?? DateTime.now(),
      endDate: toDateTime(json['endDate']) ?? DateTime.now(),
      createdAt: toDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: toDateTime(json['updatedAt']),
      imageUrl: json['imageUrl'] as String?,
      priceBoostDetails: PriceBoostDetailsModel.fromJson(
        Map<String, dynamic>.from(json['priceBoostDetails'] as Map),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'junkshopId': junkshopId,
      'junkshopName': junkshopName,
      'title': title,
      'description': description,
      'type': type.toFirestoreValue(),
      'materials': materials,
      'status': status.toFirestoreValue(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (imageUrl != null) 'imageUrl': imageUrl,
      'priceBoostDetails': {
        'boostPercentage': priceBoostDetails.boostPercentage,
      },
    };
  }

  factory PromotionModel.fromEntity(Promotion promotion) {
    return PromotionModel(
      id: promotion.id,
      junkshopId: promotion.junkshopId,
      junkshopName: promotion.junkshopName,
      title: promotion.title,
      description: promotion.description,
      type: promotion.type,
      materials: promotion.materials,
      status: promotion.status,
      startDate: promotion.startDate,
      endDate: promotion.endDate,
      createdAt: promotion.createdAt,
      updatedAt: promotion.updatedAt,
      imageUrl: promotion.imageUrl,
      priceBoostDetails: promotion.priceBoostDetails,
    );
  }
}

class PriceBoostDetailsModel extends PriceBoostDetails {
  const PriceBoostDetailsModel({required super.boostPercentage});

  factory PriceBoostDetailsModel.fromJson(Map<String, dynamic> json) {
    return PriceBoostDetailsModel(
      boostPercentage: (json['boostPercentage'] as num).toDouble(),
    );
  }
}
