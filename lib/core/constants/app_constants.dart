class AIConstants {
  /// Below this → AiDetectionRejected (unacceptable).
  /// ≥40% → AiDetectionSuccess (acceptable).
  static const double rejectionThreshold = 0.40;

  static const int maxAlternativeMaterials = 5;
}
