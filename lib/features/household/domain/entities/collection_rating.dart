import 'package:equatable/equatable.dart';

/// Entity representing a rating given by a household for a completed collection
class CollectionRating extends Equatable {
  final String id;
  final double collectorRating;
  final double junkshopRating;
  final String reviewText;
  final int timelinessScore;
  final int professionalismScore;
  final DateTime createdAt;
  final String ratedBy;
  final String postingId;

  const CollectionRating({
    required this.id,
    required this.collectorRating,
    required this.junkshopRating,
    required this.reviewText,
    required this.timelinessScore,
    required this.professionalismScore,
    required this.createdAt,
    required this.ratedBy,
    required this.postingId,
  });

  @override
  List<Object?> get props => [
    id,
    collectorRating,
    junkshopRating,
    reviewText,
    timelinessScore,
    professionalismScore,
    createdAt,
    ratedBy,
    postingId,
  ];
}
