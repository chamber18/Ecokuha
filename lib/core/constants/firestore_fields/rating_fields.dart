/// Firestore field names for rating-related documents
class RatingFields {
  // Posting-level rating fields
  static const String isRated = 'isRated';
  static const String ratingDeadline = 'ratingDeadline';
  static const String collectorRating = 'collectorRating';
  static const String junkshopRating = 'junkshopRating';

  // Rating subcollection fields
  static const String overallRating = 'overallRating';
  static const String reviewText = 'reviewText';
  static const String timelinessScore = 'timelinessScore';
  static const String professionalismScore = 'professionalismScore';
  static const String createdAt = 'createdAt';
  static const String ratedBy = 'ratedBy';
  static const String postingId = 'postingId';

  // Aggregate stats fields
  static const String totalRatings = 'totalRatings';
  static const String averageRating = 'averageRating';
  static const String sumOfRatings = 'sumOfRatings';
}
