import 'package:equatable/equatable.dart';
import 'promotion_type.dart';

class Promotion extends Equatable {
  final String id;
  final String junkshopId;
  final String junkshopName;
  final String title;
  final String description;
  final List<String> materials;
  final PromotionType type;
  final PromotionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? imageUrl;
  final PriceBoostDetails priceBoostDetails;

  const Promotion({
    required this.id,
    required this.junkshopId,
    required this.junkshopName,
    required this.title,
    required this.description,
    required this.materials,
    required this.type,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.priceBoostDetails,
    this.updatedAt,
    this.imageUrl,
  });

  bool get isActive {
    final now = DateTime.now();
    return status == PromotionStatus.active &&
        now.isAfter(startDate) &&
        now.isBefore(endDate);
  }

  bool get isExpired {
    return status == PromotionStatus.expired || DateTime.now().isAfter(endDate);
  }

  Promotion copyWith({
    String? id,
    String? junkshopId,
    String? junkshopName,
    String? title,
    String? description,
    List<String>? materials,
    PromotionType? type,
    PromotionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
    PriceBoostDetails? priceBoostDetails,
  }) {
    return Promotion(
      id: id ?? this.id,
      junkshopId: junkshopId ?? this.junkshopId,
      junkshopName: junkshopName ?? this.junkshopName,
      title: title ?? this.title,
      description: description ?? this.description,
      materials: materials ?? this.materials,
      type: type ?? this.type,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      priceBoostDetails: priceBoostDetails ?? this.priceBoostDetails,
    );
  }

  @override
  List<Object?> get props => [
    id,
    junkshopId,
    junkshopName,
    title,
    description,
    materials,
    type,
    status,
    startDate,
    endDate,
    createdAt,
    updatedAt,
    imageUrl,
    priceBoostDetails,
  ];
}

class PriceBoostDetails extends Equatable {
  final double boostPercentage;

  const PriceBoostDetails({required this.boostPercentage});

  @override
  List<Object?> get props => [boostPercentage];
}
