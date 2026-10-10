/// Firestore field names for user profile documents across all roles.
/// Used in: households/{uid}, junkshops/{uid}, collectors/{uid}
class UserFields {
  // ========== SHARED PROFILE FIELDS ==========

  /// User's full name (String)
  static const fullName = 'full_name';

  /// Alternative name field (String) - legacy support
  static const name = 'name';

  /// Email address (String)
  static const email = 'email';

  /// User role: 'household' | 'junkshop' | 'collector' (String)
  static const role = 'role';

  /// Profile image URL from Firebase Storage (String)
  static const profileImageUrl = 'profile_image_url';

  /// Alternative: profile picture URL (String) - legacy support
  static const profilePictureUrl = 'profilePictureUrl';

  /// Alternative: avatar URL (String) - legacy support
  static const avatar = 'avatar';

  /// Phone number (String)
  static const phone = 'phone';

  /// Alternative: phone number (String) - snake_case
  static const phoneNumber = 'phone_number';

  /// Email verification status (bool)
  static const isEmailVerified = 'is_email_verified';

  /// Alternative: email verified (bool) - camelCase
  static const emailVerified = 'emailVerified';

  /// Profile completion status (bool)
  static const isProfileComplete = 'is_profile_complete';

  /// Alternative: profile complete (bool) - camelCase
  static const profileComplete = 'profileComplete';

  /// Application status for role approval (String)
  static const applicationStatus = 'application_status';

  /// Last login timestamp (Timestamp/String)
  static const lastLoginAt = 'last_login_at';

  /// Alternative: last login (Timestamp/String) - camelCase
  static const lastLogin = 'lastLogin';

  /// Alternative: last login at (Timestamp/String) - camelCase
  static const lastLoginAtCamel = 'lastLoginAt';

  /// First name (String) - legacy support
  static const firstName = 'firstName';

  /// Alternative: first name (String) - snake_case
  static const firstNameSnake = 'first_name';

  /// Last name (String) - legacy support
  static const lastName = 'lastName';

  /// Alternative: last name (String) - snake_case
  static const lastNameSnake = 'last_name';

  /// User ID field (String)
  static const id = 'id';

  /// Account creation timestamp (Timestamp)
  static const createdAt = 'createdAt';

  /// Alternative: created at (String) - snake_case
  static const createdAtSnake = 'created_at';

  /// Last profile update timestamp (Timestamp)
  static const updatedAt = 'updatedAt';

  // ========== LOCATION FIELDS ==========

  /// Latitude coordinate (double) - top-level field
  static const lat = 'lat';

  /// Longitude coordinate (double) - top-level field
  static const lng = 'lng';

  /// Alternative: latitude (double) - legacy support
  static const latitude = 'latitude';

  /// Alternative: longitude (double) - legacy support
  static const longitude = 'longitude';

  /// Nested location map (`Map<String, dynamic>`)
  /// Contains: {lat, lng, address}
  static const location = 'location';

  /// City name (String)
  static const city = 'city';

  /// Province name (String)
  static const province = 'province';

  /// Full street address (String)
  static const address = 'address';

  /// Address note/label (String) - e.g. "Home", "Work"
  static const note = 'note';

  /// Second/alternative location map (`Map<String, dynamic>`)
  /// Contains: {lat, lng, address, note}
  static const location2 = 'location_2';

  // ========== HOUSEHOLD-SPECIFIC FIELDS ==========

  /// Household user ID (String)
  static const householdId = 'householdId';

  /// Total recycled weight in kg (double)
  static const totalRecycledKg = 'total_recycled_kg';

  /// Number of completed pickups (int)
  static const completedPickups = 'completed_pickups';

  /// Total earnings in pesos (double)
  static const totalEarnings = 'total_earnings';

  // ========== JUNKSHOP-SPECIFIC FIELDS ==========

  /// Nested junkshop profile data (Map)
  static const junkshopProfile = 'junkshop_profile';

  /// Business name (String)
  static const businessName = 'business_name';

  /// Business address (String)
  static const businessAddress = 'businessAddress';

  /// Business registration number (String)
  static const businessRegistration = 'business_registration';

  /// Junkshop rating (double)
  static const rating = 'rating';

  // ========== COLLECTOR-SPECIFIC FIELDS ==========

  /// Nested collector profile data (Map)
  static const collectorProfile = 'collector_profile';

  /// Number of application attempts (int)
  static const applicationAttempts = 'application_attempts';

  /// Rejection reason text (String)
  static const rejectionReason = 'rejection_reason';

  /// Rejection timestamp (String/Timestamp)
  static const rejectedAt = 'rejected_at';

  /// ID of junkshop this collector is assigned to (String)
  static const assignedJunkshopId = 'assigned_junkshop_id';

  /// Collector approval status: 'pending' | 'approved' | 'rejected' (String)
  static const approvalStatus = 'approval_status';

  /// Collector's display name (String)
  static const collectorName = 'collector_name';

  /// Vehicle type (String)
  static const vehicleType = 'vehicle_type';

  /// License plate number (String)
  static const licensePlate = 'license_plate';
}
