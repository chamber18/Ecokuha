import 'package:flutter/material.dart';
import 'dart:io' show File;
import 'dart:math' show sin, cos, sqrt, asin;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:ecokuha/core/di/service_locator.dart';
import 'package:ecokuha/features/ai/data/models/waste_detection_model.dart';
import 'square_camera_screen.dart';
import 'package:ecokuha/features/household/data/models/posting_model.dart';
import 'package:ecokuha/features/household/data/repositories/household_posting_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_helpers.dart' hide supabase;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/constants/firestore_fields/index.dart';
import '../utils/posting_helpers.dart';
import '../../data/models/detected_item.dart';
import '../../../messaging/data/repositories/chat_repository.dart';
import '../../../messaging/data/models/conversation_model.dart';
import '../../../messaging/data/services/conversation_sync_service.dart';
import '../../../../core/services/posting_upload_service.dart';
import '../widgets/junkshop_selection_sheet.dart';
import '../widgets/address_selection_sheet.dart';
import 'junkshop_profile_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

// Helper class for displaying rule details
class RuleDetail {
  final String label;
  final String value;
  final bool isHighlight;

  RuleDetail({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });
}

class PostItemsScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  final bool editMode;
  final String? postingId;
  final Map<String, dynamic>? postingData;
  final bool isRepost;
  final String? preSelectedJunkshopId;
  final String? promotionId;
  final Map<String, dynamic>? promotionData;

  const PostItemsScreen({
    super.key,
    this.onBackToHome,
    this.editMode = false,
    this.postingId,
    this.postingData,
    this.isRepost = false,
    this.preSelectedJunkshopId,
    this.promotionId,
    this.promotionData,
  });

  @override
  State<PostItemsScreen> createState() => _PostItemsScreenState();
}

