/// Firestore field names for posting documents.
/// Collection path: households/{uid}/postings/{postingId}
class PostingFields {
  // ========== CORE METADATA ==========

  /// Posting document ID (String)
  static const postingId = 'postingId';

  /// Posting status: 'pending' | 'assigned' | 'in_transit' | 'arrived' | 'collecting' | 'completed' | 'cancelled' (String)
  static const status = 'status';

  /// Creation timestamp (Timestamp)
  static const createdAt = 'createdAt';

  /// Last update timestamp (Timestamp)
  static const updatedAt = 'updatedAt';

  /// Scheduled collection date (Timestamp)
  static const scheduledDate = 'scheduledDate';

  /// Scheduled collection time (String)
  static const scheduledTime = 'scheduledTime';

  /// Preferred date of collection (Timestamp)
  static const dateOfCollection = 'dateOfCollection';

  /// Assignment timestamp (Timestamp)
  static const assignedAt = 'assignedAt';

  // ========== RELATIONSHIPS (UIDs) ==========

  /// ID of household who created posting (String)
  static const householdId = 'householdId';

  /// ID of assigned junkshop (String)
  static const assignedJunkshopId = 'assignedJunkshopId';

  /// Name of assigned junkshop (String) - denormalized
  static const assignedJunkshopName = 'assignedJunkshopName';

  /// Address of assigned junkshop (String) - denormalized
  static const assignedJunkshopAddress = 'assignedJunkshopAddress';

  /// Phone of assigned junkshop (String) - denormalized
  static const assignedJunkshopPhone = 'assignedJunkshopPhone';

  /// Rating of assigned junkshop (double) - denormalized
  static const assignedJunkshopRating = 'assignedJunkshopRating';

  /// ID of assigned collector (String)
  static const assignedCollectorId = 'assignedCollectorId';

  /// Name of assigned collector (String) - denormalized
  static const assignedCollectorName = 'assignedCollectorName';

  // ========== DENORMALIZED HOUSEHOLD DATA ==========
  // Copied from household profile for fast list rendering

  /// Household's full name (String)
  static const householdName = 'householdName';

  /// Short address: "City, Province" (String)
  static const addressShort = 'addressShort';

  /// Household's profile image URL (String)
  static const profileImageUrl = 'profileImageUrl';

  /// Household's phone number (String)
  static const householdPhone = 'householdPhone';

  /// Full street address (String)
  static const pickupLocation = 'pickupLocation';

  // ========== LOCATION FOR DISTANCE CALCULATION ==========

  /// Structure: { lat: double, lng: double }
  static const location = 'location';

  /// Latitude inside location map (double)
  static const locationLat = 'lat';

  /// Longitude inside location map (double)
  static const locationLng = 'lng';

  /// Alternative: top-level latitude (double) - legacy support
  static const latitude = 'latitude';

  /// Alternative: top-level longitude (double) - legacy support
  static const longitude = 'longitude';

  /// Alternative location coords map (Map) - legacy support
  static const locationCoords = 'locationCoords';

  // ========== ITEMS & VALUE ==========

  /// Array of waste items (List<Map>)
  /// Each item: { name, quantity, unit, category, estimatedValue, weightKg }
  static const items = 'items';

  /// Array of verified waste items by collector (List<Map>)
  /// Same structure as items, but filled during collection verification
  static const verifiedItems = 'verifiedItems';

  /// Timestamp when items were verified by collector (Timestamp)
  static const verifiedAt = 'verifiedAt';

  /// ID of collector who verified the items (String)
  static const verifiedBy = 'verifiedBy';

  /// Total estimated value in pesos (double)
  static const totalEstimatedValue = 'totalEstimatedValue';

  /// Total verified value after collector verification in pesos (double)
  static const totalVerifiedValue = 'totalVerifiedValue';

  /// Alternative: estimated value (double) - legacy support
  static const estimatedValue = 'estimatedValue';

  /// Alternative: value (double) - legacy support
  static const value = 'value';

  /// Total estimated weight in kg (double)
  static const estimatedTotalWeight = 'estimatedTotalWeight';

  static const categories = 'categories';

  // ========== COLLECTION DETAILS ==========

  static const photos = 'photos';

  static const imageUrls = 'imageUrls';

  /// Special instructions for collector (String)
  static const specialInstructions = 'specialInstructions';

  /// Alternative: notes (String) - legacy support
  static const note = 'note';

  /// Notes or additional information (String)
  static const notes = 'notes';

  static const proofPhotos = 'proofPhotos';

  static const paymentProofUrls = 'paymentProofUrls';

  static const unavailableDates = 'unavailableDates';

  /// Collected at timestamp (Timestamp)
  static const collectedAt = 'collectedAt';

  /// Reviewed at timestamp (Timestamp)
  static const reviewedAt = 'reviewedAt';

  // ========== ITEM SUB-FIELDS ==========
  // Used inside items array maps

  /// Item name (String)
  static const itemName = 'name';

  /// Item quantity (dynamic: int or double)
  static const itemQuantity = 'quantity';

  /// Item unit: 'kg' | 'pcs' | 'bag' | etc. (String)
  static const itemUnit = 'unit';

  /// Item category (String)
  static const itemCategory = 'category';

  /// Item estimated value (double)
  static const itemEstimatedValue = 'estimatedValue';

  /// Item confidence score (double)
  static const itemConfidence = 'confidence';

  /// Item is recyclable flag (bool)
  static const itemIsRecyclable = 'isRecyclable';

  /// Item weight in kg (double)
  static const itemWeightKg = 'weightKg';

  /// Item minimum price (double)
  static const itemPriceMin = 'priceMin';

  /// Item maximum price (double)
  static const itemPriceMax = 'priceMax';

  /// Item base unit (String)
  static const itemBaseUnit = 'baseUnit';

  /// Item condition (String)
  static const itemCondition = 'condition';

  /// Item AI scanned flag (bool)
  static const itemIsAiScanned = 'isAiScanned';

  static const itemImagePaths = 'imagePaths';

  /// Item is cracked condition (bool)
  static const itemIsCracked = 'isCracked';

  /// Item is dented condition (bool)
  static const itemIsDented = 'isDented';

  /// Item is faded condition (bool)
  static const itemIsFaded = 'isFaded';

  /// Item has stickers condition (bool)
  static const itemHasStickers = 'hasStickers';

  /// Item has rust condition (bool)
  static const itemHasRust = 'hasRust';

  /// Item is clean condition (bool)
  static const itemIsClean = 'isClean';

  /// Item is complete condition (bool)
  static const itemIsComplete = 'isComplete';

  /// Item has paint condition (bool)
  static const itemHasPaint = 'hasPaint';

  // ========== NESTED OBJECT FIELDS ==========

  /// Household nested object containing all household details (Map)
  static const household = 'household';

  /// Junkshop nested object containing all junkshop details (Map)
  static const junkshop = 'junkshop';

  /// Collector nested object containing all collector details (Map)
  static const collector = 'collector';

  /// Items nested object with list and summary data (Map)
  static const itemsData = 'items';

  /// Items list within items object (List)
  static const itemsList = 'list';
}
