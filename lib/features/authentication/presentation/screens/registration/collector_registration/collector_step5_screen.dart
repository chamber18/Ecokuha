import 'package:flutter/material.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../../core/supabase/supabase_helpers.dart' as sb;
import '../../../../../../core/constants/firestore_fields/index.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/theme/app_dimensions.dart';
import '../../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../../core/utils/user_collection_helper.dart';

class CollectorStep5Screen extends StatefulWidget {
  const CollectorStep5Screen({super.key});

  @override
  State<CollectorStep5Screen> createState() => _CollectorStep5ScreenState();
}

class _CollectorStep5ScreenState extends State<CollectorStep5Screen> {
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isLoadingJunkshops = true;
  String? _selectedJunkShop;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _junkShops = [];
  List<Map<String, dynamic>> _filteredJunkShops = [];

  // Data from previous steps
  Map<String, dynamic> _collectedData = {};

  @override
  void initState() {
    super.initState();
    _loadJunkshops();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load data passed from previous steps
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _collectedData = Map<String, dynamic>.from(args);
    }
  }

  Future<void> _loadJunkshops() async {
    setState(() {
      _isLoadingJunkshops = true;
    });

    try {
      // Query junkshop users from junkshops collection
      final docs = await UserCollectionHelper.queryUsersByRole('junkshop');

      final junkshops = <Map<String, dynamic>>[];

      for (final data in docs) {

        // Skip junkshops disabled by admin
        if (data['isActive'] == false) continue;

        // Extract business name
        String businessName = 'Unknown Junkshop';
        if (data[UserFields.junkshopProfile] != null &&
            data[UserFields.junkshopProfile]['business'] != null &&
            data[UserFields.junkshopProfile]['business'][UserFields
                    .businessName] !=
                null) {
          businessName =
              data[UserFields.junkshopProfile]['business'][UserFields
                      .businessName]
                  .toString()
                  .trim();
        } else if (data[UserFields.businessName] != null) {
          businessName = data[UserFields.businessName].toString().trim();
        } else if (data[UserFields.name] != null) {
          businessName = data[UserFields.name].toString().trim();
        }

        if (businessName.isEmpty) businessName = 'Unknown Junkshop';

        // Extract address and phone
        String? address;
        String? phone;

        if (data[UserFields.junkshopProfile] != null &&
            data[UserFields.junkshopProfile][UserFields.location] != null) {
          address =
              data[UserFields.junkshopProfile][UserFields.location][UserFields
                      .address]
                  ?.toString();
        } else {
          address = data[UserFields.address]?.toString();
        }

        // Try multiple locations for phone number
        if (data[UserFields.junkshopProfile] != null &&
            data[UserFields.junkshopProfile]['business'] != null &&
            data[UserFields.junkshopProfile]['business'][UserFields.phone] !=
                null) {
          phone = data[UserFields.junkshopProfile]['business'][UserFields.phone]
              ?.toString();
        } else if (data[UserFields.junkshopProfile] != null &&
            data[UserFields.junkshopProfile]['contact'] != null &&
            data[UserFields.junkshopProfile]['contact'][UserFields.phone] !=
                null) {
          phone = data[UserFields.junkshopProfile]['contact'][UserFields.phone]
              ?.toString();
        } else if (data[UserFields.phone] != null) {
          phone = data[UserFields.phone]?.toString();
        }

        // Average rating is maintained by a DB trigger on the junkshops row
        final averageRating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;

        junkshops.add({
          'id': data['id'],
          'name': businessName,
          'address': address ?? 'Address not set',
          'distance': '${2.5 + (junkshops.length * 0.8)} km',
          'rating': averageRating,
          'status': 'Open', // All junkshops considered open for now
          'phone': phone ?? 'Not provided',
          'acceptedMaterials': [
            'Plastic',
            'Metal',
            'Paper',
            'Glass',
            'Cardboard',
          ],
          'operatingHours': '8:00 AM - 5:00 PM',
          'verified': true, // All registered junkshops considered verified
          'image': data[UserFields.profileImageUrl]
              ?.toString(), // Profile image
        });
      }

      setState(() {
        _junkShops = junkshops;
        _filteredJunkShops = List.from(junkshops);
        _isLoadingJunkshops = false;
      });
    } catch (e) {
      debugPrint('Error loading junkshops: $e');
      setState(() {
        _isLoadingJunkshops = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load junk shops: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterJunkShops(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredJunkShops = List.from(_junkShops);
      } else {
        _filteredJunkShops = _junkShops
            .where(
              (shop) =>
                  shop['name'].toLowerCase().contains(query.toLowerCase()) ||
                  shop['address'].toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  void _selectJunkShop(String junkShopId) {
    setState(() {
      _selectedJunkShop = junkShopId;
    });
  }

  Future<String?> _uploadDocumentImage(
    File imageFile,
    String userId,
    String documentType,
  ) async {
    try {
      debugPrint('Starting upload for $documentType...');
      debugPrint('File path: ${imageFile.path}');
      debugPrint('File exists: ${await imageFile.exists()}');

      if (!await imageFile.exists()) {
        debugPrint('ERROR: File does not exist!');
        return null;
      }

      final fileName =
          '${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final objectPath = '$userId/collector/$fileName';
      debugPrint('Storage path: documents/$objectPath');

      final storedPath = await sb.uploadPrivateDocument(
        path: objectPath,
        file: imageFile,
      );
      debugPrint('Upload complete for $documentType: $storedPath');

      return storedPath;
    } catch (e, stackTrace) {
      debugPrint('ERROR uploading document image $documentType: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  void _submitApplication() async {
    if (_isSubmitting) {
      debugPrint('Submission already in progress, ignoring duplicate request');
      return;
    }

    if (_selectedJunkShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a junk shop to partner with'),
          backgroundColor: AppColors.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isSubmitting = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Try collect data passed via previous steps if any
      final args = ModalRoute.of(context)?.settings.arguments;
      Map<String, dynamic> collected = {};
      if (args is Map<String, dynamic>) {
        collected = Map<String, dynamic>.from(args);
      }

      // Extract personal data - check if it's already in personal object or at root level
      final existingPersonal = collected['personal'] as Map<String, dynamic>?;
      final personal = {
        'full_name':
            (existingPersonal?['full_name'] ?? collected['fullName'] ?? '')
                .toString()
                .trim(),
        'date_of_birth':
            (existingPersonal?['date_of_birth'] ??
                    collected['dateOfBirth'] ??
                    '')
                .toString()
                .trim(),
        'phone': (existingPersonal?['phone'] ?? collected['phone'] ?? '')
            .toString()
            .trim()
            .replaceAll(' ', ''),
      };
      final contact =
          (collected['contact'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          <String, dynamic>{};

      // Vehicle data - filter out deprecated fields (make, model, color)
      final vehicleRaw =
          (collected['vehicle'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          <String, dynamic>{};

      // Only keep type, capacity, and plate_number
      final vehicle = <String, dynamic>{
        'type': vehicleRaw['type'] ?? '',
        'capacity': vehicleRaw['capacity'] ?? '',
        'plate_number': vehicleRaw['plate_number'] ?? '',
      };

      // Upload document images to the private documents bucket and store object paths
      debugPrint('=== Starting document upload process ===');
      debugPrint('Collected data keys: ${collected.keys.toList()}');

      final documentFiles =
          collected['documentFiles'] as Map<String, dynamic>? ?? {};
      debugPrint('Document files received: ${documentFiles.keys.toList()}');

      final documents = <String, dynamic>{};

      for (final entry in documentFiles.entries) {
        debugPrint('Processing ${entry.key}: ${entry.value?.runtimeType}');

        if (entry.value != null && entry.value is File) {
          final file = entry.value as File;
          debugPrint('Uploading ${entry.key} to Storage...');

          final url = await _uploadDocumentImage(file, user.id, entry.key);

          if (url != null) {
            documents[entry.key] = url;
            debugPrint('✅ Successfully uploaded ${entry.key}: $url');
          } else {
            debugPrint('❌ Failed to upload ${entry.key}');
            documents[entry.key] = false;
          }
        } else {
          debugPrint('⚠️ ${entry.key} has no file or invalid type');
          documents[entry.key] = false;
        }
      }

      debugPrint('Final documents map: $documents');
      debugPrint('=== Document upload process complete ===');

      // Get current application attempts and increment
      final currentAttempts = collected['application_attempts'] as int? ?? 0;
      final newAttempts = currentAttempts + 1;

      final payload = <String, dynamic>{
        if ((personal['full_name'] as String).isNotEmpty)
          'full_name': personal['full_name'],
        if ((personal['phone'] as String).isNotEmpty) 'phone': personal['phone'],
        if ((vehicle['type'] as String? ?? '').isNotEmpty)
          'vehicle_type': vehicle['type'],
        'collector_profile': {
          'personal': personal,
          'contact': contact,
          'vehicle': vehicle,
          'documents': documents,
          'preferred_junkshop_id': _selectedJunkShop,
        },
        'preferred_junkshop_id': _selectedJunkShop,
        'application_status': 'pending',
        'application_attempts': newAttempts,
        'is_profile_complete': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await UserCollectionHelper.getUserDocument(
        user.id,
        'collector',
      ).set(payload, merge: true);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth/collector-pending',
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }
  }

  void _previousStep() {
    // Prevent going back if submission is in progress
    if (_isSubmitting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait while your application is being submitted',
          ),
          backgroundColor: AppColors.warningColor,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.pop(context);
  }

  void _viewJunkShopDetails(Map<String, dynamic> junkShop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildJunkShopDetailsSheet(junkShop),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Show message if trying to go back during submission
        if (_isSubmitting) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please wait while your application is being submitted',
              ),
              backgroundColor: AppColors.warningColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: SafeArea(
          child: Column(
            children: [
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: AppDimensions.spacing16),

                      // Review Section
                      _buildReviewSection(),

                      // Divider
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacing24,
                          vertical: AppDimensions.spacing16,
                        ),
                        height: 1,
                        color: AppColors.borderLight,
                      ),

                      // Partner Selection Title
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacing24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.storefront,
                                  color: AppColors.collectorPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: AppDimensions.spacing8),
                                Text(
                                  'Select Partner Junk Shop',
                                  style: AppTextStyles.h6.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spacing4),
                            Text(
                              'Choose a verified junk shop to partner with for your collection routes',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Search Bar
                      _buildSearchBar(),

                      // Junk Shops List
                      _buildJunkShopsList(),

                      // Continue Button
                      _buildContinueButton(),
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

  Widget _buildReviewSection() {
    // Extract data from collected data (Step 1: Personal info)
    final fullName = _collectedData['fullName'] as String? ?? '';
    final dateOfBirth = _collectedData['dateOfBirth'] as String? ?? '';
    final phone = _collectedData['phone'] as String? ?? '';

    // Step 2: Contact info
    final contactInfo =
        _collectedData['contact'] as Map<String, dynamic>? ?? {};
    final address = contactInfo['address'] as String? ?? '';
    final latitude = contactInfo['latitude'];
    final longitude = contactInfo['longitude'];

    // Step 3: Vehicle info
    final vehicleInfo =
        _collectedData['vehicle'] as Map<String, dynamic>? ?? {};
    final vehicleType = vehicleInfo['type'] as String? ?? '';
    final brandModel = vehicleInfo['brand'] as String? ?? '';
    final plateNumber = vehicleInfo['plate_number'] as String? ?? '';
    final fuelType = vehicleInfo['fuel_type'] as String? ?? '';
    final capacity = vehicleInfo['capacity'] as String? ?? '';

    // Step 4: Documents
    final documentsInfo =
        _collectedData['documents'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              const Icon(
                Icons.assignment_turned_in,
                color: AppColors.collectorPrimary,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                'Application Review',
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.collectorPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Personal Information Card
          if (fullName.isNotEmpty || dateOfBirth.isNotEmpty || phone.isNotEmpty)
            _buildReviewCard(
              icon: Icons.person,
              title: 'Personal Information',
              items: [
                if (fullName.isNotEmpty) 'Full Name: $fullName',
                if (dateOfBirth.isNotEmpty) 'Date of Birth: $dateOfBirth',
                if (phone.isNotEmpty) 'Contact Number: $phone',
              ],
            ),

          if (fullName.isNotEmpty || dateOfBirth.isNotEmpty || phone.isNotEmpty)
            const SizedBox(height: AppDimensions.spacing12),

          // Contact Details Card
          if (address.isNotEmpty || (latitude != null && longitude != null))
            _buildReviewCard(
              icon: Icons.location_on,
              title: 'Contact Details',
              items: [
                if (address.isNotEmpty) 'Address: $address',
                if (latitude != null && longitude != null)
                  'GPS Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
              ],
            ),

          if (address.isNotEmpty || (latitude != null && longitude != null))
            const SizedBox(height: AppDimensions.spacing12),

          // Vehicle Information Card
          if (vehicleType.isNotEmpty ||
              brandModel.isNotEmpty ||
              plateNumber.isNotEmpty ||
              fuelType.isNotEmpty ||
              capacity.isNotEmpty)
            _buildReviewCard(
              icon: Icons.local_shipping,
              title: 'Vehicle Information',
              items: [
                if (vehicleType.isNotEmpty) 'Vehicle Type: $vehicleType',
                if (brandModel.isNotEmpty) 'Brand/Model: $brandModel',
                if (plateNumber.isNotEmpty) 'Plate Number: $plateNumber',
                if (fuelType.isNotEmpty) 'Fuel Type: $fuelType',
                if (capacity.isNotEmpty) 'Load Capacity: $capacity',
              ],
            ),

          if (vehicleType.isNotEmpty ||
              brandModel.isNotEmpty ||
              plateNumber.isNotEmpty ||
              fuelType.isNotEmpty ||
              capacity.isNotEmpty)
            const SizedBox(height: AppDimensions.spacing12),

          // Documents Card
          if (documentsInfo.isNotEmpty)
            _buildReviewCard(
              icon: Icons.folder_open,
              title: 'Submitted Documents',
              items: [
                if (documentsInfo['validId'] == true) 'Valid ID: ✓ Uploaded',
                if (documentsInfo['driversLicense'] == true)
                  'Driver\'s License: ✓ Uploaded',
                if (documentsInfo['vehicleRegistration'] == true)
                  'Vehicle OR/CR: ✓ Uploaded',
                if (documentsInfo['vehiclePhoto'] == true)
                  'Vehicle Photo: ✓ Uploaded',
                if (documentsInfo['selfieWithVehicle'] == true)
                  'Selfie with Vehicle: ✓ Uploaded',
              ],
            ),

          if (documentsInfo.isNotEmpty)
            const SizedBox(height: AppDimensions.spacing16),

          // Note about verification
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: AppColors.infoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(
                color: AppColors.infoColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.infoColor, size: 16),
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    'All information will be verified before approval. Ensure all details are accurate.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.infoColor,
                      fontWeight: FontWeight.w500,
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

  Widget _buildReviewCard({
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            children: [
              Icon(icon, color: AppColors.collectorPrimary, size: 16),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing8),

          // Card Content
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: TextField(
        controller: _searchController,
        onChanged: _filterJunkShops,
        decoration: InputDecoration(
          hintText: 'Search junk shops...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _filterJunkShops('');
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(
              color: AppColors.collectorPrimary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: AppColors.backgroundLight,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing16,
          ),
        ),
      ),
    );
  }

  Widget _buildJunkShopsList() {
    if (_isLoadingJunkshops) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spacing24),
          child: CircularProgressIndicator(color: AppColors.collectorPrimary),
        ),
      );
    }

    if (_filteredJunkShops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppDimensions.spacing16),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No junk shops found'
                    : 'No junk shops available',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Text(
                _searchController.text.isNotEmpty
                    ? 'Try adjusting your search terms'
                    : 'Please contact support for assistance',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Horizontal scrolling list of junk shop cards
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
        ),
        itemCount: _filteredJunkShops.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppDimensions.spacing16),
        itemBuilder: (context, index) {
          final junkShop = _filteredJunkShops[index];
          return SizedBox(
            width: 280,
            child: _buildJunkShopCard(junkShop, index),
          );
        },
      ),
    );
  }

  Widget _buildJunkShopCard(Map<String, dynamic> junkShop, int index) {
    final isSelected = _selectedJunkShop == junkShop['id'];

    return GestureDetector(
      onTap: () => _selectJunkShop(junkShop['id']),
      onLongPress: () => _viewJunkShopDetails(junkShop),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.collectorPrimary, width: 3)
              : null,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.collectorPrimary.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 17 : 20),
          child: Stack(
            children: [
              // Background gradient
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: index % 3 == 0
                        ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                        : index % 3 == 1
                        ? [const Color(0xFF3B82F6), const Color(0xFF1E40AF)]
                        : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Profile image if available
              if (junkShop['image'] != null &&
                  (junkShop['image'] as String).startsWith('http'))
                Positioned.fill(
                  child: Image.network(
                    junkShop['image'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox.shrink();
                    },
                  ),
                ),

              // Rating badge (top right)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    junkShop['rating'] > 0
                        ? '⭐ ${(junkShop['rating'] as double).toStringAsFixed(1)}'
                        : '⭐ No ratings',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Selected indicator (top left)
              if (isSelected)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.collectorPrimary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.collectorPrimary.withValues(
                            alpha: 0.5,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.check, color: Colors.white, size: 18),
                    ),
                  ),
                ),

              // Bottom overlay with info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 108,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                junkShop['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _viewJunkShopDetails(junkShop),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                junkShop['address'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          junkShop['distance'],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJunkShopDetailsSheet(Map<String, dynamic> junkShop) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.radiusXl),
          topRight: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacing24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.collectorPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.storefront,
                            color: AppColors.collectorPrimary,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacing16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    junkShop['name'],
                                    style: AppTextStyles.h5.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (junkShop['verified'])
                                  const Icon(
                                    Icons.verified,
                                    color: AppColors.successColor,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: AppColors.warningColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  junkShop['rating'] > 0
                                      ? '${(junkShop['rating'] as double).toStringAsFixed(1)} rating'
                                      : 'No ratings yet',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Contact Information
                  _buildDetailSection('Contact Information', [
                    _buildDetailItem(Icons.phone, 'Phone', junkShop['phone']),
                    _buildDetailItem(
                      Icons.location_on,
                      'Address',
                      junkShop['address'],
                    ),
                    _buildDetailItem(
                      Icons.schedule,
                      'Operating Hours',
                      junkShop['operatingHours'],
                    ),
                  ]),

                  const SizedBox(height: AppDimensions.spacing32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          onPressed: () => Navigator.pop(context),
                          text: 'Cancel',
                          isOutlined: true,
                          backgroundColor: Colors.white,
                          textColor: AppColors.collectorPrimary,
                          borderColor: AppColors.collectorPrimary,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacing12),
                      Expanded(
                        child: CustomButton(
                          onPressed: () {
                            _selectJunkShop(junkShop['id']);
                            Navigator.pop(context);
                          },
                          text: 'Select Shop',
                          backgroundColor: AppColors.collectorPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(value, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    final selectedShop = _selectedJunkShop != null
        ? _junkShops.firstWhere((shop) => shop['id'] == _selectedJunkShop)
        : null;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (selectedShop != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              decoration: BoxDecoration(
                color: AppColors.collectorPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: AppColors.collectorPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Partner:',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.collectorPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedShop['name'],
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    selectedShop['address'],
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacing16),
          ],
          Row(
            children: [
              Expanded(
                flex: 1,
                child: CustomButton(
                  onPressed: _isSubmitting ? null : _previousStep,
                  text: 'Back',
                  backgroundColor: AppColors.backgroundDark,
                  textColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing16),
              Expanded(
                flex: 2,
                child: CustomButton(
                  onPressed: _isLoading ? null : _submitApplication,
                  text: _isLoading
                      ? 'Submitting Application...'
                      : 'Submit Application',
                  backgroundColor: AppColors.collectorPrimary,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