class _PostItemsScreenState extends State<PostItemsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _instructionsController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  /// Round double to 2 decimal places to avoid floating-point precision issues
  double _roundToTwoDecimals(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  final List<DetectedItem> _detectedItems = [];
  final List<String> _scannedImages = []; // Store all scanned images
  final Map<String, Map<String, double>> _imageBoundingBoxes =
      {}; // imagePath -> bbox
  final Map<String, String> _imageLabels = {}; // imagePath -> material label

  final bool _isScanning = false;
  final bool _isCreatingPosting = false; // Loading state for posting creation
  bool _hasActiveCollection = false; // Flag for active collection warning
  bool _isCheckingActiveCollection = true; // Loading state for check
  String? _activeCollectionStatus; // Store the status of active collection
  String? _activeCollectionId; // Store the ID of active collection
  Map<String, dynamic>? _activePostingData; // Full data map for edit navigation

  // Manual posting state
  List<dynamic>?
  _materialCatalog; // Loaded from assets/config/material_prices.json
  final TextEditingController _manualQtyController = TextEditingController(
    text: '1',
  );

  // Junkshop and Location state
  List<Map<String, dynamic>> _availableJunkshops = [];
  Map<String, dynamic>? _selectedJunkshop;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _estimatedWeightController =
      TextEditingController();

  // Business Controls state (from selected junkshop)
  double? _baseFee;
  double? _costPerKm;
  double? _maxWeightPerValueRatio;
  double? _serviceRadius;
  String? _operatingHours;
  Set<String> _acceptedCategories = {};
  Map<String, dynamic> _validationResults = {}; // Store validation checks

  // Slide to delete state
  String? _openItemKey; // Track which item is currently slid open

  // Saved addresses state
  List<Map<String, dynamic>> _savedAddresses = [];
  String _selectedAddressKey =
      'manual'; // 'manual', 'location', or 'location_2'
  bool _isLoadingAddresses = true;

  // Promotion state
  String? _activePromotionId;
  List<String> _promotionMaterials = [];
  double _promotionBoostPercentage = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Add listener to weight controller for real-time validation
    _estimatedWeightController.addListener(() {
      if (_selectedJunkshop != null) {
        _validatePosting();
      }
    });

    // Initialize location and available junkshops for pricing context
    _locationController.text = '';

    // Load saved addresses first, then junkshops (so we have coordinates for distance calculation)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // Check for active collections only if not in edit mode
        if (!widget.editMode) {
          await _checkForActiveCollection();
        } else {
          setState(() => _isCheckingActiveCollection = false);
        }

        await _loadSavedAddresses();
        // Initialize promotion data BEFORE loading junkshops so pre-selection works
        if (mounted &&
            widget.promotionId != null &&
            widget.promotionData != null) {
          _initializePromotionData();
        }
        // After addresses are loaded, load junkshops with coordinates
        if (mounted) {
          await _loadAvailableJunkshops();
        }
        // If in edit mode, load the existing posting data
        if (mounted && widget.editMode && widget.postingData != null) {
          await _loadExistingPostingData();
        }
      }
    });
  }

  Future<void> _checkForActiveCollection() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isCheckingActiveCollection = false);
      return;
    }

    try {
      final activeStatuses = [
        'pending',
        'Pending',
        'assigned',
        'Assigned',
        'scheduled',
        'Scheduled',
        'rescheduled',
        'Rescheduled',
        'in_progress',
        'In Progress',
        'En Route',
        'en_route',
        'in_transit',
        'arrived',
        'collecting',
        'queued',
        'collected',
      ];

      final rows = await Supabase.instance.client
          .from('postings')
          .select()
          .eq('household_id', user.id)
          .inFilter('status', activeStatuses)
          .limit(1);

      if (rows.isNotEmpty) {
        _setActive(rowToDoc('postings', rows.first));
        return;
      }
      setState(() {
        _hasActiveCollection = false;
        _activeCollectionStatus = null;
        _activeCollectionId = null;
        _isCheckingActiveCollection = false;
      });
    } catch (e) {
      if (kDebugMode) print('Error checking for active collection: $e');
      setState(() => _isCheckingActiveCollection = false);
    }
  }

  void _setActive(Map<String, dynamic> data) {
    final status = data[PostingFields.status]?.toString() ?? '';
    final id = data['id']?.toString();
    setState(() {
      _hasActiveCollection = true;
      _activeCollectionStatus = status;
      _activeCollectionId = id;
      _activePostingData = {...data, 'id': id};
      _isCheckingActiveCollection = false;
    });
  }
  Future<void> _loadExistingPostingData() async {
    if (kDebugMode) print('📝 Loading existing posting data for editing');
    final data = widget.postingData!;

    // First, load synchronous data in setState
    setState(() {
      // Load items - handle both new nested and legacy flat structure
      List<dynamic> items = [];

      final itemsData = data[PostingFields.items];
      if (itemsData is Map) {
        // New nested structure: items.list
        items = (itemsData[PostingFields.itemsList] ?? []) as List<dynamic>;
      } else if (itemsData is List) {
        // Legacy flat structure
        items = itemsData;
      }

      _detectedItems.clear();
      for (var item in items) {
        final itemMap = item as Map<String, dynamic>;
        final detectedItem = DetectedItem(
          name: itemMap[PostingFields.itemName] ?? 'Unknown',
          category: itemMap[PostingFields.itemCategory] ?? 'other',
          quantity: itemMap[PostingFields.itemQuantity] ?? 1,
          unit: itemMap[PostingFields.itemUnit] ?? 'pcs',
          estimatedValue: (itemMap[PostingFields.itemEstimatedValue] ?? 0.0)
              .toDouble(),
          confidence: (itemMap[PostingFields.itemConfidence] ?? 0.8).toDouble(),
          isRecyclable: itemMap[PostingFields.itemIsRecyclable] ?? true,
          imagePaths:
              (itemMap[PostingFields.itemImagePaths] as List<dynamic>?)
                  ?.cast<String>() ??
              [],
          isAiScanned: itemMap[PostingFields.itemIsAiScanned] ?? false,
          priceMin: (itemMap[PostingFields.itemPriceMin] as num?)?.toDouble(),
          priceMax: (itemMap[PostingFields.itemPriceMax] as num?)?.toDouble(),
          baseUnit: itemMap[PostingFields.itemBaseUnit] as String?,
          promotionBoostPercentage:
              (itemMap['promotionBoostPercentage'] as num?)?.toDouble(),
          promotionId: itemMap['promotionId'] as String?,
        );

        // Set active promotion from first item with promotionId
        if (detectedItem.promotionId != null && _activePromotionId == null) {
          _activePromotionId = detectedItem.promotionId;
          _promotionBoostPercentage =
              detectedItem.promotionBoostPercentage ?? 0.0;
        }

        _detectedItems.add(detectedItem);
      }

      // Load scanned images from items (use Set to avoid duplicates)
      final uniqueImages = <String>{};
      for (var item in _detectedItems) {
        uniqueImages.addAll(item.imagePaths);
      }
      _scannedImages.clear();
      _scannedImages.addAll(uniqueImages);

      // Load location/address - check nested household object first, then fallback to top-level
      final householdData =
          data[PostingFields.household] as Map<String, dynamic>?;
      _locationController.text =
          householdData?['address'] ??
          data[PostingFields.pickupLocation] ??
          data[PostingFields.addressShort] ??
          '';

      debugPrint(
        '[Repost] Loaded household address: ${_locationController.text}',
      );

      // Load selected junkshop if available - check nested junkshop object first
      final junkshopData =
          data[PostingFields.junkshop] as Map<String, dynamic>?;
      final junkshopId =
          junkshopData?['id'] ??
          junkshopData?['uid'] ??
          data[PostingFields.assignedJunkshopId];

      debugPrint('[Repost] Junkshop nested data: $junkshopData');
      debugPrint('[Repost] Extracted junkshop ID: $junkshopId');
      if (junkshopId != null) {
        debugPrint('[Repost] Looking for junkshop with ID: $junkshopId');
        debugPrint(
          '[Repost] Available junkshops: ${_availableJunkshops.map((js) => '${js['name']} (id=${js['id']}, uid=${js['uid']})').join(', ')}',
        );

        try {
          final foundJunkshop = _availableJunkshops.firstWhere(
            (js) => js['id'] == junkshopId || js['uid'] == junkshopId,
          );
          _selectedJunkshop = foundJunkshop;
          debugPrint(
            '[Repost] ✅ Pre-selected junkshop: ${_selectedJunkshop!['name']} (ID: $junkshopId)',
          );
        } catch (e) {
          debugPrint(
            '[Repost] ⚠️ Could not find junkshop with ID: $junkshopId',
          );
          _selectedJunkshop = null;
        }
      }

      // Load instructions
      _instructionsController.text =
          data[PostingFields.specialInstructions] ?? '';

      // Load estimated total weight - handle both nested and legacy structure
      double? estimatedWeight;
      if (itemsData is Map) {
        // New nested structure
        estimatedWeight = itemsData[PostingFields.estimatedTotalWeight];
      } else {
        // Legacy flat structure
        estimatedWeight = data[PostingFields.estimatedTotalWeight];
      }

      if (estimatedWeight != null) {
        _estimatedWeightController.text = estimatedWeight.toString();
      } else {
        // Calculate from items if not stored
        final totalWeight = _getTotalWeightFromItems();
        if (totalWeight > 0) {
          _estimatedWeightController.text = totalWeight.toStringAsFixed(2);
        }
      }
    });

    // Load business controls and material catalog for the selected junkshop
    if (_selectedJunkshop != null) {
      await _fetchBusinessControls();
      await _ensureMaterialCatalogLoaded();
      debugPrint('[Repost] ✅ Loaded business controls and material catalog');
    }

    // Then, load promotion materials asynchronously if needed
    if (_activePromotionId != null && _selectedJunkshop != null) {
      await _loadPromotionMaterialNames();
      debugPrint('[Repost] ✅ Loaded promotion materials for junkshop');

      // Recalculate boosted prices for items with promotion
      if (_promotionBoostPercentage > 0) {
        setState(() {
          final boostMultiplier = 1 + (_promotionBoostPercentage / 100);
          for (var item in _detectedItems) {
            if (item.promotionId != null &&
                item.priceMin != null &&
                item.priceMax != null) {
              item.boostedPriceMin = item.priceMin! * boostMultiplier;
              item.boostedPriceMax = item.priceMax! * boostMultiplier;
              debugPrint(
                '[Repost] ✅ Recalculated boosted price for ${item.name}: ${item.boostedPriceMin} - ${item.boostedPriceMax}',
              );
            }
          }
        });
      }
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'queued':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_transit':
      case 'en_route':
      case 'en route':
        return 'En Route';
      case 'arrived':
      case 'collecting':
        return 'Collecting';
      case 'completed':
        return 'Completed';
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      default:
        return status;
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _pulseController.dispose();
    _manualQtyController.dispose();
    _locationController.dispose();
    _estimatedWeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isCheckingActiveCollection
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : (!widget.editMode && _hasActiveCollection)
          ? _buildActiveCollectionBlockScreen()
          : Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            // Step 1: Location Selection (Always visible)
                            _buildLocationSection(),
                            // Step 2: Junkshop Selection (Always visible)
                            _buildJunkshopSection(),

                            // Step 3: Upload/Scan Section (enabled after prerequisites)
                            _buildUploadSection(),

                            // Detected Items and Actions
                            if (_detectedItems.isNotEmpty && !_isScanning) ...[
                              _buildDetectedItemsSection(),
                              _buildTotalValueSection(),
                              _buildPostButton(),
                            ],
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // AI Scanner Modal Overlay
                // Loading Overlay when creating posting
                if (_isCreatingPosting) _buildLoadingOverlay(),
              ],
            ),
    );
  }

  Widget _buildActiveCollectionBlockScreen() {
    final isPending = _activeCollectionStatus?.toLowerCase() == 'pending';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isPending
                    ? AppColors.warningColor.withValues(alpha: 0.1)
                    : AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPending
                    ? Icons.edit_note_rounded
                    : Icons.local_shipping_rounded,
                size: 64,
                color: isPending
                    ? AppColors.warningColor
                    : AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Active Collection in Progress',
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              isPending
                  ? 'You have a pending collection request. You can edit it if you forgot something, or wait until it\'s completed before posting a new one.'
                  : 'Your collection is currently ${_formatStatus(_activeCollectionStatus ?? '')}. Please wait until it is completed before creating a new posting.\n\nThis prevents duplicate collections and confusion.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 32),

            // Action buttons
            if (isPending) ...[
              // Edit button for pending posts
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to edit mode
                    Navigator.pushReplacementNamed(
                      context,
                      '/household-home',
                      arguments: {
                        'initialIndex': 1,
                        'mode': 'edit',
                        'postingId': _activeCollectionId,
                        'postingData': _activePostingData,
                      },
                    );
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit Pending Post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // View collection button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate back to household dashboard and switch to Track tab
                  Navigator.pushReplacementNamed(
                    context,
                    '/household-home',
                    arguments: {'initialIndex': 2}, // Track tab
                  );
                },
                icon: const Icon(Icons.track_changes_rounded),
                label: const Text('View Collection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasPrerequisites() {
    return _selectedAddressKey.isNotEmpty && _selectedJunkshop != null;
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.successColor,
            AppColors.successColor.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.successColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.padding2xl,
            vertical: AppDimensions.paddingLg,
          ),
          child: Row(
            children: [
              // Title and progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.editMode
                          ? 'Edit Materials Post'
                          : 'Post Materials',
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pickup Location',
                  style: AppTextStyles.h4.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingAddresses)
            Row(
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading addresses...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            )
          else
            InkWell(
              onTap: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  isDismissible: true,
                  enableDrag: true,
                  builder: (context) => AddressSelectionSheet(
                    savedAddresses: _savedAddresses,
                    selectedAddressKey: _selectedAddressKey,
                    onAddressSelected: (key, address) {
                      setState(() {
                        if (key != null) {
                          _selectedAddressKey = key;
                        }
                        if (key == 'manual' && address != null) {
                          _locationController.text = address;
                        } else if (key != null) {
                          final selectedAddress = _savedAddresses.firstWhere(
                            (addr) => addr['key'] == key,
                            orElse: () => {},
                          );
                          if (selectedAddress.isNotEmpty) {
                            _locationController.text =
                                selectedAddress['address'] ?? '';
                          }
                        }
                        // Re-load junkshops when address changes
                        _loadAvailableJunkshops();
                        // Re-validate if junkshop is already selected
                        if (_selectedJunkshop != null) {
                          Future.microtask(() => _validatePosting());
                        }
                      });
                    },
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAddressKey != 'manual'
                                ? (_savedAddresses.firstWhere(
                                        (addr) =>
                                            addr['key'] == _selectedAddressKey,
                                        orElse: () => {
                                          'label': 'Select pickup address',
                                        },
                                      )['label']
                                      as String)
                                : _selectedAddressKey == 'manual' &&
                                      _locationController.text.isNotEmpty
                                ? 'Custom Address'
                                : 'Select pickup address',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _locationController.text.isNotEmpty
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_locationController.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _locationController.text,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJunkshopSection() {
    final isLocked = widget.editMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isLocked ? 'Junkshop' : 'Select Junkshop',
                  style: AppTextStyles.h4.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isLocked)
                const Tooltip(
                  message: 'Junkshop cannot be changed after posting',
                  child: Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                IconButton(
                  onPressed: _showJunkshopRules,
                  icon: const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.primaryGreen,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'See junkshop rules',
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLocked && _selectedJunkshop != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedJunkshop!['name'] as String,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cannot be changed once submitted',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          if (!isLocked && _availableJunkshops.isNotEmpty)
            InkWell(
              onTap: () async {
                await showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  isDismissible: true,
                  enableDrag: true,
                  builder: (context) => JunkshopSelectionSheet(
                    junkshops: _availableJunkshops,
                    selectedJunkshop: _selectedJunkshop,
                    onJunkshopSelected: (junkshop) async {
                      if (junkshop != null &&
                          !(junkshop['isAvailable'] as bool? ?? true)) {
                        return;
                      }

                      setState(() {
                        _selectedJunkshop = junkshop;
                        _materialCatalog = null;
                      });

                      await _fetchBusinessControls();
                      await _ensureMaterialCatalogLoaded();
                      await _validateItemsAgainstJunkshop();
                    },
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedJunkshop != null
                                ? (_selectedJunkshop!['name'] as String)
                                : 'Select a junkshop',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _selectedJunkshop != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_selectedJunkshop != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 12,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${(_selectedJunkshop!['distance'] as double).toStringAsFixed(1)}km away',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          if (!isLocked && _availableJunkshops.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'No nearby junkshops found for the current location. You can still proceed; base prices will be used.',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 13,
                        color: Colors.orange[900],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<List<String>> _loadPromotionMaterialNames() async {
    if (_selectedJunkshop == null || _promotionMaterials.isEmpty) {
      return [];
    }

    try {
      final junkshopId = _selectedJunkshop!['uid'] ?? _selectedJunkshop!['id'];
      final rows = await Supabase.instance.client
          .from('junkshop_materials')
          .select('id, name')
          .eq('junkshop_id', junkshopId.toString())
          .inFilter('id', _promotionMaterials);

      return rows
          .map((row) => row['name'] as String? ?? row['id'].toString())
          .toList();    } catch (e) {
      debugPrint('[Promotion] Error loading material names: $e');
      return [];
    }
  }

  Widget _buildUploadSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        children: [
          _buildUploadBox(),
          if (_scannedImages.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildScannedImagesCarousel(),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadBox() {
    final hasPrerequisites = _hasPrerequisites();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Step Badge
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: hasPrerequisites
                    ? AppColors.primaryGreen
                    : AppColors.textSecondary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Upload Items',
              style: AppTextStyles.h4.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: hasPrerequisites
                    ? AppColors.textPrimary
                    : AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hasPrerequisites
              ? 'Scan items with AI or add them manually'
              : 'Complete steps above to start adding items',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Two Button Layout: Scan & Manual
        Row(
          children: [
            // Scan Button (Primary)
            Expanded(
              child: Opacity(
                opacity: hasPrerequisites ? 1.0 : 0.5,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: hasPrerequisites
                        ? LinearGradient(
                            colors: [
                              AppColors.successColor,
                              AppColors.successColor.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: hasPrerequisites
                        ? null
                        : AppColors.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: hasPrerequisites
                        ? [
                            BoxShadow(
                              color: AppColors.successColor.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: hasPrerequisites ? _showScanOptions : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Scan Items',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Manual Button (Secondary)
            Expanded(
              child: Opacity(
                opacity: hasPrerequisites ? 1.0 : 0.5,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasPrerequisites
                          ? AppColors.borderLight
                          : AppColors.textSecondary.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: hasPrerequisites ? _openManualAddItem : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            color: hasPrerequisites
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Manual Entry',
                            style: TextStyle(
                              color: hasPrerequisites
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScannedImagesCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              Icons.photo_library_rounded,
              color: AppColors.successColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Uploaded Images (${_scannedImages.length})',
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Horizontal scrollable carousel
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _scannedImages.length,
            itemBuilder: (context, index) {
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.successColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Image (file path vs asset path) - Tappable for full-screen view
                      GestureDetector(
                        onTap: () => _showFullScreenImage(index),
                        child: Builder(
                          builder: (context) {
                            final path = _scannedImages[index];
                            final isAsset = path.startsWith('assets/');
                            final isUrl =
                                path.startsWith('http://') ||
                                path.startsWith('https://');

                            Widget imageWidget;
                            if (isAsset) {
                              imageWidget = Image.asset(
                                path,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              );
                            } else if (isUrl) {
                              imageWidget = Image.network(
                                path,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              );
                            } else {
                              imageWidget = Image.file(
                                File(path),
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              );
                            }
                            return imageWidget;
                          },
                        ),
                      ),
                      // Bounding box overlay - drawn after image
                      Builder(
                        builder: (context) {
                          final path = _scannedImages[index];
                          if (kDebugMode) {
                            print('[BBox UI] Checking bbox for path: $path');
                          }
                          if (kDebugMode) {
                            print(
                              '[BBox UI] Has bbox: ${_imageBoundingBoxes.containsKey(path)}',
                            );
                          }
                          if (kDebugMode) {
                            print(
                              '[BBox UI] Total bboxes in map: ${_imageBoundingBoxes.length}',
                            );
                          }
                          if (_imageBoundingBoxes.containsKey(path)) {
                            if (kDebugMode) {
                              print(
                                '[BBox UI] Found bbox: ${_imageBoundingBoxes[path]}',
                              );
                            }
                            return Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: BoundingBoxPainter(
                                    boundingBox: _imageBoundingBoxes[path]!,
                                    label: _imageLabels[path] ?? '',
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // Remove button
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            onTap: () => _removeScannedImage(index),
                            borderRadius: BorderRadius.circular(15),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // AI Detection overlay with animation
                      if (_isScanning && index == _scannedImages.length - 1)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Rotating scanner effect
                                    SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(
                                        color: Colors.red,
                                        strokeWidth: 4,
                                      ),
                                    ),
                                    // AI icon
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.red,
                                      size: 28,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'AI Detecting...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Analyzing object',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Scanning status
        if (_isScanning)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI SCANNING...',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.spacing12),
                Text(
                  'Identifying waste items and calculating values',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _removeScannedImage(int index) {
    setState(() {
      _scannedImages.removeAt(index);
      // If this was the only image, clear detected items too
      if (_scannedImages.isEmpty) {
        _detectedItems.clear();
        _estimatedWeightController.clear();
      }
    });
  }

  // Show full-screen image viewer
  void _showFullScreenImage(int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // PageView for image swiping
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: _scannedImages.length,
              itemBuilder: (context, index) {
                final path = _scannedImages[index];
                final isAsset = path.startsWith('assets/');
                final isUrl =
                    path.startsWith('http://') || path.startsWith('https://');

                Widget imageWidget;
                if (isAsset) {
                  imageWidget = Image.asset(path, fit: BoxFit.contain);
                } else if (isUrl) {
                  imageWidget = Image.network(path, fit: BoxFit.contain);
                } else {
                  imageWidget = Image.file(File(path), fit: BoxFit.contain);
                }

                return Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Stack(
                      children: [
                        imageWidget,
                        // Bounding box overlay in full screen
                        if (_imageBoundingBoxes.containsKey(path))
                          Positioned.fill(
                            child: CustomPaint(
                              painter: BoundingBoxPainter(
                                boundingBox: _imageBoundingBoxes[path]!,
                                label: _imageLabels[path] ?? '',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            // Image counter
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${initialIndex + 1} / ${_scannedImages.length}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectedItemsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detected Items',
            style: AppTextStyles.h5.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing20),
          ..._detectedItems.map((item) => _buildDetectedItemCard(item)),
        ],
      ),
    );
  }

  String _formatItemPrice(DetectedItem item) {
    debugPrint('[_formatItemPrice] Formatting price for: ${item.name}');
    debugPrint('[_formatItemPrice] Unit: ${item.unit}');
    debugPrint('[_formatItemPrice] Quantity: ${item.quantity}');
    debugPrint(
      '[_formatItemPrice] priceMin: ${item.priceMin}, priceMax: ${item.priceMax}',
    );
    debugPrint(
      '[_formatItemPrice] boostedPriceMin: ${item.boostedPriceMin}, boostedPriceMax: ${item.boostedPriceMax}',
    );
    debugPrint('[_formatItemPrice] estimatedValue: ${item.estimatedValue}');
    debugPrint('[_formatItemPrice] promotionId: ${item.promotionId}');

    // If item has promotion boost, show boosted price
    if (item.promotionId != null &&
        item.boostedPriceMin != null &&
        item.boostedPriceMax != null) {
      final minTotal = item.boostedPriceMin! * item.quantity;
      final maxTotal = item.boostedPriceMax! * item.quantity;

      // If min and max totals are the same, show single price
      if ((minTotal - maxTotal).abs() < 0.01) {
        return AppFormatters.currency(minTotal);
      }

      // Otherwise show range
      return '${AppFormatters.currency(minTotal)}-${AppFormatters.currency(maxTotal)}';
    }

    // If item has priceMin and priceMax from material catalog
    if (item.priceMin != null &&
        item.priceMax != null &&
        (item.priceMin! > 0 || item.priceMax! > 0)) {
      final minTotal = item.priceMin! * item.quantity;
      final maxTotal = item.priceMax! * item.quantity;

      // If min and max totals are the same, show single price
      if ((minTotal - maxTotal).abs() < 0.01) {
        return AppFormatters.currency(minTotal);
      }

      // Otherwise show range
      return '${AppFormatters.currency(minTotal)}-${AppFormatters.currency(maxTotal)}';
    }

    // Fallback to estimatedValue (per-unit × quantity)
    return AppFormatters.currency(item.estimatedValue * item.quantity);
  }

  String? _formatOriginalPrice(DetectedItem item) {
    // Only show original price if there's a promotion boost
    if (item.promotionId == null ||
        item.priceMin == null ||
        item.priceMax == null) {
      return null;
    }

    final minTotal = item.priceMin! * item.quantity;
    final maxTotal = item.priceMax! * item.quantity;

    // If min and max totals are the same, show single price
    if ((minTotal - maxTotal).abs() < 0.01) {
      return AppFormatters.currency(minTotal);
    }

    // Otherwise show range
    return '${AppFormatters.currency(minTotal)}-${AppFormatters.currency(maxTotal)}';
  }

  Widget _buildDetectedItemCard(DetectedItem item) {
    final isAiScanned = item.isAiScanned;
    final accentColor = isAiScanned
        ? AppColors.successColor
        : AppColors.primaryGreen;

    final itemKey = item.name + item.hashCode.toString();
    final isOpen = _openItemKey == itemKey;
    final slideOffset = isOpen ? -80.0 : 0.0; // 80px slide distance

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Open on left drag, close on right drag
        if (details.delta.dx < -2) {
          // Dragging left
          setState(() {
            _openItemKey = itemKey;
          });
        } else if (details.delta.dx > 2 && isOpen) {
          // Dragging right while open - close it
          setState(() {
            _openItemKey = null;
          });
        }
      },
      onHorizontalDragEnd: (details) {
        // Also handle fast swipes
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -100) {
          setState(() {
            _openItemKey = itemKey;
          });
        } else if (details.primaryVelocity != null &&
            details.primaryVelocity! > 100 &&
            isOpen) {
          setState(() {
            _openItemKey = null;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
        child: Stack(
          children: [
            // Background delete button
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Container(
                width: 80,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {
                    _removeItem(item);
                    setState(() {
                      _openItemKey = null;
                    });
                  },
                  child: Icon(
                    Icons.delete_rounded,
                    color: AppColors.errorColor,
                    size: 28,
                  ),
                ),
              ),
            ),
            // Sliding content
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(slideOffset, 0, 0),
              child: Card(
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    AppDimensions.spacing12,
                    16,
                    AppDimensions.spacing12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      item.category,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (item.promotionId != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primaryGreen,
                                              AppColors.primaryGreen.withValues(
                                                alpha: 0.8,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.trending_up_rounded,
                                              size: 10,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '+${item.promotionBoostPercentage!.toStringAsFixed(0)}%',
                                              style: AppTextStyles.bodySmall
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 10,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAiScanned
                                      ? Icons.auto_awesome_rounded
                                      : Icons.edit_note_rounded,
                                  size: 12,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAiScanned ? 'AI Scanned' : 'Manual',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppDimensions.spacing12),

                      // Quantity and Estimated Value Row
                      Row(
                        children: [
                          // Quantity
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showQuantityDialog(item),
                              child: Row(
                                children: [
                                  Text(
                                    '${item.quantity} ${item.unit}',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 14,
                                    color: AppColors.primaryGreen,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacing16),
                          // Estimated Value
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Original price (struck through if promotion)
                              if (_formatOriginalPrice(item) != null) ...[
                                Text(
                                  _formatOriginalPrice(item)!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              // Boosted/Current price
                              Text(
                                _formatItemPrice(item),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: item.promotionId != null
                                      ? AppColors.primaryGreen
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Not accepted warning — below quantity/price row
                      if (item.isNotAcceptableByJunkshop) ...[
                        const SizedBox(height: 10),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFFFE0E0),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Not Accepted by This Junkshop',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Remove this item or choose a different junkshop.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.red.shade400,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get category icon
  // Helper method to build condition chip
  // Manual posting helpers
  Future<void> _ensureMaterialCatalogLoaded() async {
    debugPrint('[MaterialCatalog] Checking if catalog needs loading...');
    debugPrint(
      '[MaterialCatalog] Current catalog: ${_materialCatalog == null ? "null" : "${_materialCatalog!.length} items"}',
    );
    debugPrint(
      '[MaterialCatalog] Selected junkshop: ${_selectedJunkshop?['id'] ?? "none"}',
    );

    if (_materialCatalog != null) {
      debugPrint('[MaterialCatalog] Catalog already loaded, skipping');
      return;
    }

    // Load materials from selected junkshop's Firebase collection
    if (_selectedJunkshop != null && _selectedJunkshop!['id'] != null) {
      try {
        final junkshopId = _selectedJunkshop!['id'] as String;
        debugPrint(
          '[MaterialCatalog] Loading materials from junkshop: $junkshopId',
        );

        final materialDocs = rowsToDocs(
          'junkshop_materials',
          await Supabase.instance.client
              .from('junkshop_materials')
              .select()
              .eq('junkshop_id', junkshopId)
              .order('category')
              .order('name'),
        );

        debugPrint(
          '[MaterialCatalog] Found ${materialDocs.length} materials (including inactive)',
        );
        _materialCatalog = materialDocs.map((data) {
          final commission = (data['commission'] as num?)?.toDouble() ?? 0.0;
          final priceMin = (data['priceMin'] as num?)?.toDouble() ?? 0.0;
          final priceMax = (data['priceMax'] as num?)?.toDouble() ?? 0.0;
          final householdMin = priceMin - commission;
          final householdMax = priceMax - commission;
          final name = data['name'] ?? '';
          final isActive = data['isActive'] ?? true;

          debugPrint(
            '[Material] $name: priceMin=$priceMin, priceMax=$priceMax, commission=$commission, householdMin=$householdMin, householdMax=$householdMax, isActive=$isActive',
          );

          return {
            'name': name,
            'category': data['category'] ?? 'others',
            'unit': data['unit'] ?? 'kg',
            'priceMin': priceMin,
            'priceMax': priceMax,
            'commission': commission,
            'householdPriceMin': householdMin,
            'householdPriceMax': householdMax,
            'isActive': isActive,
            // Keep 'price' for backward compatibility (use max)
            'price': householdMax,
          };
        }).toList();

        debugPrint(
          '[MaterialCatalog] Successfully loaded ${_materialCatalog!.length} materials from junkshop $junkshopId',
        );
        // Validate existing items to ensure they have proper pricing
        await _validateExistingItems();
      } catch (e) {
        debugPrint('[MaterialCatalog] Error loading materials: $e');
        // Fallback to JSON if loading fails
        _materialCatalog = await PostingHelpers.loadMaterialCatalog();
        debugPrint(
          '[MaterialCatalog] Loaded ${_materialCatalog?.length ?? 0} materials from JSON fallback',
        );
        // Validate existing items to ensure they have proper pricing
        await _validateExistingItems();
      }
    } else {
      debugPrint('[MaterialCatalog] No junkshop selected, using JSON fallback');
      // Fallback to JSON if no junkshop selected
      _materialCatalog = await PostingHelpers.loadMaterialCatalog();
      debugPrint(
        '[MaterialCatalog] Loaded ${_materialCatalog?.length ?? 0} materials from JSON fallback',
      );
      // Validate existing items to ensure they have proper pricing
      await _validateExistingItems();
    }
  }

  /// Validate existing items against new junkshop's material catalog
  /// Updates prices for acceptable items and marks unacceptable ones
  Future<void> _validateExistingItems() async {
    if (_detectedItems.isEmpty || _materialCatalog == null) {
      return;
    }

    debugPrint(
      '[MaterialValidation] Validating ${_detectedItems.length} items',
    );

    setState(() {
      for (var item in _detectedItems) {
        // First ensure the item has basic pricing information
        if ((item.priceMin == null || item.priceMin == 0.0) &&
            (item.priceMax == null || item.priceMax == 0.0)) {
          debugPrint(
            '[MaterialValidation] Item ${item.name} has no pricing, attempting to fetch...',
          );

          // Try to find pricing for this material
          _fetchPricingForItem(item);
        }

        // Then validate if it matches any material in current catalog
        final searchTerm = item.name.toLowerCase();
        final normalizedSearch = searchTerm
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'\\s+'), ' ')
            .trim();

        final matchingMaterial = _materialCatalog!.firstWhere((material) {
          final matName = (material['name'] as String? ?? '').toLowerCase();
          final normalizedName = matName
              .replaceAll('_', ' ')
              .replaceAll(RegExp(r'\\s+'), ' ')
              .trim();
          return normalizedName.contains(normalizedSearch) ||
              normalizedSearch.contains(normalizedName) ||
              matName.contains(searchTerm);
        }, orElse: () => <String, dynamic>{});

        if (matchingMaterial.isNotEmpty) {
          // Update with current catalog pricing
          final householdMin =
              (matchingMaterial['householdPriceMin'] as num?)?.toDouble() ??
              0.0;
          final householdMax =
              (matchingMaterial['householdPriceMax'] as num?)?.toDouble() ??
              0.0;

          if (householdMin > 0 || householdMax > 0) {
            debugPrint(
              '[MaterialValidation] Updating prices for ${item.name}: ₱$householdMin - ₱$householdMax',
            );
            item.priceMin = householdMin;
            item.priceMax = householdMax;
            item.estimatedValue = (householdMin + householdMax) / 2;
          }

          item.category =
              matchingMaterial['category'] as String? ?? item.category;
          // Clear any stale unacceptable flag from a previously selected junkshop
          item.isNotAcceptableByJunkshop = false;
          // Keep the unit from scanning screen
          // item.unit = matchingMaterial['unit'] as String? ?? item.unit;
        } else {
          debugPrint(
            '[MaterialValidation] ⚠️ ${item.name} not found in current catalog',
          );
          // Mark unacceptable only when a junkshop is explicitly selected
          if (_selectedJunkshop != null) {
            item.isNotAcceptableByJunkshop = true;
          }
        }
      }
    });
  }

  /// Fetch pricing for a single item from catalog
  Future<void> _fetchPricingForItem(DetectedItem item) async {
    final priceRange = await _getPriceRangeForCategory(item.name, weight: 1.0);

    final priceMin = priceRange['min'] as double?;
    final priceMax = priceRange['max'] as double?;

    if (priceMin != null && priceMin > 0 && priceMax != null && priceMax > 0) {
      item.priceMin = priceMin;
      item.priceMax = priceMax;
      item.estimatedValue = (priceMin + priceMax) / 2;
      debugPrint(
        '[MaterialValidation] Fetched pricing for ${item.name}: ₱$priceMin - ₱$priceMax',
      );
    } else {
      debugPrint('[MaterialValidation] No pricing found for ${item.name}');
    }
  }

  Future<void> _validateItemsAgainstJunkshop() async {
    if (_detectedItems.isEmpty || _materialCatalog == null) {
      return;
    }

    debugPrint(
      '[ItemValidation] Validating ${_detectedItems.length} items against junkshop catalog',
    );

    setState(() {
      for (final item in _detectedItems) {
        // Find matching material in the new junkshop's catalog
        final matchingMaterial = _materialCatalog!.firstWhere((material) {
          final materialName = (material['name'] as String? ?? '')
              .toLowerCase()
              .trim();
          final itemName = item.name.toLowerCase().trim();
          final isActive = material['isActive'] as bool? ?? true;

          // Use fuzzy matching (same as _validateExistingItems) so minor
          // name variations between junkshops don't false-flag items
          return isActive &&
              (materialName == itemName ||
                  materialName.contains(itemName) ||
                  itemName.contains(materialName));
        }, orElse: () => <String, dynamic>{});

        if (matchingMaterial.isEmpty) {
          // Material not found or not active in new junkshop
          item.isNotAcceptableByJunkshop = true;
          debugPrint(
            '[ItemValidation] ❌ ${item.name} NOT acceptable by junkshop',
          );
        } else {
          // Material found - update prices from new junkshop
          item.isNotAcceptableByJunkshop = false;
          item.priceMin = matchingMaterial['householdPriceMin'] as double?;
          item.priceMax = matchingMaterial['householdPriceMax'] as double?;
          item.baseUnit = matchingMaterial['unit'] as String?;

          // Recalculate boosted prices if promotion is active
          if (item.promotionBoostPercentage != null &&
              item.priceMin != null &&
              item.priceMax != null) {
            final boostMultiplier = 1 + (item.promotionBoostPercentage! / 100);
            item.boostedPriceMin = item.priceMin! * boostMultiplier;
            item.boostedPriceMax = item.priceMax! * boostMultiplier;
          }

          debugPrint(
            '[ItemValidation] ✅ ${item.name} acceptable - Updated prices: ₱${item.priceMin}-₱${item.priceMax}',
          );
        }
      }
    });

    // Show notification if there are unacceptable items
    final unacceptableCount = _detectedItems
        .where((item) => item.isNotAcceptableByJunkshop)
        .length;
    if (unacceptableCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$unacceptableCount material(s) not accepted by this junkshop. Please remove or change junkshop.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _fetchBusinessControls() async {
    if (_selectedJunkshop == null || _selectedJunkshop!['id'] == null) {
      debugPrint('[BusinessControls] No junkshop selected');
      setState(() {
        _baseFee = null;
        _costPerKm = null;
        _maxWeightPerValueRatio = null;
        _serviceRadius = null;
        _operatingHours = null;
        _acceptedCategories = {};
      });
      return;
    }

    try {
      final junkshopId = _selectedJunkshop!['id'] as String;
      debugPrint('[BusinessControls] Fetching for junkshop: $junkshopId');

      final junkshopRow = await Supabase.instance.client
          .from('junkshops')
          .select()
          .eq('id', junkshopId)
          .maybeSingle();

      if (junkshopRow != null) {
        final data = junkshopRow;
        // Load from settings (correct path)
        final settings = data['settings'] as Map<String, dynamic>?;

        // Load service radius from junkshop_profile.location.service_radius
        final junkshopProfile =
            data['junkshop_profile'] as Map<String, dynamic>?;
        final locationMap =
            junkshopProfile?['location'] as Map<String, dynamic>?;
        final businessMap =
            junkshopProfile?['business'] as Map<String, dynamic>?;

        final serviceRadius =
            (locationMap?['service_radius'] as num?)?.toDouble() ??
            (businessMap?['service_radius'] as num?)?.toDouble();
        final operatingHours = businessMap?['operating_hours'] as String?;

        // Fetch active materials
        final activeMaterials = await Supabase.instance.client
            .from('junkshop_materials')
            .select('category')
            .eq('junkshop_id', junkshopId)
            .eq('is_active', true);

        final acceptedCategories = <String>{};
        for (final row in activeMaterials) {
          final category = row['category'] as String?;
          if (category != null && category.isNotEmpty) {
            acceptedCategories.add(category.toLowerCase());
          }
        }
        setState(() {
          _baseFee = (settings?['baseFee'] as num?)?.toDouble();
          _costPerKm = (settings?['costPerKm'] as num?)?.toDouble();
          _maxWeightPerValueRatio =
              (settings?['maxWeightPerValueRatio'] as num?)?.toDouble();
          _serviceRadius = serviceRadius;
          _operatingHours = operatingHours;
          _acceptedCategories = acceptedCategories;
        });

        debugPrint(
          '[BusinessControls] ✅ Loaded: baseFee=$_baseFee, costPerKm=$_costPerKm, maxRatio=$_maxWeightPerValueRatio, serviceRadius=$_serviceRadius, hours=$_operatingHours',
        );
        debugPrint(
          '[BusinessControls] Accepted categories: $acceptedCategories',
        );

        if (_baseFee == null &&
            _costPerKm == null &&
            _maxWeightPerValueRatio == null) {
          debugPrint(
            '[BusinessControls] ⚠️ WARNING: No business controls configured for this junkshop!',
          );
          debugPrint('[BusinessControls] Business rules will NOT be enforced.');
        }

        // Trigger validation after fetching controls
        _validatePosting();
      } else {
        debugPrint('[BusinessControls] Junkshop document not found');
      }
    } catch (e) {
      debugPrint('[BusinessControls] Error fetching: $e');
    }
  }

  Future<Map<String, dynamic>> _getPriceRangeForCategory(
    String category, {
    double weight = 1.0,
  }) async {
    // Always prefer the already-loaded catalog (which has computed householdPriceMin/Max).
    // Only fall back to a live Firestore query when the catalog hasn't been loaded yet.
    if (_materialCatalog != null && _materialCatalog!.isNotEmpty) {
      debugPrint('[PriceRange] Searching catalog for: $category');

      final searchTerm = category.toLowerCase();
      final normalizedSearch = searchTerm
          .replaceAll('_', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final searchWords = normalizedSearch
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toSet();

      // Also try the AI-label → Firebase name map for better matching
      final resolvedSearch = WasteDetectionModel.getSearchNameForLabel(
        category,
      );
      final resolvedWords = resolvedSearch
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toSet();

      final matchingMaterials = _materialCatalog!.where((material) {
        final matName = (material['name'] as String? ?? '').toLowerCase();
        final normalizedName = matName
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final nameWords = normalizedName
            .split(' ')
            .where((w) => w.isNotEmpty)
            .toSet();

        final hasExactMatch =
            normalizedName == normalizedSearch ||
            normalizedName.contains(normalizedSearch) ||
            normalizedSearch.contains(normalizedName) ||
            normalizedName == resolvedSearch ||
            normalizedName.contains(resolvedSearch) ||
            resolvedSearch.contains(normalizedName);

        final hasWordMatch =
            searchWords.intersection(nameWords).isNotEmpty ||
            resolvedWords.intersection(nameWords).isNotEmpty;

        return hasExactMatch || hasWordMatch;
      }).toList();

      if (matchingMaterials.isNotEmpty) {
        final material = matchingMaterials.first;
        final householdMin =
            (material['householdPriceMin'] as num?)?.toDouble() ?? 0.0;
        final householdMax =
            (material['householdPriceMax'] as num?)?.toDouble() ?? 0.0;
        final avgPrice = (householdMin + householdMax) / 2;
        final materialCategory = material['category'] as String?;
        final materialUnit = material['unit'] as String? ?? 'pcs';

        debugPrint(
          '[PriceRange] Found in catalog: ${material['name']} — ₱$householdMin–₱$householdMax per $materialUnit',
        );

        return {
          'min': householdMin,
          'max': householdMax,
          'avg': avgPrice,
          'category': materialCategory,
          'unit': materialUnit,
        };
      }

      debugPrint('[PriceRange] No catalog match for: $category');
    }

    // Catalog empty or no match — try live Firestore query as last resort
    if (_selectedJunkshop != null && _selectedJunkshop!['uid'] != null) {
      return await _getJunkshopMaterialPrice(category, weight: weight);
    }

    return {
      'min': 0.0,
      'max': 0.0,
      'avg': 0.0,
      'category': null,
      'unit': 'pcs',
    };
  }

  Future<Map<String, dynamic>> _getJunkshopMaterialPrice(
    String materialName, {
    double weight = 1.0,
  }) async {
    final junkshopId = _selectedJunkshop!['uid'] as String;

    debugPrint(
      '[JunkshopPrice] Querying junkshop $junkshopId for material: $materialName',
    );

    // Fetch material price from junkshop and wait for result
    return await _fetchJunkshopMaterialPrice(materialName, weight);
  }

  Future<Map<String, dynamic>> _fetchJunkshopMaterialPrice(
    String materialName,
    double weight,
  ) async {
    if (_selectedJunkshop == null) {
      return {
        'min': 0.0,
        'max': 0.0,
        'avg': 0.0,
        'category': null,
        'unit': 'kg',
      };
    }

    final junkshopId = _selectedJunkshop!['uid'] as String;

    // Use resolved search name to reliably match AI labels to Firebase material names
    final normalizedSearch = WasteDetectionModel.getSearchNameForLabel(
      materialName,
    );
    final searchWords = normalizedSearch
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toSet();

    try {
      final materialDocs = rowsToDocs(
        'junkshop_materials',
        await Supabase.instance.client
            .from('junkshop_materials')
            .select()
            .eq('junkshop_id', junkshopId)
            .eq('is_active', true),
      );

      debugPrint(
        '[JunkshopPrice] Found ${materialDocs.length} active materials',
      );
      debugPrint('[JunkshopPrice] Label: "$materialName"');
      debugPrint('[JunkshopPrice] Resolved search: "$normalizedSearch"');
      debugPrint('[JunkshopPrice] Search words: $searchWords');

      // Find matching material by name (case-insensitive, fuzzy match)
      for (final data in materialDocs) {
        final name = (data['name'] as String?)?.toLowerCase().trim() ?? '';

        // Normalize material name: remove underscores, extra spaces
        final normalizedName = name
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final nameWords = normalizedName
            .split(' ')
            .where((w) => w.isNotEmpty)
            .toSet();

        // Exact/partial match OR single-word overlap — handles label↔name mismatches
        final hasExactMatch =
            normalizedName == normalizedSearch ||
            normalizedName.contains(normalizedSearch) ||
            normalizedSearch.contains(normalizedName);

        final hasWordMatch = searchWords.intersection(nameWords).isNotEmpty;

        if (hasExactMatch || hasWordMatch) {
          debugPrint(
            '[JunkshopPrice] Material name: "$name" → normalized: "$normalizedName"',
          );
          debugPrint(
            '[JunkshopPrice] Match type: exact=$hasExactMatch, words=$hasWordMatch',
          );

          // Compute household prices the same way the catalog loader does:
          // householdPrice = junkshopPrice - commission
          final rawPriceMin = (data['priceMin'] as num?)?.toDouble() ?? 0.0;
          final rawPriceMax = (data['priceMax'] as num?)?.toDouble() ?? 0.0;
          final commission = (data['commission'] as num?)?.toDouble() ?? 0.0;
          final priceMin = (rawPriceMin - commission).clamp(
            0.0,
            double.infinity,
          );
          final priceMax = (rawPriceMax - commission).clamp(
            0.0,
            double.infinity,
          );
          final avgPrice = (priceMin + priceMax) / 2;
          final materialUnit = data['unit'] as String? ?? 'kg';
          final materialCategory = data['category'] as String?;

          debugPrint('[JunkshopPrice] Found match: ${data['name']}');
          debugPrint('[JunkshopPrice] Category: $materialCategory');
          debugPrint('[JunkshopPrice] Unit: $materialUnit');
          debugPrint(
            '[JunkshopPrice] Price range: ₱$priceMin - ₱$priceMax per $materialUnit',
          );

          // Check if this material qualifies for promotion boost
          final materialId = data['id']?.toString();
          final hasPromotion =
              _activePromotionId != null &&
              _promotionMaterials.contains(materialId);
          final boostMultiplier = hasPromotion
              ? (1.0 + (_promotionBoostPercentage / 100.0))
              : 1.0;

          debugPrint(
            '[Promotion] Checking material: ${data['name']} (ID: $materialId)',
          );
          debugPrint('[Promotion] Active Promotion: $_activePromotionId');
          debugPrint('[Promotion] Eligible Materials: $_promotionMaterials');
          debugPrint('[Promotion] Is Eligible: $hasPromotion');
          if (hasPromotion) {
            debugPrint(
              '[Promotion] ✅ Applying $_promotionBoostPercentage% boost to ${data['name']}',
            );
            debugPrint(
              '[Promotion] Base price: ₱$avgPrice, Boosted: ₱${avgPrice * boostMultiplier}',
            );
          } else {
            debugPrint('[Promotion] ❌ No boost applied to ${data['name']}');
          }

          // Update detected items with junkshop's actual per-unit prices and category
          if (mounted) {
            setState(() {
              for (var item in _detectedItems) {
                if (item.name.toLowerCase().contains(normalizedSearch) ||
                    item.category.toLowerCase().contains(normalizedSearch)) {
                  // Debug: Check values before assignment
                  debugPrint('[Price Debug] Material: ${item.name}');
                  debugPrint(
                    '[Price Debug] From DB - priceMin: $priceMin, priceMax: $priceMax per unit',
                  );
                  debugPrint('[Price Debug] boostMultiplier: $boostMultiplier');

                  // Store per-unit prices (without boost)
                  item.priceMin = priceMin;
                  item.priceMax = priceMax;

                  debugPrint(
                    '[Price Debug] Per-unit prices - item.priceMin: ${item.priceMin}, item.priceMax: ${item.priceMax}',
                  );

                  // Calculate base value per unit
                  final baseValuePerUnit = avgPrice;

                  // Store boosted per-unit prices if promotion is active
                  if (hasPromotion) {
                    item.boostedPriceMin =
                        priceMin * (1 + (_promotionBoostPercentage / 100));
                    item.boostedPriceMax =
                        priceMax * (1 + (_promotionBoostPercentage / 100));
                    item.estimatedValue =
                        baseValuePerUnit *
                        (1 + (_promotionBoostPercentage / 100));
                    item.promotionBoostPercentage = _promotionBoostPercentage;
                    item.promotionId = _activePromotionId;
                    debugPrint(
                      '[Price Debug] Boosted per-unit - min: ${item.boostedPriceMin}, max: ${item.boostedPriceMax}',
                    );
                  } else {
                    item.boostedPriceMin = null;
                    item.boostedPriceMax = null;
                    item.promotionBoostPercentage = null;
                    item.estimatedValue = baseValuePerUnit;
                  }
                  item.category = data['category'] as String? ?? item.category;
                  // Keep the unit from scanning screen (don't override)
                  // item.unit = data['unit'] as String? ?? item.unit;
                }
              }
            });
          }

          // Return pricing data with unit per unit (not multiplied by weight)
          debugPrint(
            '[JunkshopPrice] Returning unit: $materialUnit for material: ${data['name']}',
          );
          return {
            'min': priceMin,
            'max': priceMax,
            'avg': avgPrice,
            'category': materialCategory,
            'unit': materialUnit,
          };
        }
      }

      debugPrint(
        '[JunkshopPrice] No matching material found in junkshop inventory',
      );
    } catch (e) {
      debugPrint('[JunkshopPrice] Error fetching material prices: $e');
    }

    // Return default values if no match found or error occurred
    return {'min': 0.0, 'max': 0.0, 'avg': 0.0, 'category': null, 'unit': 'kg'};
  }

  void _validatePosting() {
    if (_selectedJunkshop == null) {
      setState(() => _validationResults = {});
      return;
    }

    final results = <String, dynamic>{};

    // Calculate total value using minimum price first, if fails try maximum price
    double totalMin = _detectedItems.fold<double>(0, (acc, item) {
      if (item.priceMin != null && item.priceMin! > 0) {
        return acc + (item.priceMin! * item.quantity);
      }
      return acc + (item.estimatedValue * item.quantity);
    });

    double totalMax = _detectedItems.fold<double>(0, (acc, item) {
      if (item.priceMax != null && item.priceMax! > 0) {
        return acc + (item.priceMax! * item.quantity);
      }
      return acc + (item.estimatedValue * item.quantity);
    });

    // 1. Validate weight-to-value ratio
    if (_maxWeightPerValueRatio != null) {
      final weightStr = _estimatedWeightController.text;
      final weight = weightStr.isNotEmpty ? double.tryParse(weightStr) : null;

      if (weight != null && weight > 0) {
        // Calculate weighted items value using minimum price first
        final weightedItemsValueMin = _detectedItems
            .where((item) => item.unit.toLowerCase() == 'kg')
            .fold<double>(0.0, (acc, item) {
              if (item.priceMin != null) {
                return acc + (item.priceMin! * item.quantity);
              }
              return acc + item.estimatedValue;
            });

        final weightedItemsValueMax = _detectedItems
            .where((item) => item.unit.toLowerCase() == 'kg')
            .fold<double>(0.0, (acc, item) {
              if (item.priceMax != null) {
                return acc + (item.priceMax! * item.quantity);
              }
              return acc + item.estimatedValue;
            });

        double weightedItemsValue = weightedItemsValueMin;

        if (weightedItemsValue > 0) {
          double ratio = (weight / weightedItemsValue) * 100; // kg per ₱100
          bool meetsRatio = ratio <= _maxWeightPerValueRatio!;

          // If minimum price fails, try maximum price
          if (!meetsRatio && weightedItemsValueMax > 0) {
            ratio = (weight / weightedItemsValueMax) * 100;
            if (ratio <= _maxWeightPerValueRatio!) {
              meetsRatio = true;
              weightedItemsValue = weightedItemsValueMax;
            }
          }

          results['weightRatio'] = {
            'pass': meetsRatio,
            'max': _maxWeightPerValueRatio,
            'current': ratio,
            'message': meetsRatio
                ? 'Weight-to-value ratio is acceptable'
                : 'Weight too high for the declared value (${ratio.toStringAsFixed(1)} kg/₱100 vs max ${_maxWeightPerValueRatio!.toStringAsFixed(1)} kg/₱100)',
            'suggestion': meetsRatio
                ? null
                : 'Reduce weight to ${(_maxWeightPerValueRatio! * weightedItemsValue / 100).toStringAsFixed(1)} kg or add ₱${((weight * 100 / _maxWeightPerValueRatio!) - weightedItemsValue).toStringAsFixed(0)} more value',
          };
        }
      }
    }

    // 3. Validate accepted materials by name
    if (_materialCatalog != null && _materialCatalog!.isNotEmpty) {
      final rejectedItems = <DetectedItem>[];
      for (final item in _detectedItems) {
        final materialName = item.name.toLowerCase();
        final isAccepted = _materialCatalog!.any((material) {
          final matName = (material['name'] as String? ?? '').toLowerCase();
          return matName == materialName ||
              matName.contains(materialName) ||
              materialName.contains(matName);
        });

        if (!isAccepted) {
          rejectedItems.add(item);
        }
      }

      results['categories'] = {
        'pass': rejectedItems.isEmpty,
        'rejectedItems': rejectedItems,
        'message': rejectedItems.isEmpty
            ? 'All items are accepted by this junkshop'
            : '${rejectedItems.length} item(s) not accepted for pickup',
        'suggestion': rejectedItems.isEmpty
            ? null
            : 'Remove rejected items or choose a different junkshop that accepts these materials',
        'details': rejectedItems.isEmpty
            ? null
            : rejectedItems.map((item) => item.name).join(', '),
      };
    }

    // 4. Validate service radius
    final distance = _calculateDistance();
    if (distance != null && _selectedJunkshop != null) {
      final junkshopRadius = (_selectedJunkshop!['serviceRadius'] is num)
          ? (_selectedJunkshop!['serviceRadius'] as num).toDouble()
          : double.tryParse(
                  _selectedJunkshop!['serviceRadius']?.toString() ?? '15.0',
                ) ??
                15.0;

      final withinRadius = distance <= junkshopRadius;

      results['serviceRadius'] = {
        'pass': withinRadius,
        'distance': distance,
        'maxRadius': junkshopRadius,
        'message': withinRadius
            ? 'Within service area (${distance.toStringAsFixed(1)} km)'
            : 'Location is ${distance.toStringAsFixed(1)} km away, exceeds ${junkshopRadius.toStringAsFixed(0)} km service radius',
        'suggestion': withinRadius
            ? null
            : 'Choose a closer junkshop or contact them to request service at your location',
      };
    }

    setState(() => _validationResults = results);
    debugPrint('[Validation] Results: $results');
  }

  double? _calculateDistance() {
    // Get household coordinates
    final selectedAddress = _savedAddresses.firstWhere(
      (addr) => addr['key'] == _selectedAddressKey,
      orElse: () => {},
    );

    if (selectedAddress.isEmpty) return null;

    final householdLat = (selectedAddress['lat'] is num)
        ? (selectedAddress['lat'] as num).toDouble()
        : double.tryParse(selectedAddress['lat'].toString());
    final householdLng = (selectedAddress['lng'] is num)
        ? (selectedAddress['lng'] as num).toDouble()
        : double.tryParse(selectedAddress['lng'].toString());

    if (householdLat == null || householdLng == null) return null;

    // Get junkshop coordinates
    if (_selectedJunkshop == null) return null;

    final junkshopLat = (_selectedJunkshop!['lat'] is num)
        ? (_selectedJunkshop!['lat'] as num).toDouble()
        : double.tryParse(_selectedJunkshop!['lat'].toString());
    final junkshopLng = (_selectedJunkshop!['lng'] is num)
        ? (_selectedJunkshop!['lng'] as num).toDouble()
        : double.tryParse(_selectedJunkshop!['lng'].toString());

    if (junkshopLat == null || junkshopLng == null) return null;

    // Calculate distance using Haversine formula
    return _haversineDistance(
      householdLat,
      householdLng,
      junkshopLat,
      junkshopLng,
    );
  }

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * (3.141592653589793 / 180);

  Future<void> _loadAvailableJunkshops() async {
    // Get household coordinates from selected address
    double? householdLat;
    double? householdLng;

    // Find the selected address data
    final selectedAddress = _savedAddresses.firstWhere(
      (addr) => addr['key'] == _selectedAddressKey,
      orElse: () => <String, dynamic>{},
    );

    if (selectedAddress.isNotEmpty) {
      // Extract lat/lng from selected address
      if (selectedAddress['lat'] != null) {
        householdLat = (selectedAddress['lat'] is num)
            ? (selectedAddress['lat'] as num).toDouble()
            : double.tryParse(selectedAddress['lat'].toString());
      }
      if (selectedAddress['lng'] != null) {
        householdLng = (selectedAddress['lng'] is num)
            ? (selectedAddress['lng'] as num).toDouble()
            : double.tryParse(selectedAddress['lng'].toString());
      }
    }

    debugPrint(
      '[Junkshops] Loading with household coords: lat=$householdLat, lng=$householdLng',
    );

    _availableJunkshops = await PostingHelpers.loadAvailableJunkshops(
      householdLat: householdLat,
      householdLng: householdLng,
    );

    debugPrint('[Junkshops] Loaded ${_availableJunkshops.length} junkshop(s)');

    // Pre-select junkshop if coming from promotion
    debugPrint(
      '[Junkshops] Checking pre-selection: preSelectedJunkshopId=${widget.preSelectedJunkshopId}',
    );
    if (widget.preSelectedJunkshopId != null &&
        _availableJunkshops.isNotEmpty) {
      debugPrint(
        '[Junkshops] Looking for junkshop with ID: ${widget.preSelectedJunkshopId}',
      );
      final preSelectedShop = _availableJunkshops.firstWhere(
        (shop) {
          final matchesUid = shop['uid'] == widget.preSelectedJunkshopId;
          final matchesId = shop['id'] == widget.preSelectedJunkshopId;
          debugPrint(
            '[Junkshops] Checking shop: ${shop['name']} (uid=${shop['uid']}, id=${shop['id']}) - Match: ${matchesUid || matchesId}',
          );
          return matchesUid || matchesId;
        },
        orElse: () {
          debugPrint('[Junkshops] No match found, using first junkshop');
          return _availableJunkshops.first;
        },
      );
      _selectedJunkshop = preSelectedShop;
      debugPrint(
        '[Junkshops] Pre-selected from promotion: ${_selectedJunkshop!['name']} (${_selectedJunkshop!['uid']})',
      );
    } else if (_availableJunkshops.isNotEmpty && !widget.editMode) {
      // Set default selection to closest junkshop (but not in edit/repost mode)
      _selectedJunkshop = _availableJunkshops.first;
      debugPrint(
        '[Junkshops] Selected closest: ${_selectedJunkshop!['name']} (${_selectedJunkshop!['distance'].toStringAsFixed(1)} km)',
      );
    }

    // Load business controls and material catalog for the selected junkshop (only if not in edit mode, as edit mode will load its own junkshop)
    if (_selectedJunkshop != null && !widget.editMode) {
      await _fetchBusinessControls();
      await _ensureMaterialCatalogLoaded();
    }

    if (mounted) setState(() {});
  }

  void _initializePromotionData() {
    setState(() {
      _activePromotionId = widget.promotionId;
      _promotionMaterials = List<String>.from(
        widget.promotionData?['materials'] ?? [],
      );
      _promotionBoostPercentage =
          (widget.promotionData?['priceBoostDetails']?['boostPercentage']
                  as num?)
              ?.toDouble() ??
          0.0;
    });
    debugPrint('[Promotion] ===== Promotion Data Initialized =====');
    debugPrint('[Promotion] ID: $_activePromotionId');
    debugPrint('[Promotion] Eligible Materials: $_promotionMaterials');
    debugPrint('[Promotion] Boost Percentage: $_promotionBoostPercentage%');
    debugPrint('[Promotion] =====================================');

    // Check if promotion is still valid when reposting
    if (widget.isRepost && _activePromotionId != null) {
      _checkPromotionValidity();
    }
  }

  Future<void> _checkPromotionValidity() async {
    if (_selectedJunkshop == null || _activePromotionId == null) return;

    try {
      final junkshopId = _selectedJunkshop!['uid'] as String;
      final promotionRow = await Supabase.instance.client
          .from('promotions')
          .select()
          .eq('id', _activePromotionId!)
          .eq('junkshop_id', junkshopId)
          .maybeSingle();

      if (promotionRow == null) {
        debugPrint('[Promotion] Promotion no longer exists');
        _clearPromotionData('Promotion is no longer available');
        return;
      }

      final promotionData = rowToDoc('promotions', promotionRow);
      final status = promotionData['status']?.toString();
      final endDate = toDateTime(promotionData['endDate']);
      // Check if promotion is expired or inactive
      if (status != 'active') {
        debugPrint('[Promotion] ⚠️ Promotion status is: $status');
        _clearPromotionData('Promotion is no longer active');
        return;
      }

      if (endDate != null && endDate.isBefore(DateTime.now())) {
        debugPrint('[Promotion] ⚠️ Promotion expired on: $endDate');
        _clearPromotionData('Promotion has expired');
        return;
      }

      debugPrint('[Promotion] ✅ Promotion is still valid');
    } catch (e) {
      debugPrint('[Promotion] ❌ Error checking promotion validity: $e');
      _clearPromotionData('Could not verify promotion status');
    }
  }

  void _clearPromotionData(String reason) {
    setState(() {
      _activePromotionId = null;
      _promotionMaterials = [];
      _promotionBoostPercentage = 0.0;

      // Remove promotion data from all items
      for (var item in _detectedItems) {
        item.promotionBoostPercentage = null;
        item.promotionId = null;
        item.boostedPriceMin = null;
        item.boostedPriceMax = null;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$reason. Prices have been reset to original values.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    debugPrint('[Promotion] ❌ Cleared promotion data: $reason');
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint(
        '[Addresses] Fetching user doc for uid=$userId (role=household)',
      );

      final data = await Supabase.instance.client
          .from('households')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null || !mounted) {
        debugPrint('[Addresses] User document not found or widget unmounted');
        if (mounted) {
          setState(() {
            _isLoadingAddresses = false;
          });
        }
        return;
      }
      debugPrint('[Addresses] User data keys: ${data.keys.toList()}');
      final List<Map<String, dynamic>> addresses = [];

      // Add primary address if exists
      final location = data[UserFields.location];
      if (location is Map<String, dynamic> &&
          location[UserFields.address] is String &&
          (location[UserFields.address] as String).trim().isNotEmpty) {
        addresses.add({
          'key': 'location',
          'label': 'Primary Address',
          'address': location[UserFields.address] as String,
          'lat': location[UserFields.lat],
          'lng': location[UserFields.lng],
          'note': location['note'],
        });
      }

      // Add second address if exists
      final location2 = data['location_2'];
      if (location2 is Map<String, dynamic> &&
          location2[UserFields.address] is String &&
          (location2[UserFields.address] as String).trim().isNotEmpty) {
        addresses.add({
          'key': 'location_2',
          'label': 'Second Address',
          'address': location2[UserFields.address] as String,
          'lat': location2[UserFields.lat],
          'lng': location2[UserFields.lng],
          'note': location2['note'],
        });
      }

      if (mounted) {
        setState(() {
          _savedAddresses = addresses;
          _isLoadingAddresses = false;
          // Auto-select primary address if available, otherwise keep manual
          if (_savedAddresses.isNotEmpty) {
            _selectedAddressKey = _savedAddresses.first['key'];
            _locationController.text = _savedAddresses.first['address'];
            debugPrint(
              '[Addresses] Loaded ${_savedAddresses.length} address(es); selected $_selectedAddressKey',
            );
          } else {
            _selectedAddressKey = 'manual';
            debugPrint('[Addresses] No saved addresses; using manual entry');
          }
        });
      }
    } catch (e) {
      debugPrint('[Addresses] Error loading saved addresses: $e');
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
        });
      }
    }
  }

  void _openManualAddItem() async {
    try {
      await _ensureMaterialCatalogLoaded();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => ManualAddItemModal(
          materialCatalog: (_materialCatalog ?? [])
              .cast<Map<String, dynamic>>(),
          junkshopId: _selectedJunkshop?['uid'] ?? _selectedJunkshop?['id'],
          activePromotionId: _activePromotionId,
          promotionMaterials: _promotionMaterials,
          promotionBoostPercentage: _promotionBoostPercentage,
          onAddItem: (item) {
            setState(() {
              // Check if material name is accepted
              final materialName = item.name.toLowerCase();
              final isAccepted =
                  _materialCatalog?.any((material) {
                    final matName = (material['name'] as String? ?? '')
                        .toLowerCase();
                    return matName == materialName ||
                        matName.contains(materialName) ||
                        materialName.contains(matName);
                  }) ??
                  false;

              // Check if item with same name and unit already exists
              final existingItemIndex = _detectedItems.indexWhere(
                (existing) =>
                    existing.name.toLowerCase() == item.name.toLowerCase() &&
                    existing.unit.toLowerCase() == item.unit.toLowerCase(),
              );

              if (existingItemIndex != -1) {
                // Item already exists, merge by adding quantities
                final existingItem = _detectedItems[existingItemIndex];
                existingItem.quantity += item.quantity;
                // Update estimated value (additive)
                existingItem.estimatedValue += item.estimatedValue;
                // Merge image paths
                for (final imagePath in item.imagePaths) {
                  if (!existingItem.imagePaths.contains(imagePath)) {
                    existingItem.imagePaths.add(imagePath);
                  }
                }
              } else {
                // New item, add to list
                _detectedItems.add(item);
              }

              // Add manual item images to scanned images list
              if (item.imagePaths.isNotEmpty) {
                for (final imagePath in item.imagePaths) {
                  if (!_scannedImages.contains(imagePath)) {
                    _scannedImages.add(imagePath);
                  }
                }
              }

              // Update estimated weight with calculated total
              final totalWeight = _getTotalWeightFromItems();
              if (totalWeight > 0) {
                _estimatedWeightController.text = totalWeight.toStringAsFixed(
                  2,
                );
              }

              // Run validation after adding item
              Future.microtask(() => _validatePosting());

              // Show warning if material not accepted
              if (!isAccepted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '⚠️ ${item.name} is not accepted by this junkshop',
                    ),
                    backgroundColor: AppColors.warningColor,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            });
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open manual add dialog: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _getTotalWeightFromItems() {
    // Sum up estimatedWeightKg from all items (regardless of unit)
    return _detectedItems.fold<double>(
      0.0,
      (acc, item) => acc + (item.estimatedWeightKg ?? 0.0),
    );
  }

  Widget _buildTotalValueSection() {
    // Calculate minimum and maximum total values
    double totalMinValue = 0.0;
    double totalMaxValue = 0.0;

    for (final item in _detectedItems) {
      // Use boosted prices if promotion is active, otherwise use base prices
      if (item.boostedPriceMin != null &&
          item.boostedPriceMin! > 0 &&
          item.boostedPriceMax != null &&
          item.boostedPriceMax! > 0) {
        totalMinValue += item.boostedPriceMin! * item.quantity;
        totalMaxValue += item.boostedPriceMax! * item.quantity;
      } else if (item.priceMin != null &&
          item.priceMin! > 0 &&
          item.priceMax != null &&
          item.priceMax! > 0) {
        totalMinValue += item.priceMin! * item.quantity;
        totalMaxValue += item.priceMax! * item.quantity;
      } else {
        // Fallback: estimatedValue is per-unit, multiply by quantity
        totalMinValue += item.estimatedValue * item.quantity;
        totalMaxValue += item.estimatedValue * item.quantity;
      }
    }

    return Column(
      children: [
        // Total Estimated Value Range
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Est. Price',
                style: AppTextStyles.labelMedium.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                (totalMinValue - totalMaxValue).abs() < 0.01
                    ? AppFormatters.currency(totalMinValue)
                    : '${AppFormatters.currency(totalMinValue)} - ${AppFormatters.currency(totalMaxValue)}',
                style: AppTextStyles.h4.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        // Estimated Total Weight Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: GestureDetector(
            onTap: _showWeightDialog,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Est. Total Weight',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _estimatedWeightController.text.isEmpty
                          ? (_getTotalWeightFromItems() > 0
                                ? _getTotalWeightFromItems().toStringAsFixed(2)
                                : '0.00')
                          : _estimatedWeightController.text,
                      style: AppTextStyles.h4.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'kg',
                      style: AppTextStyles.h4.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostButton() {
    final hasItems = _detectedItems.isNotEmpty;
    final hasValidationErrors = _validationResults.values.any(
      (result) => result is Map && result['pass'] == false,
    );

    // Check if there are any unacceptable items
    final hasUnacceptableItems = _detectedItems.any(
      (item) => item.isNotAcceptableByJunkshop,
    );

    final canPost =
        hasItems &&
        !hasValidationErrors &&
        !hasUnacceptableItems &&
        (!_hasActiveCollection || widget.editMode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // Validation message
          if (!hasItems)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 22,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add at least one item to continue',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Active collection warning for button
          if (hasItems && _hasActiveCollection && !widget.editMode)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warningColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 22,
                    color: AppColors.warningColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cannot post while you have an active collection',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.warningColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Action button(s)
          if (widget.editMode || widget.isRepost)
            // Edit/Repost mode: compact Cancel + Continue row
            Row(
              children: [
                // Cancel button — outlined, equal width
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(
                            'Cancel ${widget.isRepost ? 'Reposting' : 'Editing'}?',
                            style: AppTextStyles.h5.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          content: Text(
                            'Your changes will not be saved.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                              ),
                              child: const Text('Stay'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(this.context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.errorColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Discard'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorColor,
                      side: BorderSide(
                        color: AppColors.errorColor.withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Continue button — filled, equal width
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canPost && !hasValidationErrors
                        ? _proceedToScheduling
                        : null,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.textSecondary
                          .withValues(alpha: 0.2),
                      disabledForegroundColor: AppColors.textSecondary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            // Normal mode: Show full-width Continue button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: canPost
                    ? LinearGradient(
                        colors: [
                          AppColors.primaryGreen,
                          AppColors.primaryGreen.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canPost
                    ? null
                    : AppColors.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: canPost
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canPost && !hasValidationErrors
                      ? () {
                          // Double-check validation before proceeding
                          if (!hasValidationErrors) {
                            _proceedToScheduling();
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          color: canPost
                              ? Colors.white
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Continue to Schedule',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: canPost
                                ? Colors.white
                                : AppColors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: canPost
                              ? Colors.white
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Rule violations — shown BELOW the continue button
          if (_selectedJunkshop != null && _validationResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildValidationSummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildValidationSummary() {
    final failedEntries = _validationResults.entries
        .where((e) => e.value is Map && (e.value as Map)['pass'] == false)
        .toList();

    if (failedEntries.isEmpty) return const SizedBox.shrink();

    // Map key → label
    const ruleMeta = {
      'serviceRadius': 'Service Area',
      'minValue': 'Minimum Value',
      'weightRatio': 'Weight-to-Value Ratio',
      'categories': 'Accepted Materials',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF1F2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Posting Rules Not Met',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fix the issue${failedEntries.length > 1 ? 's' : ''} below or choose a different junkshop.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.red.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${failedEntries.length} issue${failedEntries.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rule items
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: failedEntries.asMap().entries.map((entry) {
                final idx = entry.key;
                final key = entry.value.key;
                final result = entry.value.value as Map<String, dynamic>;
                final label = ruleMeta[key] ?? key;
                final message = result['message'] as String? ?? '';
                final suggestion = result['suggestion'] as String?;
                final details = result['details'] as String?;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (idx != 0)
                      const Divider(
                        height: 20,
                        thickness: 1,
                        color: Color(0xFFFFCDD2),
                      ),
                    Text(
                      label,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.4,
                        fontSize: 12,
                      ),
                    ),
                    if (details != null && details.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: details
                            .split(', ')
                            .map(
                              (name) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Text(
                                  name,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.red.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (suggestion != null && suggestion.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Solution',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.amber.shade900,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              suggestion,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.amber.shade800,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87, // Dark overlay
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Creating your posting...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Uploading images and saving details',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Action methods
  // Current location and address now handled in Schedule Pickup screen.

  Future<void> _takePicture() async {
    try {
      // Open the custom square-viewfinder camera. Shows a live framing box
      // and auto-crops the centre square on capture — no second confirmation.
      final String? imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const SquareCameraScreen()),
      );
      if (imagePath == null || !mounted) return;

      if (mounted) {
        // Navigate to dedicated scanning screen
        final result = await Navigator.pushNamed(
          context,
          '/household/scan-material',
          arguments: {
            'imageFile': imagePath,
            'materialCatalog': _materialCatalog,
            'selectedJunkshop': _selectedJunkshop,
            'acceptedCategories': _acceptedCategories.toList(),
          },
        );

        if (result != null && result is Map<String, dynamic>) {
          final detectedItem = result['detectedItem'] as DetectedItem?;
          final imagePath = result['imagePath'] as String?;

          if (detectedItem != null && imagePath != null) {
            debugPrint(
              '[_takePicture] Received detectedItem: ${detectedItem.name}',
            );
            debugPrint(
              '[_takePicture] Initial estimatedValue: ${detectedItem.estimatedValue}',
            );
            debugPrint(
              '[_takePicture] Image paths: ${detectedItem.imagePaths}',
            );
            debugPrint('[_takePicture] Unit: ${detectedItem.unit}');

            // Add scanned image to uploaded images list
            if (imagePath.isNotEmpty && !_scannedImages.contains(imagePath)) {
              _scannedImages.add(imagePath);
              debugPrint(
                '[_takePicture] Added image to uploaded images: $imagePath',
              );
            }

            // Get per-unit pricing from catalog/Firebase (do not multiply by weight)
            final priceRange = await _getPriceRangeForCategory(
              detectedItem.name,
              weight: 1.0, // Always pass 1.0 to get per-unit prices
            );

            debugPrint('[_takePicture] Price range result: $priceRange');

            // Check for promotion boost
            final hasPromotion = _promotionMaterials.contains(
              detectedItem.category,
            );
            final boostPercentage = hasPromotion
                ? _promotionBoostPercentage
                : 0.0;

            // Store per-unit prices
            final priceMin = priceRange['min'] as double?;
            final priceMax = priceRange['max'] as double?;
            final avgPricePerUnit = priceMin != null && priceMax != null
                ? (priceMin + priceMax) / 2
                : 0.0;

            // If no prices found from priceRange, try fetching directly
            if ((priceMin == null || priceMin == 0.0) &&
                (priceMax == null || priceMax == 0.0)) {
              debugPrint(
                '[_takePicture] No prices from _getPriceRangeForCategory, trying direct material lookup',
              );

              // Try to find material in catalog directly
              if (_materialCatalog != null && _materialCatalog!.isNotEmpty) {
                final materialName = detectedItem.name.toLowerCase();
                final matchingMaterial = _materialCatalog!.firstWhere((
                  material,
                ) {
                  final matName = (material['name'] as String? ?? '')
                      .toLowerCase();
                  return matName.contains(materialName) ||
                      materialName.contains(matName);
                }, orElse: () => <String, dynamic>{});

                if (matchingMaterial.isNotEmpty) {
                  final directPriceMin =
                      (matchingMaterial['householdPriceMin'] as num?)
                          ?.toDouble() ??
                      0.0;
                  final directPriceMax =
                      (matchingMaterial['householdPriceMax'] as num?)
                          ?.toDouble() ??
                      0.0;
                  debugPrint(
                    '[_takePicture] Found direct prices: $directPriceMin - $directPriceMax',
                  );

                  // Update with direct prices
                  detectedItem.priceMin = directPriceMin;
                  detectedItem.priceMax = directPriceMax;
                  detectedItem.estimatedValue =
                      (directPriceMin + directPriceMax) / 2;
                }
              }
            } else {
              debugPrint(
                '[_takePicture] Fetched prices - min: $priceMin, max: $priceMax per unit',
              );
              debugPrint(
                '[_takePicture] Item quantity: ${detectedItem.quantity}, unit: ${detectedItem.unit}',
              );
            }

            final boostedPriceMin =
                hasPromotion && detectedItem.priceMin != null
                ? detectedItem.priceMin! * (1 + boostPercentage / 100)
                : detectedItem.priceMin ?? priceMin;
            final boostedPriceMax =
                hasPromotion && detectedItem.priceMax != null
                ? detectedItem.priceMax! * (1 + boostPercentage / 100)
                : detectedItem.priceMax ?? priceMax;
            final boostedAvgPerUnit =
                hasPromotion && detectedItem.estimatedValue > 0
                ? detectedItem.estimatedValue * (1 + boostPercentage / 100)
                : detectedItem.estimatedValue > 0
                ? detectedItem.estimatedValue
                : avgPricePerUnit;

            // Only apply catalog prices if they are valid (> 0).
            // Never overwrite good values set by the direct-lookup fallback with zeros.
            if ((detectedItem.priceMin == null ||
                    detectedItem.priceMin == 0.0) &&
                priceMin != null &&
                priceMin > 0) {
              detectedItem.priceMin = priceMin;
            }
            if ((detectedItem.priceMax == null ||
                    detectedItem.priceMax == 0.0) &&
                priceMax != null &&
                priceMax > 0) {
              detectedItem.priceMax = priceMax;
            }

            // Recalculate boosted prices from the final resolved priceMin/Max.
            final finalBoostedMin =
                hasPromotion &&
                    detectedItem.priceMin != null &&
                    detectedItem.priceMin! > 0
                ? detectedItem.priceMin! * (1 + boostPercentage / 100)
                : detectedItem.priceMin;
            final finalBoostedMax =
                hasPromotion &&
                    detectedItem.priceMax != null &&
                    detectedItem.priceMax! > 0
                ? detectedItem.priceMax! * (1 + boostPercentage / 100)
                : detectedItem.priceMax;
            detectedItem.boostedPriceMin = finalBoostedMin;
            detectedItem.boostedPriceMax = finalBoostedMax;

            // Update estimatedValue only when a better (non-zero) value is available.
            if (boostedAvgPerUnit > 0) {
              detectedItem.estimatedValue = boostedAvgPerUnit;
            } else if (avgPricePerUnit > 0) {
              detectedItem.estimatedValue = avgPricePerUnit;
            }
            // else: keep scan screen's estimatedValue as-is.

            detectedItem.promotionId = hasPromotion ? _activePromotionId : null;
            detectedItem.promotionBoostPercentage = hasPromotion
                ? boostPercentage
                : null;

            debugPrint(
              '[_takePicture] Final estimatedValue per unit: ${detectedItem.estimatedValue}',
            );
            debugPrint('[_takePicture] Promotion applied: $hasPromotion');
            debugPrint(
              '[_takePicture] Setting priceMin: $priceMin, priceMax: $priceMax',
            );
            debugPrint(
              '[_takePicture] Setting boostedPriceMin: $boostedPriceMin, boostedPriceMax: $boostedPriceMax',
            );
            debugPrint(
              '[_takePicture] Item unit before adding: ${detectedItem.unit}',
            );
            debugPrint(
              '[_takePicture] Item quantity: ${detectedItem.quantity}',
            );
            debugPrint(
              '[_takePicture] Item estimated weight kg: ${detectedItem.estimatedWeightKg}',
            );

            // Use category from price range if available (more accurate)
            if (priceRange['category'] != null) {
              detectedItem.category = priceRange['category'] as String;
            }

            // Ensure prices are set (they should have been set above)
            if (detectedItem.priceMin == null ||
                detectedItem.priceMax == null) {
              debugPrint(
                '[_takePicture] WARNING: Prices are null after assignment!',
              );
              debugPrint(
                '[_takePicture] priceMin: ${detectedItem.priceMin}, priceMax: ${detectedItem.priceMax}',
              );
            }

            // Keep the unit and image paths from scanning screen (already fetched from catalog)
            // detectedItem.unit and detectedItem.imagePaths are preserved

            // Directly add item to post without dialog
            if (mounted) {
              setState(() {
                _detectedItems.add(detectedItem);
              });

              // Show success feedback
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Added ${detectedItem.name} to your post',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.primaryGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            // Update estimated weight
            final totalWeight = _getTotalWeightFromItems();
            _estimatedWeightController.text = totalWeight > 0
                ? totalWeight.toStringAsFixed(2)
                : '';

            // Trigger validation
            if (_selectedJunkshop != null) {
              _validatePosting();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open camera. Please check permissions.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadPhoto() async {
    try {
      // Directly open gallery for photo selection
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        // Crop to square before AI scan — remove background, boost accuracy.
        final CroppedFile? cropped = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Frame the Material',
              toolbarColor: AppColors.primaryGreen,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Frame the Material',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );
        if (cropped == null || !mounted) return; // user cancelled

        final croppedXFile = XFile(cropped.path);

        // Show scanning animation while processing
        showScanningAnimation();

        try {
          // Compress the image if needed
          final File imageFile = File(croppedXFile.path);
          final fileSizeInBytes = await imageFile.length();
          final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

          XFile? compressedImage = croppedXFile;

          if (fileSizeInMB > 2.0) {
            final compressedResult =
                await FlutterImageCompress.compressAndGetFile(
                  croppedXFile.path,
                  '${croppedXFile.path}_compressed.jpg',
                  quality: 70,
                  minWidth: 1920,
                  minHeight: 1920,
                );
            if (compressedResult != null) {
              compressedImage = compressedResult;
            }
          }

          // Add to scanned images list
          setState(() {
            _scannedImages.add(compressedImage!.path);
          });

          // Close scanning animation
          if (mounted) Navigator.of(context).pop();
          if (!mounted) return;

          // Navigate to dedicated scanning screen
          final result = await Navigator.pushNamed(
            context,
            '/household/scan-material',
            arguments: {
              'imageFile': compressedImage.path,
              'materialCatalog': _materialCatalog,
              'selectedJunkshop': _selectedJunkshop,
              'acceptedCategories': _acceptedCategories.toList(),
            },
          );

          if (result != null && result is Map<String, dynamic>) {
            final detectedItem = result['detectedItem'] as DetectedItem?;
            final imagePath = result['imagePath'] as String?;

            if (detectedItem != null && imagePath != null) {
              debugPrint(
                '[_uploadPhoto] Received detectedItem: ${detectedItem.name}',
              );
              debugPrint(
                '[_uploadPhoto] Initial estimatedValue: ${detectedItem.estimatedValue}',
              );

              // Add scanned image to uploaded images list if not already there
              if (imagePath.isNotEmpty && !_scannedImages.contains(imagePath)) {
                _scannedImages.add(imagePath);
                debugPrint(
                  '[_uploadPhoto] Added image to uploaded images: $imagePath',
                );
              }

              // Get per-unit pricing from catalog/Firebase
              final priceRange = await _getPriceRangeForCategory(
                detectedItem.name,
                weight: 1.0, // Always pass 1.0 to get per-unit prices
              );

              debugPrint('[_uploadPhoto] Price range result: $priceRange');

              // Check for promotion boost
              final hasPromotion = _promotionMaterials.contains(
                detectedItem.category,
              );
              final boostPercentage = hasPromotion
                  ? _promotionBoostPercentage
                  : 0.0;

              // Store per-unit prices
              final priceMin = priceRange['min'] as double?;
              final priceMax = priceRange['max'] as double?;
              final avgPricePerUnit = priceMin != null && priceMax != null
                  ? (priceMin + priceMax) / 2
                  : 0.0;

              // If no prices found from priceRange, try fetching directly
              if ((priceMin == null || priceMin == 0.0) &&
                  (priceMax == null || priceMax == 0.0)) {
                debugPrint(
                  '[_uploadPhoto] No prices from _getPriceRangeForCategory, trying direct material lookup',
                );

                // Try to find material in catalog directly
                if (_materialCatalog != null && _materialCatalog!.isNotEmpty) {
                  final materialName = detectedItem.name.toLowerCase();
                  final matchingMaterial = _materialCatalog!.firstWhere((
                    material,
                  ) {
                    final matName = (material['name'] as String? ?? '')
                        .toLowerCase();
                    return matName.contains(materialName) ||
                        materialName.contains(matName);
                  }, orElse: () => <String, dynamic>{});

                  if (matchingMaterial.isNotEmpty) {
                    final directPriceMin =
                        (matchingMaterial['householdPriceMin'] as num?)
                            ?.toDouble() ??
                        0.0;
                    final directPriceMax =
                        (matchingMaterial['householdPriceMax'] as num?)
                            ?.toDouble() ??
                        0.0;
                    debugPrint(
                      '[_uploadPhoto] Found direct prices: $directPriceMin - $directPriceMax',
                    );

                    // Update with direct prices
                    detectedItem.priceMin = directPriceMin;
                    detectedItem.priceMax = directPriceMax;
                    detectedItem.estimatedValue =
                        (directPriceMin + directPriceMax) / 2;
                  }
                }
              } else {
                debugPrint(
                  '[_uploadPhoto] Fetched prices - min: $priceMin, max: $priceMax per unit',
                );
              }

              final boostedPriceMin =
                  hasPromotion && detectedItem.priceMin != null
                  ? detectedItem.priceMin! * (1 + boostPercentage / 100)
                  : detectedItem.priceMin ?? priceMin;
              final boostedPriceMax =
                  hasPromotion && detectedItem.priceMax != null
                  ? detectedItem.priceMax! * (1 + boostPercentage / 100)
                  : detectedItem.priceMax ?? priceMax;
              final boostedAvgPerUnit =
                  hasPromotion && detectedItem.estimatedValue > 0
                  ? detectedItem.estimatedValue * (1 + boostPercentage / 100)
                  : detectedItem.estimatedValue > 0
                  ? detectedItem.estimatedValue
                  : avgPricePerUnit;

              // Only apply catalog prices if they are valid (> 0).
              // Leaving priceMin/Max null lets _formatItemPrice fall back to estimatedValue.
              if ((detectedItem.priceMin == null ||
                      detectedItem.priceMin == 0.0) &&
                  priceMin != null &&
                  priceMin > 0) {
                detectedItem.priceMin = priceMin;
              }
              if ((detectedItem.priceMax == null ||
                      detectedItem.priceMax == 0.0) &&
                  priceMax != null &&
                  priceMax > 0) {
                detectedItem.priceMax = priceMax;
              }

              detectedItem.boostedPriceMin = boostedPriceMin;
              detectedItem.boostedPriceMax = boostedPriceMax;

              // Update estimatedValue only when a better (non-zero) value is available.
              if (boostedAvgPerUnit > 0) {
                detectedItem.estimatedValue = boostedAvgPerUnit;
              } else if (avgPricePerUnit > 0) {
                detectedItem.estimatedValue = avgPricePerUnit;
              }
              // else: keep scan screen's estimatedValue as-is.

              detectedItem.promotionId = hasPromotion
                  ? _activePromotionId
                  : null;
              detectedItem.promotionBoostPercentage = hasPromotion
                  ? boostPercentage
                  : null;

              debugPrint(
                '[_uploadPhoto] Final estimatedValue per unit: ${detectedItem.estimatedValue}',
              );
              debugPrint('[_uploadPhoto] Promotion applied: $hasPromotion');

              // Directly add item to post without dialog
              if (mounted) {
                setState(() {
                  _detectedItems.add(detectedItem);
                });

                // Show success feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Added ${detectedItem.name} to your post',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.primaryGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }

              // Update estimated weight
              final totalWeight = _getTotalWeightFromItems();
              _estimatedWeightController.text = totalWeight > 0
                  ? totalWeight.toStringAsFixed(2)
                  : '';

              // Trigger validation
              if (_selectedJunkshop != null) {
                _validatePosting();
              }
            }
          }
        } catch (processingError) {
          // Close scanning animation if it's still open
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }

          debugPrint('Processing error: $processingError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to process image: ${processingError.toString()}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not select image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void showScanningAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.successColor,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.search,
                      size: 50,
                      color: AppColors.successColor,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Scanning Image...',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI is analyzing waste materials',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void startScanningAnimation() {
    if (mounted) {
      _pulseController.repeat(reverse: true);
    }
  }

  void stopScanningAnimation() {
    if (mounted) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  Future<void> uploadPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        // Crop to square before AI scan — removes background, boosts accuracy.
        final CroppedFile? cropped = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Frame the Material',
              toolbarColor: AppColors.primaryGreen,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Frame the Material',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );
        if (cropped == null || !mounted) return; // user cancelled
        final imagePath = cropped.path;

        // Navigate to dedicated scanning screen
        final result = await Navigator.pushNamed(
          context,
          '/household/scan-material',
          arguments: {
            'imageFile': imagePath,
            'materialCatalog': _materialCatalog,
            'selectedJunkshop': _selectedJunkshop,
            'acceptedCategories': _acceptedCategories.toList(),
          },
        );

        if (result != null && result is Map<String, dynamic>) {
          final detectedItem = result['detectedItem'] as DetectedItem?;
          final imagePath = result['imagePath'] as String?;

          if (detectedItem != null && imagePath != null) {
            debugPrint(
              '[_uploadPhoto] Received detectedItem: ${detectedItem.name}',
            );
            debugPrint(
              '[_uploadPhoto] Initial estimatedValue: ${detectedItem.estimatedValue}',
            );
            debugPrint(
              '[_uploadPhoto] Image paths: ${detectedItem.imagePaths}',
            );
            debugPrint('[_uploadPhoto] Unit: ${detectedItem.unit}');

            // Add scanned image to uploaded images list
            if (imagePath.isNotEmpty && !_scannedImages.contains(imagePath)) {
              _scannedImages.add(imagePath);
              debugPrint(
                '[_uploadPhoto] Added image to uploaded images: $imagePath',
              );
            }

            // Get per-unit pricing from catalog/Firebase (do not multiply by weight)
            final priceRange = await _getPriceRangeForCategory(
              detectedItem.name,
              weight: 1.0, // Always pass 1.0 to get per-unit prices
            );

            debugPrint('[_uploadPhoto] Price range result: $priceRange');

            // Check for promotion boost
            final hasPromotion = _promotionMaterials.contains(
              detectedItem.category,
            );
            final boostPercentage = hasPromotion
                ? _promotionBoostPercentage
                : 0.0;

            // Store per-unit prices
            final priceMin = priceRange['min'] as double?;
            final priceMax = priceRange['max'] as double?;
            final avgPricePerUnit = priceMin != null && priceMax != null
                ? (priceMin + priceMax) / 2
                : 0.0;

            // If no prices found from priceRange, try fetching directly
            if ((priceMin == null || priceMin == 0.0) &&
                (priceMax == null || priceMax == 0.0)) {
              debugPrint(
                '[_uploadPhoto] No prices from _getPriceRangeForCategory, trying direct material lookup',
              );

              // Try to find material in catalog directly
              if (_materialCatalog != null && _materialCatalog!.isNotEmpty) {
                final materialName = detectedItem.name.toLowerCase();
                final matchingMaterial = _materialCatalog!.firstWhere((
                  material,
                ) {
                  final matName = (material['name'] as String? ?? '')
                      .toLowerCase();
                  return matName.contains(materialName) ||
                      materialName.contains(matName);
                }, orElse: () => <String, dynamic>{});

                if (matchingMaterial.isNotEmpty) {
                  final directPriceMin =
                      (matchingMaterial['householdPriceMin'] as num?)
                          ?.toDouble() ??
                      0.0;
                  final directPriceMax =
                      (matchingMaterial['householdPriceMax'] as num?)
                          ?.toDouble() ??
                      0.0;
                  debugPrint(
                    '[_uploadPhoto] Found direct prices: $directPriceMin - $directPriceMax',
                  );

                  // Update with direct prices
                  detectedItem.priceMin = directPriceMin;
                  detectedItem.priceMax = directPriceMax;
                  detectedItem.estimatedValue =
                      (directPriceMin + directPriceMax) / 2;
                }
              }
            } else {
              debugPrint(
                '[_uploadPhoto] Fetched prices - min: $priceMin, max: $priceMax, avg: $avgPricePerUnit',
              );
            }

            final boostedPriceMin =
                hasPromotion && detectedItem.priceMin != null
                ? detectedItem.priceMin! * (1 + boostPercentage / 100)
                : detectedItem.priceMin ?? priceMin;
            final boostedPriceMax =
                hasPromotion && detectedItem.priceMax != null
                ? detectedItem.priceMax! * (1 + boostPercentage / 100)
                : detectedItem.priceMax ?? priceMax;
            final boostedAvgPerUnit =
                hasPromotion && detectedItem.estimatedValue > 0
                ? detectedItem.estimatedValue * (1 + boostPercentage / 100)
                : detectedItem.estimatedValue > 0
                ? detectedItem.estimatedValue
                : avgPricePerUnit;

            // Only apply catalog prices if they are valid (> 0).
            if ((detectedItem.priceMin == null ||
                    detectedItem.priceMin == 0.0) &&
                priceMin != null &&
                priceMin > 0) {
              detectedItem.priceMin = priceMin;
            }
            if ((detectedItem.priceMax == null ||
                    detectedItem.priceMax == 0.0) &&
                priceMax != null &&
                priceMax > 0) {
              detectedItem.priceMax = priceMax;
            }

            detectedItem.boostedPriceMin = boostedPriceMin;
            detectedItem.boostedPriceMax = boostedPriceMax;

            // Update estimatedValue only when a better (non-zero) value is available.
            if (boostedAvgPerUnit > 0) {
              detectedItem.estimatedValue = boostedAvgPerUnit;
            } else if (avgPricePerUnit > 0) {
              detectedItem.estimatedValue = avgPricePerUnit;
            }
            // else: keep scan screen's estimatedValue as-is.

            detectedItem.promotionId = hasPromotion ? _activePromotionId : null;
            detectedItem.promotionBoostPercentage = hasPromotion
                ? boostPercentage
                : null;

            debugPrint(
              '[_uploadPhoto] Final estimatedValue per unit: ${detectedItem.estimatedValue}',
            );
            debugPrint('[_uploadPhoto] Promotion applied: $hasPromotion');
            debugPrint(
              '[_uploadPhoto] Setting priceMin: $priceMin, priceMax: $priceMax',
            );
            debugPrint(
              '[_uploadPhoto] Setting boostedPriceMin: $boostedPriceMin, boostedPriceMax: $boostedPriceMax',
            );

            // Use category from price range if available (more accurate)
            if (priceRange['category'] != null) {
              detectedItem.category = priceRange['category'] as String;
            }

            // Ensure prices are set (they should have been set above)
            if (detectedItem.priceMin == null ||
                detectedItem.priceMax == null) {
              debugPrint(
                '[_uploadPhoto] WARNING: Prices are null after assignment!',
              );
              debugPrint(
                '[_uploadPhoto] priceMin: ${detectedItem.priceMin}, priceMax: ${detectedItem.priceMax}',
              );
            }

            // Keep the unit and image paths from scanning screen (already fetched from catalog)
            // detectedItem.unit and detectedItem.imagePaths are preserved
            // Keep the unit from scanning screen (already fetched from catalog)
            debugPrint(
              '[_uploadPhoto] Keeping unit from scanning screen: ${detectedItem.unit}',
            );

            // Directly add item to post without dialog
            if (mounted) {
              setState(() {
                _detectedItems.add(detectedItem);
              });

              // Show success feedback
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Added ${detectedItem.name} to your post',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.primaryGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            // Update estimated weight
            final totalWeight = _getTotalWeightFromItems();
            _estimatedWeightController.text = totalWeight > 0
                ? totalWeight.toStringAsFixed(2)
                : '';

            // Trigger validation
            if (_selectedJunkshop != null) {
              _validatePosting();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not select image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> showAddItemDialog(DetectedItem item, String imagePath) async {
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );
    final weightKgController = TextEditingController(
      text: (item.estimatedWeightKg ?? 1.0).toStringAsFixed(2),
    );

    // Extract and normalize the unit
    String selectedUnit = item.unit
        .toLowerCase()
        .replaceAll(RegExp(r'[\d\.\s]+'), '')
        .trim();

    // Normalize unit variations to standard values
    if (selectedUnit == 'pieces' || selectedUnit == 'pc') {
      selectedUnit = 'pcs';
    }

    // Validate against allowed units
    if (!['kg', 'pcs', 'piece', 'lbs', 'g'].contains(selectedUnit)) {
      debugPrint(
        '[AddItemDialog] Unknown unit "$selectedUnit" from item.unit "${item.unit}", defaulting to kg',
      );
      selectedUnit = 'kg'; // fallback to kg
    } else {
      debugPrint(
        '[AddItemDialog] Using unit: $selectedUnit from item.unit: ${item.unit}',
      );
    }

    final isKgOnly = selectedUnit == 'kg';

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add to Post',
                      style: AppTextStyles.h6.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  item.category,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Show quantity + unit if unit is not kg
                    if (!isKgOnly) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quantity',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: quantityController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter quantity',
                                    prefixIcon: Icon(
                                      Icons.format_list_numbered,
                                      color: AppColors.primaryGreen,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppColors.primaryGreen,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Unit',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.borderLight,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusMd,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedUnit,
                                      isExpanded: true,
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: AppColors.primaryGreen,
                                      ),
                                      items: ['pcs', 'piece', 'lbs', 'g']
                                          .map(
                                            (unit) => DropdownMenuItem(
                                              value: unit,
                                              child: Text(unit),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() {
                                            selectedUnit = value;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Always show estimated weight in kg
                    Text(
                      isKgOnly ? 'Weight (kg)' : 'Est. Weight (kg)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: weightKgController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter weight in kg',
                        prefixIcon: Icon(
                          Icons.scale_outlined,
                          color: AppColors.primaryGreen,
                        ),
                        suffixText: 'kg',
                        suffixStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd,
                          ),
                          borderSide: BorderSide(
                            color: AppColors.primaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final weightKg =
                        double.tryParse(weightKgController.text) ?? 1.0;
                    final quantity = isKgOnly
                        ? weightKg.toInt()
                        : (double.tryParse(quantityController.text) ?? 1.0)
                              .toInt();

                    item.quantity = quantity;
                    item.unit = selectedUnit;
                    item.estimatedWeightKg = weightKg;

                    // Add item to list
                    setState(() {
                      _scannedImages.add(imagePath);
                      mergeDuplicateItems([item]);
                    });

                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                    ),
                  ),
                  child: Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> showScanOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Scanner',
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select image source for AI scanning',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Camera and Gallery options
            Row(
              children: [
                Expanded(
                  child: buildScanOptionTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppColors.primaryGreen,
                    onTap: () {
                      Navigator.pop(context);
                      _takePicture();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildScanOptionTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: AppColors.primaryBlue,
                    onTap: () {
                      Navigator.pop(context);
                      uploadPhoto();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Tips section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tips for best results',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ensure the image is clear and well-lit',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Capture only one item per image',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget buildScanOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Merge duplicate items by adding quantities instead of creating separate entries
  void mergeDuplicateItems(List<DetectedItem> newItems) {
    for (final newItem in newItems) {
      final existingItemIndex = _detectedItems.indexWhere(
        (existing) =>
            existing.name.toLowerCase() == newItem.name.toLowerCase() &&
            existing.unit.toLowerCase() == newItem.unit.toLowerCase(),
      );

      if (existingItemIndex != -1) {
        // Item already exists, merge by adding quantities
        final existingItem = _detectedItems[existingItemIndex];
        existingItem.quantity += newItem.quantity;
        // Update estimated value (additive)
        existingItem.estimatedValue += newItem.estimatedValue;
        // Merge image paths
        for (final imagePath in newItem.imagePaths) {
          if (!existingItem.imagePaths.contains(imagePath)) {
            existingItem.imagePaths.add(imagePath);
          }
        }
      } else {
        // New item, add to list
        _detectedItems.add(newItem);
      }
    }
  }

  void removeItem(DetectedItem item) {
    setState(() {
      _detectedItems.remove(item);
      // Update estimated weight after removing item
      final totalWeight = _getTotalWeightFromItems();
      _estimatedWeightController.text = totalWeight > 0
          ? totalWeight.toStringAsFixed(2)
          : '';
    });
    // Trigger validation after removing item
    if (_selectedJunkshop != null) {
      _validatePosting();
    }
  }

  void showQuantityDialog(DetectedItem item) {
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Quantity',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            item.name,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity (${item.unit})',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: item.unit,
                        suffixStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.primaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final newQuantity =
                              int.tryParse(quantityController.text) ??
                              item.quantity;
                          setState(() {
                            item.quantity = newQuantity;
                            final totalWeight = _getTotalWeightFromItems();
                            if (totalWeight > 0) {
                              _estimatedWeightController.text = totalWeight
                                  .toStringAsFixed(2);
                            } else {
                              _estimatedWeightController.clear();
                            }
                          });
                          Navigator.pop(ctx);
                          if (_selectedJunkshop != null) {
                            Future.microtask(() => _validatePosting());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Save Changes',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showWeightDialog() {
    final weightController = TextEditingController(
      text: _estimatedWeightController.text.isEmpty
          ? (_getTotalWeightFromItems() > 0
                ? _getTotalWeightFromItems().toStringAsFixed(2)
                : '')
          : _estimatedWeightController.text,
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Est. Total Weight',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Combined weight of all items',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Weight',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        suffixText: 'kg',
                        suffixStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.primaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Auto-calculated from items with known weight',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _estimatedWeightController.text =
                                weightController.text;
                          });
                          Navigator.pop(ctx);
                          if (_selectedJunkshop != null) {
                            Future.microtask(() => _validatePosting());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Save Changes',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void proceedToScheduling() {
    savePostingAndNavigate();
  }

  void showJunkshopRules() {
    if (_selectedJunkshop == null) return;

    final junkshopName = _selectedJunkshop!['name'] as String? ?? 'Junkshop';
    final distance =
        (_selectedJunkshop!['distance'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Rules',
                            style: AppTextStyles.h5.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            junkshopName,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Base Fee
                    if (_baseFee != null) ...[
                      buildRuleCard(
                        icon: Icons.payments_rounded,
                        iconColor: Colors.blue,
                        title: 'Base Collection Fee',
                        description:
                            'Minimum fee charged for any collection service, regardless of distance.',
                        details: [
                          RuleDetail(
                            label: 'Minimum Fee',
                            value: AppFormatters.currencyWhole(_baseFee!),
                            isHighlight: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Weight-to-Value Ratio
                    if (_maxWeightPerValueRatio != null) ...[
                      buildRuleCard(
                        icon: Icons.balance_rounded,
                        iconColor: Colors.orange,
                        title: 'Weight-to-Value Ratio',
                        description:
                            'Maximum weight of items allowed per ₱100 of estimated value. This ensures collections are economically viable.',
                        details: [
                          RuleDetail(
                            label: 'Maximum Ratio',
                            value:
                                '${_maxWeightPerValueRatio!.toStringAsFixed(1)} kg per ₱100',
                            isHighlight: true,
                          ),
                          RuleDetail(
                            label: 'Example',
                            value:
                                '₱100 = max ${_maxWeightPerValueRatio!.toStringAsFixed(0)} kg',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Accepted Categories
                    if (_acceptedCategories.isNotEmpty) ...[
                      buildRuleCard(
                        icon: Icons.category_rounded,
                        iconColor: Colors.green,
                        title: 'Accepted Material Categories',
                        description:
                            'This junkshop only accepts the following material types.',
                        categories: _acceptedCategories.toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Service Radius
                    if (_serviceRadius != null) ...[
                      buildRuleCard(
                        icon: Icons.location_on_rounded,
                        iconColor: Colors.purple,
                        title: 'Service Area',
                        description:
                            'This junkshop provides pickup service within a limited radius.',
                        details: [
                          RuleDetail(
                            label: 'Maximum Distance',
                            value: '${_serviceRadius!.toStringAsFixed(1)} km',
                            isHighlight: true,
                          ),
                          if (distance > 0 && distance <= _serviceRadius!)
                            RuleDetail(
                              label: 'Your Distance',
                              value:
                                  '${distance.toStringAsFixed(1)} km (Within range)',
                            ),
                          if (distance > 0 && distance > _serviceRadius!)
                            RuleDetail(
                              label: 'Your Distance',
                              value:
                                  '${distance.toStringAsFixed(1)} km (Outside range)',
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Operating Hours
                    if (_operatingHours != null) ...[
                      buildRuleCard(
                        icon: Icons.access_time_rounded,
                        iconColor: Colors.teal,
                        title: 'Operating Hours',
                        description:
                            'Pickup requests will only be processed during business hours.',
                        details: [
                          RuleDetail(
                            label: 'Business Hours',
                            value: _operatingHours!,
                            isHighlight: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    // No rules configured message
                    if (_baseFee == null &&
                        _maxWeightPerValueRatio == null &&
                        _serviceRadius == null &&
                        _operatingHours == null &&
                        _acceptedCategories.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Restrictions',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This junkshop has not configured any business rules. All postings are accepted.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    // Info footer
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryGreen.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'These rules help ensure your posting meets the junkshop\'s requirements before collection.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.darkGreen,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRuleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    List<RuleDetail>? details,
    List<String>? categories,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (details != null && details.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...details.map(
              (detail) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      detail.label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: detail.isHighlight
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: detail.isHighlight
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      detail.value,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: detail.isHighlight
                            ? AppColors.primaryGreen
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (categories != null && categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Upload images to Supabase Storage and return their public URLs
  Future<List<String>> uploadImagesToStorage(List<String> localPaths) async {
    if (kDebugMode) {
      print('🔍 _uploadImagesToStorage called with ${localPaths.length} paths');
    }

    if (localPaths.isEmpty) {
      if (kDebugMode) print('⚠️ No local paths provided');
      return [];
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (kDebugMode) print('No authenticated user - cannot upload images');
      return [];
    }

    if (kDebugMode) print('User authenticated: ${user.id}');
    // Upload all images in parallel for better performance
    final uploadFutures = localPaths.asMap().entries.map((entry) async {
      final i = entry.key;
      final localPath = entry.value;
      if (kDebugMode) print('🔍 Processing image $i: $localPath');

      try {
        // Remove 'file://' prefix if present
        final cleanPath = localPath.replaceFirst('file://', '');
        if (kDebugMode) print('🧹 Clean path: $cleanPath');

        final file = File(cleanPath);

        final exists = await file.exists();
        if (kDebugMode) print('📁 File exists: $exists');

        if (!exists) {
          if (kDebugMode) print('⚠️ File does not exist: $cleanPath');
          return null;
        }

        // Get file size for debugging
        final fileSize = await file.length();
        if (kDebugMode) print('📏 File size: $fileSize bytes');

        // Compress image before uploading
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          cleanPath,
          '${cleanPath}_compressed.jpg',
          quality: 70,
          minWidth: 1024,
          minHeight: 1024,
        );

        final fileToUpload = compressedFile != null
            ? File(compressedFile.path)
            : file;
        final compressedSize = await fileToUpload.length();
        if (kDebugMode) {
          print(
            '📉 Compressed size: $compressedSize bytes (${((1 - compressedSize / fileSize) * 100).toStringAsFixed(1)}% reduction)',
          );
        }

        // Create a unique filename using timestamp and index
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = '${user.id}/posting_${timestamp}_$i.jpg';

        if (kDebugMode) {
          print('Starting upload to Supabase Storage: $storagePath');
        }

        final downloadUrl = await uploadPublicFile(
          bucket: 'posting-images',
          path: storagePath,
          file: fileToUpload,
        );

        if (kDebugMode) print('Image uploaded successfully: $downloadUrl');        return downloadUrl;
      } catch (e, stackTrace) {
        if (kDebugMode) print('❌ Failed to upload image $i: $e');
        if (kDebugMode) print('❌ Stack trace: $stackTrace');
        return null;
      }
    });

    // Wait for all uploads to complete in parallel
    final results = await Future.wait(uploadFutures);

    // Filter out null results (failed uploads)
    final uploadedUrls = results.whereType<String>().toList();

    if (kDebugMode) {
      print(
        '📊 Upload complete: ${uploadedUrls.length} of ${localPaths.length} images uploaded',
      );
    }
    return uploadedUrls;
  }

  Future<void> savePostingAndNavigate() async {
    // Double-check validation before proceeding
    final hasValidationErrors = _validationResults.values.any(
      (result) => result is Map && result['pass'] == false,
    );

    if (hasValidationErrors) {
      debugPrint('[SavePosting] ❌ Cannot proceed - validation errors exist');
      debugPrint(
        '[SavePosting] Failed validations: ${_validationResults.entries.where((e) => e.value is Map && (e.value as Map)['pass'] == false).map((e) => e.key).join(', ')}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please fix all validation errors before proceeding',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      return;
    }

    debugPrint('[SavePosting] ✅ All validations passed, proceeding...');

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final householdId = user?.id ?? 'anonymous';
      String? householdName;
      String? householdPhone;
      String? addressShort;
      String? fullAddress; // Full address from household profile
      try {
        // Best-effort read from users profile for denormalization
        final data = user == null
            ? null
            : await Supabase.instance.client
                  .from('households')
                  .select()
                  .eq('id', user.id)
                  .maybeSingle();        final fullName = (data?['full_name'] ?? data?['name'])?.toString();
        final phone =
            (data?['phone'] ?? data?['phoneNumber'] ?? data?['phone_number'])
                ?.toString();
        final city = data?['city']?.toString();
        final province = data?['province']?.toString();
        final address = data?['address']?.toString();
        final rawLocation = data?['location'];
        final location = (rawLocation is Map
                ? rawLocation['address']
                : rawLocation)
            ?.toString(); // Full address field

        if (fullName != null && fullName.isNotEmpty) householdName = fullName;
        if (phone != null && phone.isNotEmpty) householdPhone = phone;

        // Store full address for display
        if (location != null && location.isNotEmpty) {
          fullAddress = location;
        } else if (address != null && address.isNotEmpty) {
          fullAddress = address;
        }

        // Build short address for storage
        if (city != null && city.isNotEmpty) {
          addressShort = (province != null && province.isNotEmpty)
              ? '$city, $province'
              : city;
        } else if (province != null && province.isNotEmpty) {
          addressShort = province;
        } else if (address != null && address.isNotEmpty) {
          addressShort = address;
        }
      } catch (_) {
        // ignore profile fetch errors; repo will also try
      }

      // Navigate immediately to schedule screen with local paths
      // Images will be uploaded later when the posting is actually created
      if (kDebugMode) print('🚀 Navigating to schedule screen immediately...');

      final total = _detectedItems.fold<double>(
        0.0,
        (acc, it) => acc + it.estimatedValue,
      );

      // Compute boosted min/max the same way as _buildTotalValueSection
      double totalMin = 0.0;
      double totalMax = 0.0;
      for (final item in _detectedItems) {
        if (item.boostedPriceMin != null && item.boostedPriceMax != null) {
          totalMin += item.boostedPriceMin! * item.quantity;
          totalMax += item.boostedPriceMax! * item.quantity;
        } else if (item.priceMin != null && item.priceMax != null) {
          totalMin += item.priceMin! * item.quantity;
          totalMax += item.priceMax! * item.quantity;
        } else {
          totalMin += item.estimatedValue;
          totalMax += item.estimatedValue;
        }
      }

      if (!mounted) return;

      // Prepare schedule arguments (include existing data if in edit mode)
      final scheduleArguments = {
        'junkshopName':
            _selectedJunkshop?['name'] as String? ?? 'Any Available',
        'totalEstimatedValue': _roundToTwoDecimals(totalMin),
        'totalEstimatedValueMax': _roundToTwoDecimals(totalMax),
        'location': _locationController.text.isNotEmpty
            ? _locationController.text
            : (fullAddress ?? addressShort ?? 'Not specified'),
        'itemCount': _detectedItems.length,
        // Pass items with local paths - will be uploaded when posting is saved
        'items': _detectedItems
            .map(
              (item) => {
                'name': item.name,
                'category': item.category,
                'quantity': _roundToTwoDecimals(item.quantity.toDouble()),
                'unit': item.unit,
                'estimatedValue': _roundToTwoDecimals(item.estimatedValue),
                'imagePaths': item.imagePaths, // Local paths for now
                'isAiScanned': item.isAiScanned,
                'priceMin': item.priceMin != null
                    ? _roundToTwoDecimals(item.priceMin!)
                    : 0.0,
                'priceMax': item.priceMax != null
                    ? _roundToTwoDecimals(item.priceMax!)
                    : 0.0,
                'baseUnit': item.baseUnit,
                if (item.promotionId != null) 'promotionId': item.promotionId,
                if (item.promotionId != null &&
                    item.promotionBoostPercentage != null)
                  'promotionBoostPercentage': _roundToTwoDecimals(
                    item.promotionBoostPercentage!,
                  ),
              },
            )
            .toList(),
      };

      // Always pass edit mode status to schedule screen
      scheduleArguments['isEditMode'] = widget.editMode;

      // If in edit mode, include existing schedule data
      if (widget.editMode && widget.postingData != null) {
        final unavailableDates =
            widget.postingData!['unavailableDates'] as List<dynamic>?;
        if (unavailableDates != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          // Convert stored dates to DateTime and filter out past dates
          scheduleArguments['existingDates'] = unavailableDates
              .map((date) {
                return toDateTime(date) ?? DateTime.now();
              })
              .where((dateTime) {
                final dateOnly = DateTime(
                  dateTime.year,
                  dateTime.month,
                  dateTime.day,
                );
                return !dateOnly.isBefore(today);
              })
              .toList();

          // If all dates were filtered out, don't pass the existingDates
          if ((scheduleArguments['existingDates'] as List).isEmpty) {
            scheduleArguments.remove('existingDates');
            if (kDebugMode) {
              print(
                '📅 All existing dates were in the past, removed from schedule arguments',
              );
            }
          }
        }

        final scheduledTime = widget.postingData!['scheduledTime'] as String?;
        if (scheduledTime != null && scheduledTime.isNotEmpty) {
          scheduleArguments['existingTimeSlot'] = scheduledTime;
        }

        final specialInstructions =
            widget.postingData!['specialInstructions'] as String?;
        if (specialInstructions != null && specialInstructions.isNotEmpty) {
          scheduleArguments['existingInstructions'] = specialInstructions;
        }
      }

      final scheduleData =
          await Navigator.pushNamed(
                context,
                '/household-schedule-pickup',
                arguments: scheduleArguments,
              )
              as Map<String, dynamic>?;

      if (!mounted) return;

      // If user confirmed the schedule, create the posting
      if (scheduleData != null) {
        await createPosting(
          scheduleData,
          householdId,
          householdName,
          householdPhone,
          addressShort,
          total,
        );
      } else {
        if (kDebugMode) {
          print('⚠️ User cancelled schedule selection. Posting not created.');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print('❌ Navigation error: $e');
      if (kDebugMode) print('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to proceed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> createPosting(
    Map<String, dynamic> scheduleData,
    String householdId,
    String? householdName,
    String? householdPhone,
    String? addressShort,
    double total,
  ) async {
    // ── 1. Snapshot all widget-owned state before navigating away ──
    final snapshotItems = List<DetectedItem>.from(_detectedItems);
    final snapshotJunkshop = _selectedJunkshop != null
        ? Map<String, dynamic>.from(_selectedJunkshop!)
        : null;
    final snapshotInstructions = _instructionsController.text;
    final snapshotLocation = _locationController.text;
    final snapshotWeight = _estimatedWeightController.text;
    final snapshotAddresses = _savedAddresses
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    final snapshotAddressKey = _selectedAddressKey;
    final isEditMode = widget.editMode;
    final editPostingId = widget.postingId;

    // ── 2. Navigate to Track tab immediately so user isn't blocked ──
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/household-home',
      (route) => false,
      arguments: {'initialIndex': 2},
    );

    // ── 3. Upload & save in background via PostingUploadService ──
    final uploadService = getIt<PostingUploadService>();
    uploadService.run((updateMsg) async {
      // Step 1: Separate local paths from existing uploaded URLs
      final localPathsSet = <String>{};
      final existingUrlsSet = <String>{};
      for (final item in snapshotItems) {
        for (final path in item.imagePaths) {
          if (path.startsWith('http://') || path.startsWith('https://')) {
            existingUrlsSet.add(path);
          } else {
            localPathsSet.add(path);
          }
        }
      }
      final localPathsToUpload = localPathsSet.toList();
      final existingUrls = existingUrlsSet.toList();

      // Step 2: Upload new local images
      updateMsg('Uploading images\u2026');
      List<String> uploadedUrls = [];
      if (localPathsToUpload.isNotEmpty) {
        uploadedUrls = await uploadImagesToStorage(localPathsToUpload);
      }

      // Step 3: Build local-path → uploaded-URL map
      final pathToUrlMap = <String, String>{};
      for (final url in existingUrls) {
        pathToUrlMap[url] = url;
      }
      if (uploadedUrls.length == localPathsToUpload.length) {
        for (int i = 0; i < localPathsToUpload.length; i++) {
          pathToUrlMap[localPathsToUpload[i]] = uploadedUrls[i];
        }
      }

      // Step 4: Map items, replacing local paths with uploaded URLs
      final itemsWithUploadedImages = snapshotItems.map((item) {
        final finalPaths = item.imagePaths.isNotEmpty
            ? item.imagePaths.map((p) => pathToUrlMap[p] ?? p).toList()
            : null;
        return PostingItemDto(
          name: item.name,
          category: item.category,
          quantity: item.quantity,
          unit: item.unit,
          estimatedValue: item.estimatedValue,
          priceMin: item.priceMin,
          priceMax: item.priceMax,
          baseUnit: item.baseUnit,
          isAiScanned: item.isAiScanned,
          imagePaths: finalPaths,
          promotionBoostPercentage: item.promotionBoostPercentage,
          promotionId: item.promotionId,
        );
      }).toList();

      // Step 5: Schedule data
      final unavailableDates = scheduleData['dates'] as List<DateTime>?;
      final fromTime = scheduleData['fromTime'] as String?;
      final toTime = scheduleData['toTime'] as String?;
      final timeSlot = (fromTime != null && toTime != null)
          ? '$fromTime - $toTime'
          : null;
      final estimatedWeight = snapshotWeight.isNotEmpty
          ? double.tryParse(snapshotWeight)
          : null;

      // Step 6: Fetch junkshop profile details
      updateMsg('Creating your post\u2026');
      String? junkshopAddress;
      String? junkshopPhone;
      double? junkshopRating;
      if (snapshotJunkshop != null) {
        junkshopAddress =
            snapshotJunkshop[UserFields.address] as String? ??
            snapshotJunkshop['business_address'] as String? ??
            snapshotJunkshop[UserFields.businessAddress] as String? ??
            snapshotJunkshop[UserFields.location] as String?;
        junkshopPhone =
            snapshotJunkshop[UserFields.phone] as String? ??
            snapshotJunkshop[UserFields.phoneNumber] as String? ??
            snapshotJunkshop['contact'] as String?;
        junkshopRating = (snapshotJunkshop[UserFields.rating] as num?)
            ?.toDouble();

        if (snapshotJunkshop['id'] != null &&
            (junkshopAddress == null || junkshopPhone == null)) {
          try {
            final jsId = snapshotJunkshop['id'] as String;
            final d = await Supabase.instance.client
                .from('junkshops')
                .select()
                .eq('id', jsId)
                .maybeSingle();
            if (d != null) {
              junkshopAddress ??=
                  d[UserFields.address] as String? ??
                  d['business_address'] as String? ??
                  d[UserFields.businessAddress] as String? ??
                  d[UserFields.location] as String?;
              junkshopPhone ??=
                  d[UserFields.phone] as String? ??
                  d[UserFields.phoneNumber] as String? ??
                  d['contact_number'] as String?;
              junkshopRating ??= (d[UserFields.rating] as num?)?.toDouble();
            }
          } catch (_) {}
        }
      }

      // Step 7: Household coordinates from saved address
      double? householdLat;
      double? householdLng;
      String? householdNote;
      if (snapshotAddressKey != 'manual' && snapshotAddresses.isNotEmpty) {
        final sa = snapshotAddresses.firstWhere(
          (a) => a['key'] == snapshotAddressKey,
          orElse: () => {},
        );
        if (sa.isNotEmpty) {
          final lat = sa['lat'];
          final lng = sa['lng'];
          if (lat != null && lng != null) {
            householdLat = lat is num
                ? lat.toDouble()
                : double.tryParse(lat.toString());
            householdLng = lng is num
                ? lng.toDouble()
                : double.tryParse(lng.toString());
          }
          if (sa['note'] != null && sa['note'].toString().isNotEmpty) {
            householdNote = sa['note'].toString();
          }
        }
      }

      // Step 8: Junkshop coordinates
      double? junkshopLat;
      double? junkshopLng;
      if (snapshotJunkshop != null) {
        final lat = snapshotJunkshop[UserFields.lat];
        final lng = snapshotJunkshop[UserFields.lng];
        if (lat != null && lng != null) {
          junkshopLat = lat is num
              ? lat.toDouble()
              : double.tryParse(lat.toString());
          junkshopLng = lng is num
              ? lng.toDouble()
              : double.tryParse(lng.toString());
        }
      }

      // Step 9: Create posting DTO and save
      final posting = PostingDto(
        householdId: householdId,
        items: itemsWithUploadedImages,
        totalEstimatedValue: total,
        estimatedTotalWeight: estimatedWeight,
        notes: snapshotInstructions.isNotEmpty ? snapshotInstructions : null,
        householdName: householdName,
        householdPhone: householdPhone,
        householdAddress: snapshotLocation.isNotEmpty ? snapshotLocation : null,
        addressShort: addressShort,
        householdLat: householdLat,
        householdLng: householdLng,
        assignedJunkshopId: snapshotJunkshop?['id'] as String?,
        assignedJunkshopName: snapshotJunkshop?['name'] as String?,
        assignedJunkshopAddress: junkshopAddress,
        assignedJunkshopPhone: junkshopPhone,
        assignedJunkshopRating: junkshopRating,
        assignedJunkshopLat: junkshopLat,
        assignedJunkshopLng: junkshopLng,
        pickupLocation: householdNote,
        unavailableDates: unavailableDates,
        scheduledTime: timeSlot,
        specialInstructions: scheduleData['specialInstructions'] as String?,
      );

      final repo = getIt<IHouseholdPostingRepository>();
      String postingId;
      if (isEditMode && editPostingId != null) {
        await repo.updatePosting(editPostingId, posting);
        postingId = editPostingId;
      } else {
        postingId = await repo.createPosting(posting);
      }

      // Step 10: Create conversation for new postings
      if (!isEditMode &&
          snapshotJunkshop != null &&
          snapshotJunkshop['id'] != null) {
        try {
          final chatRepo = ChatRepository();
          final currentUser = Supabase.instance.client.auth.currentUser;
          if (currentUser != null) {
            final householdData =
                await Supabase.instance.client
                    .from('households')
                    .select()
                    .eq('id', householdId)
                    .maybeSingle() ??
                {};
            final householdProfileImage =
                householdData['profileImage'] as String? ??
                householdData['profile_image_url'] as String?;

            final jsId = snapshotJunkshop['id'] as String;
            final jsName = snapshotJunkshop['name'] as String? ?? 'Junkshop';
            final jsProfileImage = snapshotJunkshop['profileImage'] as String?;

            final itemsList = snapshotItems
                .map(
                  (i) =>
                      '\u2022 ${i.name} (${i.quantity.toStringAsFixed(1)} ${i.unit})',
                )
                .join('\n');

            final conversationId = await chatRepo.createConversation(
              postingId: postingId,
              participants: [householdId, jsId],
              participantDetails: {
                householdId: ParticipantDetails(
                  name: householdName ?? 'Household',
                  role: 'household',
                  profileImage: householdProfileImage,
                  joinedAt: DateTime.now(),
                ),
                jsId: ParticipantDetails(
                  name: jsName,
                  role: 'junkshop',
                  profileImage: jsProfileImage,
                  joinedAt: DateTime.now(),
                ),
              },
              initialMessage:
                  '\ud83d\udce6 New Collection Request\n\nPosting ID: $postingId\n\nItems:\n$itemsList',
            );

            await Supabase.instance.client
                .from('postings')
                .update({'conversation_id': conversationId})
                .eq('id', postingId);

            getIt<ConversationSyncService>().syncConversationWithPosting(
              householdId,
              postingId,
              conversationId,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('\u26a0\ufe0f Failed to create conversation: $e');
          }
        }
      }
    }).ignore();
  }

  /// Show junkshop rules dialog with business controls
  void _showJunkshopRules() {
    final junkshopName = _selectedJunkshop?['name'] as String? ?? 'Junkshop';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$junkshopName Business Rules',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_baseFee != null) ...[
                        _buildRuleItem(
                          icon: Icons.attach_money,
                          title: 'Base Collection Fee',
                          value: '₱${_baseFee!.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_serviceRadius != null) ...[
                        _buildRuleItem(
                          icon: Icons.location_on,
                          title: 'Service Radius',
                          value: '${_serviceRadius!.toStringAsFixed(1)} km',
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_maxWeightPerValueRatio != null) ...[
                        _buildRuleItem(
                          icon: Icons.scale,
                          title: 'Max Weight/Value Ratio',
                          value:
                              '${_maxWeightPerValueRatio!.toStringAsFixed(1)} kg per peso',
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_operatingHours != null) ...[
                        _buildRuleItem(
                          icon: Icons.access_time,
                          title: 'Operating Hours',
                          value: _operatingHours!,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_acceptedCategories.isNotEmpty) ...[
                        _buildRuleItem(
                          icon: Icons.category,
                          title: 'Accepted Categories',
                          value: _acceptedCategories.join(', '),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_materialCatalog != null &&
                          _materialCatalog!.isNotEmpty) ...[
                        const Divider(height: 24),
                        const Text(
                          'Material Prices',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._materialCatalog!.take(5).map((material) {
                          final name = material['name'] as String? ?? 'Unknown';
                          final minPrice =
                              (material['householdPriceMin'] as num?)
                                  ?.toDouble() ??
                              0.0;
                          final maxPrice =
                              (material['householdPriceMax'] as num?)
                                  ?.toDouble() ??
                              0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  '₱${minPrice.toStringAsFixed(2)} - ₱${maxPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (_materialCatalog!.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context); // Close the rules sheet
                                if (_selectedJunkshop != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          JunkshopProfileScreen(
                                            shop: _selectedJunkshop!,
                                          ),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View all ${_materialCatalog!.length} materials',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: AppColors.primaryGreen,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      if (_baseFee == null && _serviceRadius == null) ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No business rules configured for this junkshop yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoTipEntry(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTile({
    required BuildContext sheetContext,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    if (isPrimary) {
      return Expanded(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(sheetContext);
            onTap();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: AppColors.primaryGreen.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          Navigator.pop(sheetContext);
          onTap();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: AppColors.primaryGreen),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show scanning options bottom sheet
  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.document_scanner_rounded,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Your Items',
                        style: AppTextStyles.h6.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AI will detect and price your materials',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(sheetCtx),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Buttons row
            Row(
              children: [
                _buildScanTile(
                  sheetContext: sheetCtx,
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  onTap: _takePicture,
                  isPrimary: true,
                ),
                const SizedBox(width: 12),
                _buildScanTile(
                  sheetContext: sheetCtx,
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: _uploadPhoto,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Photo tips card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Colors.grey.shade500,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tips for Better AI Detection',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildPhotoTipEntry(
                    Icons.crop_free_rounded,
                    'Fill the frame with just the material',
                  ),
                  _buildPhotoTipEntry(
                    Icons.wb_sunny_outlined,
                    'Use good lighting — avoid shadows',
                  ),
                  _buildPhotoTipEntry(
                    Icons.center_focus_strong_outlined,
                    'Keep the item centered and in focus',
                  ),
                  _buildPhotoTipEntry(
                    Icons.layers_clear_outlined,
                    'Avoid cluttered or busy backgrounds',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Remove detected item from list
  void _removeItem(DetectedItem item) {
    setState(() {
      _detectedItems.remove(item);
      // Update estimated weight
      final totalWeight = _getTotalWeightFromItems();
      _estimatedWeightController.text = totalWeight > 0
          ? totalWeight.toStringAsFixed(2)
          : '';

      // Trigger validation
      if (_selectedJunkshop != null) {
        _validatePosting();
      }
    });
  }

  /// Show quantity editing dialog
  void _showQuantityDialog(DetectedItem item) {
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Quantity',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            item.name,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity (${item.unit})',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: item.unit,
                        suffixStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.primaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final newQuantity =
                              int.tryParse(quantityController.text) ??
                              item.quantity;
                          if (newQuantity > 0) {
                            setState(() {
                              item.quantity = newQuantity;
                              if (item.priceMin != null &&
                                  item.priceMin! > 0 &&
                                  item.priceMax != null &&
                                  item.priceMax! > 0) {
                                item.estimatedValue =
                                    (item.priceMin! + item.priceMax!) / 2;
                              }
                            });
                            Navigator.pop(ctx);
                            _validatePosting();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Save Changes',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show weight dialog for manual weight entry
  void _showWeightDialog() {
    final weightController = TextEditingController(
      text: _estimatedWeightController.text.isEmpty
          ? (_getTotalWeightFromItems() > 0
                ? _getTotalWeightFromItems().toStringAsFixed(2)
                : '')
          : _estimatedWeightController.text,
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Est. Total Weight',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Combined weight of all items',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Weight',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        suffixText: 'kg',
                        suffixStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.primaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Auto-calculated from items with known weight',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final weight = double.tryParse(weightController.text);
                          if (weight != null && weight > 0) {
                            setState(() {
                              _estimatedWeightController.text = weight
                                  .toStringAsFixed(2);
                            });
                          }
                          Navigator.pop(ctx);
                          if (_selectedJunkshop != null) {
                            Future.microtask(() => _validatePosting());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Save Changes',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Proceed to scheduling screen
  void _proceedToScheduling() {
    if (_detectedItems.isEmpty && _scannedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one item or photo before proceeding',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedJunkshop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a junkshop'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Delegate to savePostingAndNavigate which awaits the schedule result
    // and runs the background upload via PostingUploadService
    savePostingAndNavigate();
  }
}

/// Enhanced manual item addition modal with photo, category, conditions
class ManualAddItemModal extends StatefulWidget {
  final List<Map<String, dynamic>> materialCatalog;
  final Function(DetectedItem) onAddItem;
  final String? junkshopId;
  final String? activePromotionId;
  final List<String> promotionMaterials;
  final double promotionBoostPercentage;

  const ManualAddItemModal({
    super.key,
    required this.materialCatalog,
    required this.onAddItem,
    this.junkshopId,
    this.activePromotionId,
    this.promotionMaterials = const [],
    this.promotionBoostPercentage = 0.0,
  });

  @override
  State<ManualAddItemModal> createState() => _ManualAddItemModalState();
}

class _ManualAddItemModalState extends State<ManualAddItemModal> {
  String? _selectedCategory;
  String? _selectedItemName;
  bool _isCustomCategory = false;
  final _customCategoryController = TextEditingController();
  final _customItemNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String _selectedUnit = 'kg'; // Default unit (matches Firebase materials)
  String? _selectedImagePath;

  // Category items built dynamically from Firebase materials
  Map<String, List<Map<String, dynamic>>> get _categoryItems {
    if (widget.materialCatalog.isEmpty) {
      return {};
    }

    final Map<String, List<Map<String, dynamic>>> categorized = {};

    for (final material in widget.materialCatalog) {
      final category = (material['category'] as String?) ?? 'others';
      final categoryKey =
          category.substring(0, 1).toUpperCase() + category.substring(1);
      final itemName = (material['name'] as String?)?.trim();

      if (itemName == null || itemName.isEmpty) continue;

      if (!categorized.containsKey(categoryKey)) {
        categorized[categoryKey] = [];
      }

      // Check if this item name already exists in this category (case-insensitive)
      final alreadyExists = categorized[categoryKey]!.any(
        (item) =>
            (item['name'] as String).toLowerCase() == itemName.toLowerCase(),
      );

      if (!alreadyExists) {
        categorized[categoryKey]!.add({
          'name': itemName,
          'unit': material['unit'],
          'price': material['price'],
          'householdPriceMin': material['householdPriceMin'],
          'householdPriceMax': material['householdPriceMax'],
          'isActive': material['isActive'] ?? true,
          'is_recyclable': true,
        });
      }
    }

    return categorized;
  }

  // Helper to get category status based on materials
  String _getCategoryStatus(String category) {
    final items = _categoryItems[category] ?? [];
    if (items.isEmpty) return 'inactive';

    final activeCount = items.where((item) => item['isActive'] == true).length;

    if (activeCount == 0) return 'inactive'; // All inactive - red
    if (activeCount == items.length) return 'active'; // All active - green
    return 'partial'; // Some active, some inactive - orange
  }

  // Helper to get category color based on status
  Color _getCategoryColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.primaryGreen;
      case 'partial':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return AppColors.primaryGreen;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _customCategoryController.dispose();
    _customItemNameController.dispose();
    super.dispose();
  }

  Widget _buildCompactSourceTile({
    required BuildContext sheetContext,
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(sheetContext);
          _pickImage(source);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_rounded,
                      color: AppColors.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Add Item Photo',
                      style: AppTextStyles.h6.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetCtx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCompactSourceTile(
                    sheetContext: sheetCtx,
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    source: ImageSource.camera,
                  ),
                  const SizedBox(width: 56),
                  _buildCompactSourceTile(
                    sheetContext: sheetCtx,
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    source: ImageSource.gallery,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _addItem() async {
    // Resolve category and item name (custom or selected)
    final effectiveCategory = _isCustomCategory
        ? _customCategoryController.text.trim()
        : _selectedCategory;
    final effectiveItemName = _isCustomCategory
        ? _customItemNameController.text.trim()
        : _selectedItemName;

    // Validation
    if (effectiveItemName == null || effectiveItemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name')),
      );
      return;
    }

    if (effectiveCategory == null || effectiveCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a category')),
      );
      return;
    }

    final qty = int.tryParse(_quantityController.text) ?? 1;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be at least 1')),
      );
      return;
    }

    debugPrint('[AddItem] Looking for material: $effectiveItemName');
    debugPrint(
      '[AddItem] Catalog has ${widget.materialCatalog.length} materials',
    );

    // Fetch junkshop-specific pricing if junkshop is selected
    double priceMin = 0.0;
    double priceMax = 10.0;
    String? materialId;
    String? category = effectiveCategory;
    bool isRecyclable = true;
    String resolvedUnit = _selectedUnit;

    if (widget.junkshopId != null) {
      try {
        debugPrint(
          '[AddItem] Fetching junkshop prices for: $_selectedItemName',
        );
        final materialDocs = rowsToDocs(
          'junkshop_materials',
          await Supabase.instance.client
              .from('junkshop_materials')
              .select()
              .eq('junkshop_id', widget.junkshopId!)
              .eq('is_active', true),
        );

        // Find matching material
        for (final data in materialDocs) {
          final name = (data['name'] as String?)?.toLowerCase().trim() ?? '';
          final searchTerm = effectiveItemName.toLowerCase().trim();

          if (name == searchTerm ||
              name.contains(searchTerm) ||
              searchTerm.contains(name)) {
            materialId = data['id']?.toString();
            priceMin = (data['householdPriceMin'] as num?)?.toDouble() ?? 0.0;
            priceMax = (data['householdPriceMax'] as num?)?.toDouble() ?? 10.0;
            category = data['category'] as String? ?? _selectedCategory;
            isRecyclable = (data['isRecyclable'] ?? data['is_recyclable']) as bool? ?? true;
            resolvedUnit = (data['unit'] as String?)?.isNotEmpty == true
                ? data['unit'] as String
                : _selectedUnit;

            debugPrint(
              '[AddItem] Found in junkshop: ${data['name']} (ID: $materialId)',
            );
            debugPrint('[AddItem] Base prices: ₱$priceMin - ₱$priceMax');
            break;
          }
        }
      } catch (e) {
        debugPrint('[AddItem] Error fetching junkshop prices: $e');
      }
    }

    // If not found in junkshop, fall back to catalog
    if (materialId == null) {
      final material = widget.materialCatalog.firstWhere(
        (m) {
          final materialName = m['name']?.toString().toLowerCase() ?? '';
          final searchName = effectiveItemName.toLowerCase();
          return materialName == searchName;
        },
        orElse: () => {
          'name': effectiveItemName,
          'category': effectiveCategory,
          'householdPriceMin': 0.0,
          'householdPriceMax': 10.0,
          'unit': 'piece',
          'is_recyclable': true,
        },
      );
      priceMin = (material['householdPriceMin'] ?? 0.0).toDouble();
      priceMax = (material['householdPriceMax'] ?? 10.0).toDouble();
      category = material['category'] as String? ?? _selectedCategory;
      isRecyclable = material['is_recyclable'] ?? true;
      resolvedUnit = (material['unit'] as String?)?.isNotEmpty == true
          ? material['unit'] as String
          : _selectedUnit;
      debugPrint('[AddItem] Using catalog prices: ₱$priceMin - ₱$priceMax');
    }

    // Apply promotion boost if eligible
    final hasPromotion =
        widget.activePromotionId != null &&
        materialId != null &&
        widget.promotionMaterials.contains(materialId);
    final boostMultiplier = hasPromotion
        ? (1.0 + (widget.promotionBoostPercentage / 100.0))
        : 1.0;

    if (hasPromotion) {
      debugPrint(
        '[Promotion] ✅ Applying ${widget.promotionBoostPercentage}% boost to $effectiveItemName',
      );
      debugPrint('[Promotion] Original: ₱$priceMin - ₱$priceMax');
    }

    final boostedPriceMin = priceMin * boostMultiplier;
    final boostedPriceMax = priceMax * boostMultiplier;
    final avgPrice = (boostedPriceMin + boostedPriceMax) / 2;

    if (hasPromotion) {
      debugPrint('[Promotion] Boosted: ₱$boostedPriceMin - ₱$boostedPriceMax');
    }

    final item = DetectedItem(
      name: effectiveItemName,
      category: category ?? 'others',
      confidence: 1.0,
      isRecyclable: isRecyclable,
      quantity: qty,
      unit: resolvedUnit,
      estimatedValue: avgPrice * qty,
      isAiScanned: false,
      imagePaths: _selectedImagePath != null ? [_selectedImagePath!] : [],
      priceMin: priceMin,
      priceMax: priceMax,
      boostedPriceMin: boostedPriceMin,
      boostedPriceMax: boostedPriceMax,
      baseUnit: resolvedUnit,
      promotionBoostPercentage: hasPromotion
          ? widget.promotionBoostPercentage
          : null,
      promotionId: hasPromotion ? widget.activePromotionId : null,
    );

    widget.onAddItem(item);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Item',
                        style: AppTextStyles.h5.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fill in the details of your recyclable item',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade100),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Photo section ──
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryGreen.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: _selectedImagePath != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    File(_selectedImagePath!),
                                    width: double.infinity,
                                    height: 140,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedImagePath = null,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 26,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add Photo',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Optional — tap to upload',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Category ──
                  _buildSectionLabel('Category'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._categoryItems.keys.map((category) {
                        final isSelected =
                            !_isCustomCategory && _selectedCategory == category;
                        final status = _getCategoryStatus(category);
                        final statusColor = _getCategoryColor(status);
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedCategory = category;
                            _selectedItemName = null;
                            _isCustomCategory = false;
                            _customCategoryController.clear();
                            _customItemNameController.clear();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? statusColor
                                  : statusColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: isSelected
                                    ? statusColor
                                    : statusColor.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              category,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isSelected ? Colors.white : statusColor,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }),
                      // "Other" chip
                      GestureDetector(
                        onTap: () => setState(() {
                          _isCustomCategory = true;
                          _selectedCategory = null;
                          _selectedItemName = null;
                          _customCategoryController.clear();
                          _customItemNameController.clear();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _isCustomCategory
                                ? AppColors.primaryGreen
                                : const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: _isCustomCategory
                                  ? AppColors.primaryGreen
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Other',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: _isCustomCategory
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: _isCustomCategory
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Custom category + item name fields
                  if (_isCustomCategory) ...[
                    const SizedBox(height: 20),
                    _buildCleanTextField(
                      controller: _customCategoryController,
                      label: 'Category Name',
                      hint: 'e.g. Electronics, Furniture…',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _buildCleanTextField(
                      controller: _customItemNameController,
                      label: 'Item Name',
                      hint: 'e.g. Old Laptop, Wooden Chair…',
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  // Item name dropdown (catalog mode)
                  if (!_isCustomCategory) ...[
                    const SizedBox(height: 24),
                    _buildSectionLabel('Item Name'),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedCategory != null
                              ? AppColors.primaryGreen.withValues(alpha: 0.3)
                              : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedItemName,
                        hint: Text(
                          _selectedCategory == null
                              ? 'Select a category first'
                              : 'Choose item type',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primaryGreen,
                        ),
                        items: _selectedCategory == null
                            ? []
                            : (_categoryItems[_selectedCategory] ?? []).map((
                                itemData,
                              ) {
                                final itemName = itemData['name'] as String;
                                final isActive = itemData['isActive'] ?? true;
                                return DropdownMenuItem<String>(
                                  value: itemName,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          itemName,
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: isActive
                                                    ? AppColors.textPrimary
                                                    : Colors.grey,
                                              ),
                                        ),
                                      ),
                                      if (!isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.red.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            'Unavailable',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  color: Colors.red,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        onChanged: _selectedCategory == null
                            ? null
                            : (value) {
                                if (value != null) {
                                  final itemData =
                                      (_categoryItems[_selectedCategory] ?? [])
                                          .firstWhere(
                                            (item) => item['name'] == value,
                                            orElse: () => {
                                              'unit': 'kg',
                                              'isActive': true,
                                            },
                                          );
                                  final isActive = itemData['isActive'] ?? true;
                                  if (!isActive) {
                                    if (mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            title: Row(
                                              children: [
                                                const Icon(
                                                  Icons.block_rounded,
                                                  color: Colors.red,
                                                  size: 28,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Material Unavailable',
                                                    style: AppTextStyles.h6
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'This material is currently not being accepted by the junkshop.',
                                                  style: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                        color: AppColors
                                                            .textSecondary,
                                                        height: 1.5,
                                                      ),
                                                ),
                                                const SizedBox(height: 16),
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors
                                                        .primaryGreen
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors
                                                          .primaryGreen
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.chat_rounded,
                                                        color: AppColors
                                                            .primaryGreen,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          'You can message the junkshop directly in the Inbox to inquire about this material.',
                                                          style: AppTextStyles
                                                              .bodySmall
                                                              .copyWith(
                                                                color: AppColors
                                                                    .darkGreen,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(
                                                  'Got it',
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.primaryGreen,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    }
                                    return;
                                  }
                                  setState(() {
                                    _selectedItemName = value;
                                    _selectedUnit =
                                        itemData['unit'] as String? ?? 'kg';
                                  });
                                }
                              },
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // ── Quantity & Unit ──
                  _buildSectionLabel('Quantity & Unit'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildStepperButton(
                          icon: Icons.remove_rounded,
                          onTap: () {
                            final current =
                                int.tryParse(_quantityController.text) ?? 1;
                            if (current > 1) {
                              setState(
                                () => _quantityController.text = (current - 1)
                                    .toString(),
                              );
                            }
                          },
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h6.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        _buildStepperButton(
                          icon: Icons.add_rounded,
                          onTap: () {
                            final current =
                                int.tryParse(_quantityController.text) ?? 1;
                            setState(
                              () => _quantityController.text = (current + 1)
                                  .toString(),
                            );
                          },
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.grey.shade300,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              _selectedUnit,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // ── Add button ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: _addItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Add Item',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.labelMedium.copyWith(
        fontSize: 11,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCleanTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF5F6FA),
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.primaryGreen),
      ),
    );
  }
}

// Custom painter for bounding box overlay
class BoundingBoxPainter extends CustomPainter {
  final Map<String, double> boundingBox;
  final String label;

  BoundingBoxPainter({required this.boundingBox, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    if (kDebugMode) {
      print(
        '[BBoxPainter] paint() called - Canvas size: ${size.width}x${size.height}',
      );
    }
    if (kDebugMode) print('[BBoxPainter] Raw bbox data: $boundingBox');

    // Extract normalized coordinates (0-1)
    final x = boundingBox['x']!;
    final y = boundingBox['y']!;
    final w = boundingBox['width']!;
    final h = boundingBox['height']!;

    if (kDebugMode) {
      print('[BBoxPainter] Normalized coords - x: $x, y: $y, w: $w, h: $h');
    }

    // Convert to pixel coordinates (YOLO uses center x,y format)
    final centerX = x * size.width;
    final centerY = y * size.height;
    final width = w * size.width;
    final height = h * size.height;

    // Calculate top-left corner
    final left = centerX - (width / 2);
    final top = centerY - (height / 2);

    if (kDebugMode) {
      print(
        '[BBoxPainter] Pixel coords - left: $left, top: $top, width: $width, height: $height',
      );
    }

    final rect = Rect.fromLTWH(left, top, width, height);
    if (kDebugMode) print('[BBoxPainter] Drawing rect: $rect');

    // Draw semi-transparent fill
    final fillPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Draw bright bounding box border
    final borderPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRect(rect, borderPaint);

    // Draw corner markers for better visibility
    final cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // Top-left corner
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(left + width, top),
      Offset(left + width - cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + width, top),
      Offset(left + width, top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(left, top + height),
      Offset(left + cornerLength, top + height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + height),
      Offset(left, top + height - cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(left + width, top + height),
      Offset(left + width - cornerLength, top + height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + width, top + height),
      Offset(left + width, top + height - cornerLength),
      cornerPaint,
    );

    // Draw label if provided
    if (label.isNotEmpty) {
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width > 200 ? 14.0 : 10.0,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              offset: const Offset(1, 1),
              blurRadius: 3,
            ),
          ],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Draw label background
      final labelPadding = 4.0;
      final labelRect = Rect.fromLTWH(
        left,
        top - textPainter.height - labelPadding * 2,
        textPainter.width + labelPadding * 2,
        textPainter.height + labelPadding * 2,
      );
      final labelBgPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      canvas.drawRect(labelRect, labelBgPaint);

      // Draw label text
      textPainter.paint(
        canvas,
        Offset(left + labelPadding, top - textPainter.height - labelPadding),
      );
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) {
    return oldDelegate.boundingBox != boundingBox || oldDelegate.label != label;
  }
}
