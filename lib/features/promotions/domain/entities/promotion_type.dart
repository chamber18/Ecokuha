enum PromotionType {
  priceBoost;

  String get displayName => 'Price Boost';

  String get description => 'Higher prices for selected materials';

  static PromotionType fromString(String value) {
    if (value.toLowerCase() == 'price_boost' ||
        value.toLowerCase() == 'priceboost') {
      return PromotionType.priceBoost;
    }
    throw ArgumentError('Invalid promotion type: $value');
  }

  String toFirestoreValue() => 'price_boost';
}

enum PromotionStatus {
  draft,
  active,
  expired,
  cancelled;

  String get displayName {
    switch (this) {
      case PromotionStatus.draft:
        return 'Draft';
      case PromotionStatus.active:
        return 'Active';
      case PromotionStatus.expired:
        return 'Expired';
      case PromotionStatus.cancelled:
        return 'Cancelled';
    }
  }

  static PromotionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'draft':
        return PromotionStatus.draft;
      case 'active':
        return PromotionStatus.active;
      case 'expired':
        return PromotionStatus.expired;
      case 'cancelled':
        return PromotionStatus.cancelled;
      default:
        throw ArgumentError('Invalid promotion status: $value');
    }
  }

  String toFirestoreValue() {
    return toString().split('.').last;
  }
}
